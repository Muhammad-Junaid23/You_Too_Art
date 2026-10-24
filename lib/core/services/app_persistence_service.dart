import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/core/constants/talent_directory.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_driver.dart';
import 'package:you_too_art/features/profile/providers/user_portfolio_provider.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';

/// Centralized, multi-engine persistence service that guarantees user data,
/// profile edits, and portfolio additions/deletions survive app restarts,
/// process termination, and browser port changes.
///
/// Engines utilized simultaneously:
/// 1. Native disk file (dart:io) on desktop/mobile
/// 2. Web localStorage & cross-port chunked cookies on Flutter Web
/// 3. SharedPreferences master JSON snapshot
/// 4. Cloud Supabase Auth metadata & users table sync when authenticated
class AppPersistenceService {
  static const String _masterKey = 'you_too_art_master_state_v4';

  static const String actorDefaultId = '00000000-0000-0000-0000-000000000001';
  static const String alexanderId = 'a1111111-1111-1111-1111-111111111111';
  static const String filmfareId = 'b2222222-2222-2222-2222-222222222222';
  static const String jeremiahId = 'c3333333-3333-3333-3333-333333333333';

  static AppPersistenceService? _instance;
  static AppPersistenceService get instance {
    if (_instance == null) {
      throw StateError(
        'AppPersistenceService must be initialized via initialize() before access',
      );
    }
    return _instance!;
  }

  final SharedPreferences _prefs;
  final Map<String, UserPersona> _personas = {};
  final Map<String, UserPortfolioState> _portfolios = {};
  String _activePersonaId = actorDefaultId;

  /// Callback fired when persistent state updates (e.g. from cloud or edit)
  VoidCallback? onStateChanged;

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    onStateChanged?.call();
    for (final l in List<VoidCallback>.from(_listeners)) {
      try {
        l();
      } catch (_) {}
    }
  }

  AppPersistenceService._(this._prefs);

  static Future<AppPersistenceService> initialize(
    SharedPreferences prefs,
  ) async {
    final service = AppPersistenceService._(prefs);
    await service._loadAll();
    _instance = service;

    // Immediately sync if Supabase user is already authenticated
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        await service.syncWithSupabaseUser(currentUser);
      }
    } catch (_) {}

    // Listen to Supabase auth state changes reactively
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final sessionUser = data.session?.user;
        if (sessionUser != null) {
          service.syncWithSupabaseUser(sessionUser);
        }
      });
    } catch (_) {}

    return service;
  }

  // ─── Persona Queries ────────────────────────────────────────

  bool isActorId(String id) {
    if (id == 'actor' || id == actorDefaultId) return true;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && id == user.id) return true;
    return false;
  }

  bool isSamePersona(String id1, String id2) {
    if (id1 == id2) return true;
    return isActorId(id1) && isActorId(id2);
  }

  UserPersona getActorPersona() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && _personas.containsKey(user.id)) {
      final p = _personas[user.id]!;
      if (p.name.trim().isNotEmpty && p.name != 'Muhammad Wajahat') {
        return p;
      }
    }
    if (_personas.containsKey('actor')) {
      final p = _personas['actor']!;
      if (p.name.trim().isNotEmpty && p.name != 'Muhammad Wajahat') {
        return p;
      }
    }
    if (_personas.containsKey(actorDefaultId)) {
      final p = _personas[actorDefaultId]!;
      if (p.name.trim().isNotEmpty && p.name != 'Muhammad Wajahat') {
        return p;
      }
    }
    if (user != null && _personas.containsKey(user.id)) {
      return _personas[user.id]!;
    }
    if (_personas.containsKey('actor')) return _personas['actor']!;
    if (_personas.containsKey(actorDefaultId)) return _personas[actorDefaultId]!;
    return _buildDefaultActor();
  }

  UserPersona getPersona(String id) {
    if (isActorId(id)) return getActorPersona();
    if (_personas.containsKey(id)) return _personas[id]!;
    if (id == alexanderId) return _buildDefaultAlexander();
    if (id == filmfareId) return _buildDefaultFilmFare();
    if (id == jeremiahId) return _buildDefaultJeremiah();
    return getActorPersona();
  }

  bool hasPersona(String id) {
    if (isActorId(id)) return true;
    if (_personas.containsKey(id)) return true;
    if (id == alexanderId || id == filmfareId || id == jeremiahId) return true;
    return false;
  }

  UserPersona getActivePersona() {
    return getPersona(_activePersonaId);
  }

  List<UserPersona> get allPersonas => [
        getPersona(actorDefaultId),
        getPersona(alexanderId),
        getPersona(filmfareId),
        getPersona(jeremiahId),
      ];

  void setActivePersonaId(String id) {
    _activePersonaId = id;
    _flush();
  }

  void savePersona(UserPersona updated) {
    final user = Supabase.instance.client.auth.currentUser;
    final isActor = isActorId(updated.id);
    final jsonStr = jsonEncode(updated.toJson());

    if (isActor) {
      _personas['actor'] = updated;
      _personas[actorDefaultId] = updated;
      if (user != null) {
        _personas[user.id] = updated.copyWith(id: user.id);
        _prefs.setString('persona_profile_${user.id}', jsonStr);
      }
      _prefs.setString('persona_profile_actor', jsonStr);
      _prefs.setString('persona_profile_$actorDefaultId', jsonStr);
    } else {
      _personas[updated.id] = updated;
      _prefs.setString('persona_profile_${updated.id}', jsonStr);
    }

    _flush();
    if (isActor) {
      _syncActorToCloud(updated);
    } else {
      _syncMockPersonasToCloud();
    }
    notifyListeners();
  }

  // ─── Portfolio Queries ──────────────────────────────────────

  UserPortfolioState getPortfolio(String id) {
    final isActor = isActorId(id);
    if (isActor) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && _portfolios.containsKey(user.id)) {
        return _portfolios[user.id]!;
      }
      if (_portfolios.containsKey('actor')) return _portfolios['actor']!;
      if (_portfolios.containsKey(actorDefaultId)) {
        return _portfolios[actorDefaultId]!;
      }
      return _buildDefaultActorPortfolio();
    }

    if (_portfolios.containsKey(id)) return _portfolios[id]!;
    if (id == alexanderId) return _buildDefaultAlexanderPortfolio();
    if (id == filmfareId) return _buildDefaultFilmFarePortfolio();
    if (id == jeremiahId) return _buildDefaultJeremiahPortfolio();

    // Dynamically build artist portfolio from TalentDirectory if present
    final talent = TalentDirectory.findById(id);
    if (talent != null) {
      return _buildTalentPortfolio(talent);
    }
    return _buildDefaultActorPortfolio();
  }

  void savePortfolio(String id, UserPortfolioState updated) {
    final user = Supabase.instance.client.auth.currentUser;
    final isActor = isActorId(id);
    final jsonStr = jsonEncode(updated.toJson());

    if (isActor) {
      _portfolios['actor'] = updated;
      _portfolios[actorDefaultId] = updated;
      if (user != null) {
        _portfolios[user.id] = updated;
      }
      _prefs.setString('user_work_portfolio_actor', jsonStr);
      _prefs.setString('user_work_portfolio_$actorDefaultId', jsonStr);
      if (user != null) {
        _prefs.setString('user_work_portfolio_${user.id}', jsonStr);
      }
    } else {
      _portfolios[id] = updated;
      _prefs.setString('user_work_portfolio_$id', jsonStr);
    }

    _flush();
    if (isActor) {
      _syncActorPortfolioToCloud(updated);
    } else {
      _syncMockPortfoliosToCloud();
    }
    notifyListeners();
  }

  // ─── Multi-Engine Persistence Logic ─────────────────────────

  Future<void> _loadAll() async {
    // 1. Try reading raw data from platform storage driver (File on desktop, chunked cookies/localStorage on web)
    String? rawData = PlatformStorageDriver.readRawData();

    // 2. Try reading from SharedPreferences master keys (v4 then v3)
    if (rawData == null || rawData.trim().isEmpty) {
      rawData = _prefs.getString(_masterKey) ??
          _prefs.getString('you_too_art_master_state_v3');
    }

    // 3. Try reading from Supabase Auth user_metadata if user is logged in
    if (rawData == null || rawData.trim().isEmpty) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final cloudState = user.userMetadata?['app_state'] as String?;
          if (cloudState != null && cloudState.trim().isNotEmpty) {
            rawData = cloudState;
          }
        }
      } catch (_) {}
    }

    if (rawData != null && rawData.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawData) as Map<String, dynamic>;

        // Active persona
        if (decoded.containsKey('active_persona_id')) {
          _activePersonaId = decoded['active_persona_id'] as String;
        }

        // Personas
        if (decoded['personas'] is Map) {
          final pMap = decoded['personas'] as Map<String, dynamic>;
          for (final entry in pMap.entries) {
            try {
              _personas[entry.key] = UserPersona.fromJson(
                entry.value as Map<String, dynamic>,
              );
            } catch (_) {}
          }
        }

        // Portfolios
        if (decoded['portfolios'] is Map) {
          final portMap = decoded['portfolios'] as Map<String, dynamic>;
          for (final entry in portMap.entries) {
            try {
              _portfolios[entry.key] = UserPortfolioState.fromJson(
                entry.value as Map<String, dynamic>,
              );
            } catch (_) {}
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AppPersistenceService._loadAll parse error: $e');
      }
    }

    // Always merge individual SharedPreferences keys (ensures single edits survive snapshot mismatches)
    _loadIndividualPrefs();

    _ensureDefaultsLoaded();
    _flush();
  }

  void _loadIndividualPrefs() {
    final user = Supabase.instance.client.auth.currentUser;
    final ids = ['actor', actorDefaultId, alexanderId, filmfareId, jeremiahId];
    if (user != null && !ids.contains(user.id)) {
      ids.insert(0, user.id);
    }
    for (final id in ids) {
      final pStr = _prefs.getString('persona_profile_$id');
      if (pStr != null && pStr.trim().isNotEmpty) {
        try {
          _personas[id] = UserPersona.fromJson(
            jsonDecode(pStr) as Map<String, dynamic>,
          );
        } catch (_) {}
      }

      final portStr = _prefs.getString('user_work_portfolio_$id');
      if (portStr != null && portStr.trim().isNotEmpty) {
        try {
          _portfolios[id] = UserPortfolioState.fromJson(
            jsonDecode(portStr) as Map<String, dynamic>,
          );
        } catch (_) {}
      }
    }

    final savedId = _prefs.getString('active_user_persona_id');
    if (savedId != null && hasPersona(savedId)) {
      _activePersonaId = savedId;
    } else if (user != null && _personas.containsKey(user.id)) {
      _activePersonaId = user.id;
    }
  }

  void _ensureDefaultsLoaded() {
    final actor = getActorPersona();
    _personas['actor'] = actor;
    _personas[actorDefaultId] = actor;

    _personas.putIfAbsent(alexanderId, () => _buildDefaultAlexander());
    _personas.putIfAbsent(filmfareId, () => _buildDefaultFilmFare());
    _personas.putIfAbsent(jeremiahId, () => _buildDefaultJeremiah());

    // Ensure Alexander Cole is not corrupted by stale actor avatar in cache
    final alex = _personas[alexanderId];
    if (alex == null || alex.avatarUrl.contains('1507003211169-0a1dd7228f2d')) {
      _personas[alexanderId] = _buildDefaultAlexander();
    }
    final alexPort = _portfolios[alexanderId];
    if (alexPort == null ||
        alexPort.photos.any(
            (p) => p.mediaUrl.contains('1507003211169-0a1dd7228f2d'))) {
      _portfolios[alexanderId] = _buildDefaultAlexanderPortfolio();
    }

    _portfolios.putIfAbsent('actor', () => _buildDefaultActorPortfolio());
    _portfolios.putIfAbsent(
        actorDefaultId, () => _buildDefaultActorPortfolio());
    _portfolios.putIfAbsent(
        alexanderId, () => _buildDefaultAlexanderPortfolio());
    _portfolios.putIfAbsent(filmfareId, () => _buildDefaultFilmFarePortfolio());
    _portfolios.putIfAbsent(jeremiahId, () => _buildDefaultJeremiahPortfolio());
  }



  void _flush() {
    try {
      final data = {
        'active_persona_id': _activePersonaId,
        'personas': {
          for (final e in _personas.entries) e.key: e.value.toJson(),
        },
        'portfolios': {
          for (final e in _portfolios.entries) e.key: e.value.toJson(),
        },
      };

      final encoded = jsonEncode(data);

      // 1. Write to platform storage driver (File on desktop, chunked cookies/localStorage on web)
      PlatformStorageDriver.writeRawData(encoded);

      // 2. Write to SharedPreferences master snapshot
      _prefs.setString(_masterKey, encoded);

      // 3. Write individual keys for every persona and portfolio
      for (final e in _personas.entries) {
        _prefs.setString(
          'persona_profile_${e.key}',
          jsonEncode(e.value.toJson()),
        );
      }
      for (final e in _portfolios.entries) {
        _prefs.setString(
          'user_work_portfolio_${e.key}',
          jsonEncode(e.value.toJson()),
        );
      }
      _prefs.setString('active_user_persona_id', _activePersonaId);
    } catch (e) {
      if (kDebugMode) debugPrint('AppPersistenceService._flush error: $e');
    }
  }

  /// Reactively syncs newly logged-in Supabase user with local memory & storage
  Future<void> syncWithSupabaseUser(User user) async {
    try {
      // 1. Check cloud app_state in user_metadata only for missing personas/portfolios
      final cloudState = user.userMetadata?['app_state'] as String?;
      if (cloudState != null && cloudState.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(cloudState) as Map<String, dynamic>;
          if (decoded['personas'] is Map) {
            final pMap = decoded['personas'] as Map<String, dynamic>;
            for (final entry in pMap.entries) {
              _personas.putIfAbsent(
                entry.key,
                () => UserPersona.fromJson(entry.value as Map<String, dynamic>),
              );
            }
          }
          if (decoded['portfolios'] is Map) {
            final portMap = decoded['portfolios'] as Map<String, dynamic>;
            for (final entry in portMap.entries) {
              _portfolios.putIfAbsent(
                entry.key,
                () => UserPortfolioState.fromJson(
                  entry.value as Map<String, dynamic>,
                ),
              );
            }
          }
        } catch (_) {}
      }

      // Check cloud mock personas and portfolios
      final mockPersonasRaw = user.userMetadata?['mock_personas_snapshot'] as String?;
      if (mockPersonasRaw != null && mockPersonasRaw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(mockPersonasRaw) as Map<String, dynamic>;
          for (final entry in decoded.entries) {
            _personas.putIfAbsent(
              entry.key,
              () => UserPersona.fromJson(entry.value as Map<String, dynamic>),
            );
          }
        } catch (_) {}
      }

      final mockPortfoliosRaw = user.userMetadata?['mock_portfolios_snapshot'] as String?;
      if (mockPortfoliosRaw != null && mockPortfoliosRaw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(mockPortfoliosRaw) as Map<String, dynamic>;
          for (final entry in decoded.entries) {
            _portfolios.putIfAbsent(
              entry.key,
              () => UserPortfolioState.fromJson(entry.value as Map<String, dynamic>),
            );
          }
        } catch (_) {}
      }

      // Check cloud user_metadata for Actor's work portfolio
      final vRaw = user.userMetadata?['work_portfolio_videos'] as String?;
      final pRaw = user.userMetadata?['work_portfolio_photos'] as String?;
      if (vRaw != null || pRaw != null) {
        try {
          final videosList = vRaw != null
              ? (jsonDecode(vRaw) as List)
                  .map((e) => WorkMediaItem.fromJson(e as Map<String, dynamic>))
                  .toList()
              : <WorkMediaItem>[];
          final photosList = pRaw != null
              ? (jsonDecode(pRaw) as List)
                  .map((e) => WorkMediaItem.fromJson(e as Map<String, dynamic>))
                  .toList()
              : <WorkMediaItem>[];
          if (videosList.isNotEmpty || photosList.isNotEmpty) {
            final cloudPort = UserPortfolioState(videos: videosList, photos: photosList);
            _portfolios['actor'] = cloudPort;
            _portfolios[actorDefaultId] = cloudPort;
            _portfolios[user.id] = cloudPort;
          }
        } catch (_) {}
      }

      // Check Supabase portfolio_items table for Actor's portfolio
      try {
        final client = Supabase.instance.client;
        final pRows = await client
            .from('portfolio_items')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: true);
        if (pRows.isNotEmpty) {
          final videos = <WorkMediaItem>[];
          final photos = <WorkMediaItem>[];
          for (final row in pRows) {
            final mediaType = row['media_type'] as String? ?? 'photo';
            final item = WorkMediaItem(
              id: row['id']?.toString() ?? '',
              title: row['title'] as String? ?? '',
              url: row['media_url'] as String? ?? '',
              mediaUrl: row['media_url'] as String? ?? '',
              isVideo: mediaType.toLowerCase() == 'video',
              lastUpdated: 'Just Now',
            );
            if (item.isVideo) {
              videos.add(item);
            } else {
              photos.add(item);
            }
          }
          final dbPort = UserPortfolioState(videos: videos, photos: photos);
          _portfolios['actor'] = dbPort;
          _portfolios[actorDefaultId] = dbPort;
          _portfolios[user.id] = dbPort;
        } else {
          // If the authenticated user has a completed profile in users table,
          // do NOT display the dummy actor seed portfolio. Use clean empty portfolio.
          final row = await client.from('users').select().eq('id', user.id).maybeSingle();
          if (row != null && (row['first_name'] != null || row['name'] != null)) {
            const emptyPort = UserPortfolioState(videos: [], photos: []);
            _portfolios['actor'] = emptyPort;
            _portfolios[actorDefaultId] = emptyPort;
            _portfolios[user.id] = emptyPort;
          }
        }
      } catch (_) {}

      // 2. Merge non-empty user metadata fields into Actor persona
      final metaName = user.userMetadata?['name'] as String?;
      final metaRole = user.userMetadata?['role'] as String?;
      final metaAvatar = user.userMetadata?['avatar_url'] as String?;
      final metaBio = user.userMetadata?['bio'] as String?;
      final metaWebsite = user.userMetadata?['website'] as String?;
      final metaExp = user.userMetadata?['experience'] as String?;
      final metaLoc = user.userMetadata?['location'] as String?;

      final currentActor = getActorPersona();
      final mergedActor = currentActor.copyWith(
        id: user.id,
        name: (metaName != null && metaName.trim().isNotEmpty)
            ? metaName
            : currentActor.name,
        role: (metaRole != null && metaRole.trim().isNotEmpty)
            ? metaRole
            : currentActor.role,
        avatarUrl: (metaAvatar != null && metaAvatar.trim().isNotEmpty)
            ? metaAvatar
            : currentActor.avatarUrl,
        bio: (metaBio != null && metaBio.trim().isNotEmpty)
            ? metaBio
            : currentActor.bio,
        website: (metaWebsite != null && metaWebsite.trim().isNotEmpty)
            ? metaWebsite
            : currentActor.website,
        experience: (metaExp != null && metaExp.trim().isNotEmpty)
            ? metaExp
            : currentActor.experience,
        location: (metaLoc != null && metaLoc.trim().isNotEmpty)
            ? metaLoc
            : currentActor.location,
      );

      _personas['actor'] = mergedActor;
      _personas[actorDefaultId] = mergedActor;
      _personas[user.id] = mergedActor;

      // 3. Check Supabase users table for persistent profile data
      try {
        final client = Supabase.instance.client;
        final row =
            await client.from('users').select().eq('id', user.id).maybeSingle();
        if (row != null) {
          final firstName = row['first_name'] as String? ?? '';
          final lastName = row['last_name'] as String? ?? '';
          final combinedName =
              '$firstName $lastName'.trim().isNotEmpty ? '$firstName $lastName'.trim() : row['name'] as String? ?? '';
          final updatedWithRow = mergedActor.copyWith(
            name: combinedName.isNotEmpty ? combinedName : mergedActor.name,
            role: (row['role'] as String? ?? '').isNotEmpty && row['role'] != 'unset'
                ? row['role'] as String
                : mergedActor.role,
            bio: (row['bio'] as String? ?? '').isNotEmpty
                ? row['bio'] as String
                : mergedActor.bio,
            location: (row['location'] as String? ?? '').isNotEmpty
                ? row['location'] as String
                : mergedActor.location,
            avatarUrl: (row['profile_image_path'] as String? ?? '').isNotEmpty
                ? row['profile_image_path'] as String
                : mergedActor.avatarUrl,
          );
          _personas['actor'] = updatedWithRow;
          _personas[actorDefaultId] = updatedWithRow;
          _personas[user.id] = updatedWithRow;
        }
      } catch (_) {}

      _ensureDefaultsLoaded();
      _flush();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('AppPersistenceService.syncWithSupabaseUser error: $e');
    }
  }

  Future<void> _syncActorToCloud(UserPersona actor) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      final mockPersonasSnapshot = jsonEncode({
        for (final id in [alexanderId, filmfareId, jeremiahId])
          if (_personas.containsKey(id)) id: _personas[id]!.toJson(),
      });

      await client.auth.updateUser(
        UserAttributes(
          data: {
            'name': actor.name,
            'role': actor.role,
            'bio': actor.bio,
            'website': actor.website,
            'experience': actor.experience,
            'location': actor.location,
            'avatar_url': actor.avatarUrl,
            'mock_personas_snapshot': mockPersonasSnapshot,
          },
        ),
      );
    } catch (_) {}

    try {
      final names = actor.name.trim().split(' ');
      final firstName = names.first;
      final lastName = names.length > 1 ? names.skip(1).join(' ') : '';
      await client.from('users').update({
        'first_name': firstName,
        'last_name': lastName,
        'name': actor.name,
        'role': actor.role,
        'bio': actor.bio,
        'location': actor.location,
        'profile_image_path': actor.avatarUrl,
      }).eq('id', user.id);
    } catch (_) {}
  }

  Future<void> _syncMockPersonasToCloud() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      final mockSnapshot = jsonEncode({
        for (final id in [alexanderId, filmfareId, jeremiahId])
          if (_personas.containsKey(id)) id: _personas[id]!.toJson(),
      });
      await client.auth.updateUser(
        UserAttributes(data: {'mock_personas_snapshot': mockSnapshot}),
      );
    } catch (_) {}
  }

  Future<void> _syncMockPortfoliosToCloud() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      final mockSnapshot = jsonEncode({
        for (final id in [alexanderId, filmfareId, jeremiahId])
          if (_portfolios.containsKey(id)) id: _portfolios[id]!.toJson(),
      });
      await client.auth.updateUser(
        UserAttributes(data: {'mock_portfolios_snapshot': mockSnapshot}),
      );
    } catch (_) {}
  }

  Future<void> _syncActorPortfolioToCloud(UserPortfolioState portfolio) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      final mockPortfoliosSnapshot = jsonEncode({
        for (final id in [alexanderId, filmfareId, jeremiahId])
          if (_portfolios.containsKey(id)) id: _portfolios[id]!.toJson(),
      });

      await client.auth.updateUser(
        UserAttributes(
          data: {
            'work_portfolio_videos': jsonEncode(
              portfolio.videos.map((v) => v.toJson()).toList(),
            ),
            'work_portfolio_photos': jsonEncode(
              portfolio.photos.map((p) => p.toJson()).toList(),
            ),
            'mock_portfolios_snapshot': mockPortfoliosSnapshot,
          },
        ),
      );
    } catch (_) {}

    try {
      for (final video in portfolio.videos) {
        await client.from('portfolio_items').upsert({
          if (video.id.isNotEmpty && video.id.length >= 30) 'id': video.id,
          'user_id': user.id,
          'title': video.title,
          'media_url': video.mediaUrl,
          'media_type': 'video',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      for (final photo in portfolio.photos) {
        await client.from('portfolio_items').upsert({
          if (photo.id.isNotEmpty && photo.id.length >= 30) 'id': photo.id,
          'user_id': user.id,
          'title': photo.title,
          'media_url': photo.mediaUrl,
          'media_type': 'photo',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  // ─── Default Generators ──────────────────────────────────────

  static UserPersona _buildDefaultActor() {
    return const UserPersona(
      id: actorDefaultId,
      name: 'Muhammad Wajahat',
      email: 'wajahat@youtooart.test',
      role: 'Actor, Director',
      avatarUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      isProductionHouse: false,
      bio:
          'Award-winning performing artist and indie filmmaker focusing on dramatic monologues, character studies, and cinematic narratives.',
      website: 'www.be.net/WajahatUIUX',
      experience: '5+ Years',
      location: 'Islamabad, Pakistan',
    );
  }

  static UserPersona _buildDefaultAlexander() {
    return const UserPersona(
      id: alexanderId,
      name: 'Alexander Cole',
      email: 'alexander.cole@youtooart.test',
      role: 'Actor | Director | Producer',
      avatarUrl:
          'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=400&q=80',
      isProductionHouse: false,
      bio:
          'Award-winning actor and indie film director with extensive experience across feature drama, festival shorts, and modern theatrical storytelling.',
      website: 'www.alexandercole.art',
      experience: '8+ Years',
      location: 'New York, NY',
    );
  }

  static UserPersona _buildDefaultFilmFare() {
    return const UserPersona(
      id: filmfareId,
      name: 'FilmFare',
      email: 'filmfare.studio@youtooart.test',
      role: 'Production House',
      avatarUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
      isProductionHouse: true,
      bio:
          'FilmFare is a premier entertainment studio producing groundbreaking feature films, digital web series, and high-impact commercial cinema. We connect bold emerging talent with top industry directors.',
      website: 'www.filmfare-studios.com',
      experience: '12+ Years',
      location: 'Hollywood, CA',
    );
  }

  static UserPersona _buildDefaultJeremiah() {
    return const UserPersona(
      id: jeremiahId,
      name: 'Jeremiah Green',
      email: 'jeremiah.green@youtooart.test',
      role: 'Actor | Model | Director',
      avatarUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
      isProductionHouse: false,
      bio:
          'Passionate actor, runway model, and aspiring film director based in Los Angeles. Experienced in leading roles across independent cinema, international commercials, and theatrical performances.',
      website: 'www.jeremiahgreen.com',
      experience: '6+ Years',
      location: 'Los Angeles, CA',
    );
  }

  static UserPortfolioState _buildDefaultActorPortfolio() {
    return const UserPortfolioState(
      videos: [
        WorkMediaItem(
          id: 'vid_1',
          title: 'SPECIAL REPORT: What\'s the Trouble in Gilgit-Baltistan?',
          url: 'https://youtu.be/JXCRWxBA0fE',
          mediaUrl:
              'https://images.unsplash.com/photo-1556761175-5973dc0f32e7?auto=format&fit=crop&w=800&q=80',
          isVideo: true,
          lastUpdated: 'Just Now',
        ),
      ],
      photos: [
        WorkMediaItem(
          id: 'photo_1',
          title: 'Short Film on Teen Age Side Hustles',
          url: 'https://drive.google.com/u/1/a3tc',
          mediaUrl:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '2 days ago',
        ),
        WorkMediaItem(
          id: 'photo_2',
          title: 'Cinematic Moodboard - Red Studio',
          url: 'https://drive.google.com/u/1/photo2',
          mediaUrl:
              'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '3 days ago',
        ),
        WorkMediaItem(
          id: 'photo_3',
          title: 'Behind the Scenes - Indie Production',
          url: 'https://drive.google.com/u/1/photo3',
          mediaUrl:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '5 days ago',
        ),
        WorkMediaItem(
          id: 'photo_4',
          title: 'Golden Hour Character Study',
          url: 'https://drive.google.com/u/1/photo4',
          mediaUrl:
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '1 week ago',
        ),
        WorkMediaItem(
          id: 'photo_5',
          title: 'Monochrome Dramatic Monologue',
          url: 'https://drive.google.com/u/1/photo5',
          mediaUrl:
              'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '1 week ago',
        ),
        WorkMediaItem(
          id: 'photo_6',
          title: 'Theatre Rehearsal Stills',
          url: 'https://drive.google.com/u/1/photo6',
          mediaUrl:
              'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '2 weeks ago',
        ),
        WorkMediaItem(
          id: 'photo_7',
          title: 'Stage Presence & Silhouette',
          url: 'https://drive.google.com/u/1/photo7',
          mediaUrl:
              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '2 weeks ago',
        ),
        WorkMediaItem(
          id: 'photo_8',
          title: 'Editorial Headshots Session',
          url: 'https://drive.google.com/u/1/photo8',
          mediaUrl:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '3 weeks ago',
        ),
        WorkMediaItem(
          id: 'photo_9',
          title: 'Casting Reel Stills - Period Drama',
          url: 'https://drive.google.com/u/1/photo9',
          mediaUrl:
              'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '1 month ago',
        ),
        WorkMediaItem(
          id: 'photo_10',
          title: 'Urban Action Sequence Frames',
          url: 'https://drive.google.com/u/1/photo10',
          mediaUrl:
              'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '1 month ago',
        ),
        WorkMediaItem(
          id: 'photo_11',
          title: 'Expressive Close-ups - Emotional Arc',
          url: 'https://drive.google.com/u/1/photo11',
          mediaUrl:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '1 month ago',
        ),
        WorkMediaItem(
          id: 'photo_12',
          title: 'Director Showcase Wrap Stills',
          url: 'https://drive.google.com/u/1/photo12',
          mediaUrl:
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '2 months ago',
        ),
      ],
    );
  }

  static UserPortfolioState _buildDefaultAlexanderPortfolio() {
    return const UserPortfolioState(
      videos: [
        WorkMediaItem(
          id: 'vid_alex_1',
          title: 'Short Film Festival Trailer - Brooklyn Noir',
          url: 'https://youtu.be/JXCRWxBA0fE',
          mediaUrl:
              'https://images.unsplash.com/photo-1485846234645-a62644f84728?auto=format&fit=crop&w=800&q=80',
          isVideo: true,
          lastUpdated: 'Yesterday',
        ),
        WorkMediaItem(
          id: 'vid_alex_2',
          title: 'Dramatic Scene Monologue - Feature Audition',
          url: 'https://youtu.be/JXCRWxBA0fE',
          mediaUrl:
              'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=800&q=80',
          isVideo: true,
          lastUpdated: '3 days ago',
        ),
      ],
      photos: [
        WorkMediaItem(
          id: 'photo_alex_1',
          title: 'Alexander Cole Editorial Portfolio Stills',
          url: 'https://drive.google.com/u/1/alex1',
          mediaUrl:
              'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '1 day ago',
        ),
        WorkMediaItem(
          id: 'photo_alex_2',
          title: 'On-Set Direction - Indie Feature Drama',
          url: 'https://drive.google.com/u/1/alex2',
          mediaUrl:
              'https://images.unsplash.com/photo-1485846234645-a62644f84728?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '5 days ago',
        ),
        WorkMediaItem(
          id: 'photo_alex_3',
          title: 'Monochrome Character Arc - New York',
          url: 'https://drive.google.com/u/1/alex3',
          mediaUrl:
              'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '1 week ago',
        ),
        WorkMediaItem(
          id: 'photo_alex_4',
          title: 'Rehearsal Lighting & Silhouette',
          url: 'https://drive.google.com/u/1/alex4',
          mediaUrl:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '2 weeks ago',
        ),
      ],
    );
  }

  static UserPortfolioState _buildDefaultFilmFarePortfolio() {
    return const UserPortfolioState(
      videos: [
        WorkMediaItem(
          id: 'vid_ff_1',
          title: 'FilmFare Studio Upcoming Slate 2026',
          url: 'https://youtu.be/JXCRWxBA0fE',
          mediaUrl:
              'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?auto=format&fit=crop&w=800&q=80',
          isVideo: true,
          lastUpdated: 'Just Now',
        ),
        WorkMediaItem(
          id: 'vid_ff_2',
          title: 'Open Casting Call Teaser - Commercial Project',
          url: 'https://youtu.be/JXCRWxBA0fE',
          mediaUrl:
              'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=800&q=80',
          isVideo: true,
          lastUpdated: '4 days ago',
        ),
      ],
      photos: [
        WorkMediaItem(
          id: 'photo_ff_1',
          title: 'FilmFare Studio Production Lot & Soundstages',
          url: 'https://drive.google.com/u/1/ff1',
          mediaUrl:
              'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '2 days ago',
        ),
        WorkMediaItem(
          id: 'photo_ff_2',
          title: 'Feature Film Concept Art & Moodboard',
          url: 'https://drive.google.com/u/1/ff2',
          mediaUrl:
              'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '5 days ago',
        ),
        WorkMediaItem(
          id: 'photo_ff_3',
          title: 'Cast Table Read - Period Short Film',
          url: 'https://drive.google.com/u/1/ff3',
          mediaUrl:
              'https://images.unsplash.com/photo-1556761175-5973dc0f32e7?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '1 week ago',
        ),
        WorkMediaItem(
          id: 'photo_ff_4',
          title: 'Post-Production Grading Suite Stills',
          url: 'https://drive.google.com/u/1/ff4',
          mediaUrl:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '2 weeks ago',
        ),
      ],
    );
  }

  static UserPortfolioState _buildDefaultJeremiahPortfolio() {
    return const UserPortfolioState(
      videos: [
        WorkMediaItem(
          id: 'vid_jer_1',
          title: 'Jeremiah Green Dramatic Reel - Los Angeles',
          url: 'https://youtu.be/JXCRWxBA0fE',
          mediaUrl:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=800&q=80',
          isVideo: true,
          lastUpdated: 'Just Now',
        ),
        WorkMediaItem(
          id: 'vid_jer_2',
          title: 'Runway Showcase - Paris & Milan Commercial Reel',
          url: 'https://youtu.be/JXCRWxBA0fE',
          mediaUrl:
              'https://images.unsplash.com/photo-1426604966848-d7adac402bff?auto=format&fit=crop&w=800&q=80',
          isVideo: true,
          lastUpdated: '5 days ago',
        ),
      ],
      photos: [
        WorkMediaItem(
          id: 'photo_jer_1',
          title: 'Editorial Character Headshots - LA Studio',
          url: 'https://drive.google.com/u/1/jer1',
          mediaUrl:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '1 day ago',
        ),
        WorkMediaItem(
          id: 'photo_jer_2',
          title: 'Cinematic Moodboard - Golden Hour',
          url: 'https://drive.google.com/u/1/jer2',
          mediaUrl:
              'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '3 days ago',
        ),
        WorkMediaItem(
          id: 'photo_jer_3',
          title: 'Runway Movement & Silhouettes',
          url: 'https://drive.google.com/u/1/jer3',
          mediaUrl:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '6 days ago',
        ),
        WorkMediaItem(
          id: 'photo_jer_4',
          title: 'Theatre Monologue Production Stills',
          url: 'https://drive.google.com/u/1/jer4',
          mediaUrl:
              'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=800&q=80',
          isVideo: false,
          lastUpdated: '1 week ago',
        ),
      ],
    );
  }

  static UserPortfolioState _buildTalentPortfolio(TalentModel talent) {
    final photos = talent.workPortfolio.map((url) {
      final idx = talent.workPortfolio.indexOf(url) + 1;
      return WorkMediaItem(
        id: 'photo_${talent.id}_$idx',
        title: '${talent.name} Portfolio Still $idx',
        url: url,
        mediaUrl: url,
        isVideo: false,
        lastUpdated: '$idx days ago',
      );
    }).toList();

    final avatar = talent.avatarUrl ?? '';
    return UserPortfolioState(
      videos: [
        WorkMediaItem(
          id: 'vid_${talent.id}_1',
          title: '${talent.name} Official Showreel (${talent.roles.split('|').first.trim()})',
          url: 'https://youtu.be/JXCRWxBA0fE',
          mediaUrl: avatar,
          isVideo: true,
          lastUpdated: 'Recent',
        ),
      ],
      photos: photos.isNotEmpty
          ? photos
          : [
              WorkMediaItem(
                id: 'photo_${talent.id}_1',
                title: '${talent.name} Official Portrait',
                url: avatar,
                mediaUrl: avatar,
                isVideo: false,
                lastUpdated: 'Recent',
              ),
            ],
    );
  }
}
