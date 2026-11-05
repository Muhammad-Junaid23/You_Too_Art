import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/repositories/chat_repository.dart';
import 'package:you_too_art/core/repositories/connection_repository.dart';
import 'package:you_too_art/core/services/app_persistence_driver.dart';
import 'package:you_too_art/features/profile/providers/user_portfolio_provider.dart';
import 'package:you_too_art/features/casting/models/casting_application_model.dart';
import 'package:you_too_art/features/casting/models/casting_call_model.dart';

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

  static const String actorDefaultId = '68f958bd-015f-4d74-ab42-98c224240537';
  static const String alexanderId = '363152eb-78b7-4625-9f6e-e13dc8da45d2';
  static const String filmfareId = '4f668c94-c9df-4db2-b844-b7ad0a981fde';
  static const String jeremiahId = 'c3333333-3333-3333-3333-333333333333';
  static const String singerId = 'd4444444-4444-4444-4444-444444444444';

  static const String realDirectorId = '363152eb-78b7-4625-9f6e-e13dc8da45d2';
  static const String realActorId = '68f958bd-015f-4d74-ab42-98c224240537';
  static const String realProductionId = '4f668c94-c9df-4db2-b844-b7ad0a981fde';

  static UserPortfolioState get defaultActorPortfolio => _defaultActorPortfolio;
  static UserPortfolioState get defaultDirectorPortfolio => _defaultDirectorPortfolio;
  static UserPortfolioState get defaultProductionPortfolio => _defaultProductionPortfolio;

  static final UserPortfolioState _defaultActorPortfolio = UserPortfolioState(
    videos: [
      WorkMediaItem(
        id: '11111111-0000-0000-0000-000000000001',
        title: 'Dramatic Monologue - Character Study',
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        mediaUrl:
            'https://res.cloudinary.com/dsxhrelpu/image/upload/v1793547862/posts/68f958bd-015f-4d74-ab42-98c224240537/ktn2ebeepmuo7qe8zqem.png',
        isVideo: true,
        lastUpdated: 'Recently',
      ),
    ],
    photos: [
      WorkMediaItem(
        id: '11111111-0000-0000-0000-000000000002',
        title: 'Dramatic Portrait Still',
        url:
            'https://res.cloudinary.com/dsxhrelpu/image/upload/v1793547862/posts/68f958bd-015f-4d74-ab42-98c224240537/ktn2ebeepmuo7qe8zqem.png',
        mediaUrl:
            'https://res.cloudinary.com/dsxhrelpu/image/upload/v1793547862/posts/68f958bd-015f-4d74-ab42-98c224240537/ktn2ebeepmuo7qe8zqem.png',
        isVideo: false,
        lastUpdated: 'Recently',
      ),
    ],
  );

  static final UserPortfolioState _defaultDirectorPortfolio = UserPortfolioState(
    videos: [
      WorkMediaItem(
        id: '22222222-0000-0000-0000-000000000001',
        title: 'Director Narrative Showreel',
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        mediaUrl:
            'https://res.cloudinary.com/dsxhrelpu/image/upload/v1793470261/posts/363152eb-78b7-4625-9f6e-e13dc8da45d2/oqlc9tc0nfbcirkrd5bm.jpg',
        isVideo: true,
        lastUpdated: 'Recently',
      ),
    ],
    photos: [
      WorkMediaItem(
        id: '22222222-0000-0000-0000-000000000002',
        title: 'Behind The Scenes - On Set',
        url:
            'https://res.cloudinary.com/dsxhrelpu/image/upload/v1793470261/posts/363152eb-78b7-4625-9f6e-e13dc8da45d2/oqlc9tc0nfbcirkrd5bm.jpg',
        mediaUrl:
            'https://res.cloudinary.com/dsxhrelpu/image/upload/v1793470261/posts/363152eb-78b7-4625-9f6e-e13dc8da45d2/oqlc9tc0nfbcirkrd5bm.jpg',
        isVideo: false,
        lastUpdated: 'Recently',
      ),
    ],
  );

  static final UserPortfolioState _defaultProductionPortfolio = UserPortfolioState(
    videos: [
      WorkMediaItem(
        id: '33333333-0000-0000-0000-000000000001',
        title: 'Production House Showreel',
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        mediaUrl:
            'https://res.cloudinary.com/dsxhrelpu/image/upload/v1793356951/posts/4f668c94-c9df-4db2-b844-b7ad0a981fde/zdfmhy6cauwtc0msvz7u.png',
        isVideo: true,
        lastUpdated: 'Recently',
      ),
    ],
    photos: [
      WorkMediaItem(
        id: '33333333-0000-0000-0000-000000000002',
        title: 'Studio Facilities & Soundstage',
        url:
            'https://res.cloudinary.com/dsxhrelpu/image/upload/v1793356951/posts/4f668c94-c9df-4db2-b844-b7ad0a981fde/zdfmhy6cauwtc0msvz7u.png',
        mediaUrl:
            'https://res.cloudinary.com/dsxhrelpu/image/upload/v1793356951/posts/4f668c94-c9df-4db2-b844-b7ad0a981fde/zdfmhy6cauwtc0msvz7u.png',
        isVideo: false,
        lastUpdated: 'Recently',
      ),
    ],
  );

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
  final Map<String, int> _followersCounts = {};
  final Map<String, Set<String>> _followingSets = {};
  final Map<String, Set<String>> _deletedConvsByUser = {};
  final List<CastingCallModel> _castingCalls = [];
  final List<CastingApplicationModel> _castingApplications = [];
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
    final clean = id.trim();
    return clean == 'actor' ||
        clean == actorDefaultId ||
        clean == realActorId ||
        clean == '00000000-0000-0000-0000-000000000001';
  }

  bool isDirectorId(String id) {
    final clean = id.trim();
    return clean == alexanderId ||
        clean == realDirectorId ||
        clean == 'a1111111-1111-1111-1111-111111111111';
  }

  bool isProductionId(String id) {
    final clean = id.trim();
    return clean == filmfareId ||
        clean == realProductionId ||
        clean == 'filmfare' ||
        clean == 'b2222222-2222-2222-2222-222222222222';
  }

  bool isSamePersona(String id1, String id2) {
    if (id1 == id2) return true;
    final clean1 = id1.trim();
    final clean2 = id2.trim();
    if (clean1 == clean2) return true;

    final actorAliases = {
      actorDefaultId,
      'actor',
      realActorId,
      '00000000-0000-0000-0000-000000000001',
    };
    if (actorAliases.contains(clean1) && actorAliases.contains(clean2)) return true;

    final dirAliases = {
      alexanderId,
      realDirectorId,
      'a1111111-1111-1111-1111-111111111111',
    };
    if (dirAliases.contains(clean1) && dirAliases.contains(clean2)) return true;

    final prodAliases = {
      filmfareId,
      'filmfare',
      realProductionId,
      'b2222222-2222-2222-2222-222222222222',
    };
    if (prodAliases.contains(clean1) && prodAliases.contains(clean2)) return true;

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (clean1 == user.id && clean2 == _activePersonaId) return true;
      if (clean2 == user.id && clean1 == _activePersonaId) return true;
    }
    return false;
  }

  UserPersona getActorPersona() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && isActorId(user.id)) {
      if (_personas.containsKey(user.id)) {
        final p = _personas[user.id]!;
        if (p.name.trim().isNotEmpty && p.name != 'Muhammad Wajahat') {
          return p;
        }
      }
    }
    return _personas[realActorId] ??
        _personas[actorDefaultId] ??
        _personas['actor'] ??
        UserPersonaNotifier.personaActor;
  }

  UserPersona getPersona(String id) {
    if (isActorId(id)) return getActorPersona();
    if (isDirectorId(id)) {
      return _personas[realDirectorId] ??
          _personas[alexanderId] ??
          UserPersonaNotifier.personaAlexander;
    }
    if (isProductionId(id)) {
      return _personas[realProductionId] ??
          _personas[filmfareId] ??
          UserPersonaNotifier.personaFilmFare;
    }
    if (_personas.containsKey(id)) return _personas[id]!;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.id == id) {
      return getActorPersona();
    }
    return getActorPersona();
  }

  bool hasPersona(String id) {
    return isActorId(id) ||
        isDirectorId(id) ||
        isProductionId(id) ||
        _personas.containsKey(id);
  }

  UserPersona getActivePersona() {
    if (_activePersonaId.isNotEmpty && _personas.containsKey(_activePersonaId)) {
      return _personas[_activePersonaId]!;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && _personas.containsKey(user.id)) {
      return _personas[user.id]!;
    }
    return getActorPersona();
  }

  List<UserPersona> get allPersonas {
    final list = <UserPersona>[];
    final active = getActivePersona();
    if (active.id.isNotEmpty) {
      list.add(active);
    }
    for (final id in [realActorId, realDirectorId, realProductionId]) {
      final p = getPersona(id);
      if (p.id.isNotEmpty && !list.any((x) => isSamePersona(x.id, p.id))) {
        list.add(p);
      }
    }
    return list;
  }

  // ─── Follower & Following Queries ────────────────────────────

  int getFollowersCount(String targetId) {
    return _followersCounts[targetId] ?? 0;
  }

  void setFollowersCount(String targetId, int count) {
    _followersCounts[targetId] = count;
    _flush();
    notifyListeners();
  }

  Set<String> getFollowingSet(String userId) {
    return _followingSets[userId] ?? <String>{};
  }

  void setFollowingSet(String userId, Set<String> targetIds) {
    _followingSets[userId] = Set<String>.from(targetIds);
    _flush();
    notifyListeners();
  }

  void setActivePersonaId(String id) {
    _activePersonaId = id;
    _flush();
  }

  bool isConvDeletedForUser(String convId, String userId) {
    return _deletedConvsByUser[userId]?.contains(convId) ?? false;
  }

  void markConvDeletedForUser(String convId, String userId) {
    _deletedConvsByUser.putIfAbsent(userId, () => <String>{}).add(convId);
    _flush();
  }

  void unmarkConvDeletedForUser(String convId, String userId) {
    _deletedConvsByUser[userId]?.remove(convId);
    _flush();
  }

  Set<String> getDeletedConvsForUser(String userId) {
    return _deletedConvsByUser[userId] ?? <String>{};
  }

  void savePersona(UserPersona updated) {
    final user = Supabase.instance.client.auth.currentUser;
    final isDir = isDirectorId(updated.id);
    final isProd = isProductionId(updated.id);
    final jsonStr = jsonEncode(updated.toJson());

    if (isDir) {
      _personas[updated.id] = updated;
      _personas[realDirectorId] = updated;
      _personas[alexanderId] = updated;
      _prefs.setString('persona_profile_${updated.id}', jsonStr);
      _prefs.setString('persona_profile_$realDirectorId', jsonStr);
      _prefs.setString('persona_profile_$alexanderId', jsonStr);
    } else if (isProd) {
      _personas[updated.id] = updated;
      _personas[realProductionId] = updated;
      _personas[filmfareId] = updated;
      _prefs.setString('persona_profile_${updated.id}', jsonStr);
      _prefs.setString('persona_profile_$realProductionId', jsonStr);
      _prefs.setString('persona_profile_$filmfareId', jsonStr);
    } else {
      _personas[updated.id] = updated;
      _personas[realActorId] = updated;
      _personas[actorDefaultId] = updated;
      _personas['actor'] = updated;
      _prefs.setString('persona_profile_${updated.id}', jsonStr);
      _prefs.setString('persona_profile_$realActorId', jsonStr);
      _prefs.setString('persona_profile_$actorDefaultId', jsonStr);
      _prefs.setString('persona_profile_actor', jsonStr);
    }

    _flush();
    if (user != null && (user.id == updated.id || isSamePersona(user.id, updated.id))) {
      _syncActorToCloud(updated);
    } else {
      _syncMockPersonasToCloud();
    }
    notifyListeners();
  }

  // ─── Portfolio Queries ──────────────────────────────────────

  UserPortfolioState _resolveDefaultPortfolio(String id) {
    if (isDirectorId(id)) return _defaultDirectorPortfolio;
    if (isProductionId(id)) return _defaultProductionPortfolio;
    if (isActorId(id)) return _defaultActorPortfolio;

    final p = _personas[id];
    if (p != null) {
      final role = p.role.toLowerCase();
      if (role.contains('director') || role.contains('filmmaker')) {
        return _defaultDirectorPortfolio;
      }
      if (role.contains('production') || role.contains('studio')) {
        return _defaultProductionPortfolio;
      }
      if (role.contains('actor')) {
        return _defaultActorPortfolio;
      }
    }
    return _defaultActorPortfolio;
  }

  UserPortfolioState getPortfolio(String id) {
    final defaultPort = _resolveDefaultPortfolio(id);

    UserPortfolioState? candidate;
    if (_portfolios.containsKey(id)) {
      candidate = _portfolios[id]!;
    } else {
      final fromPrefs = _prefs.getString('user_work_portfolio_$id');
      if (fromPrefs != null && fromPrefs.isNotEmpty) {
        try {
          candidate = UserPortfolioState.fromJson(
            jsonDecode(fromPrefs) as Map<String, dynamic>,
          );
        } catch (_) {}
      }
    }

    if (candidate != null) {
      final effectiveVideos =
          candidate.videos.isNotEmpty ? candidate.videos : defaultPort.videos;
      final effectivePhotos =
          candidate.photos.isNotEmpty ? candidate.photos : defaultPort.photos;
      final merged = candidate.copyWith(
        videos: effectiveVideos,
        photos: effectivePhotos,
      );
      _portfolios[id] = merged;
      return merged;
    }

    if (isDirectorId(id)) {
      if (_portfolios.containsKey(realDirectorId)) {
        return getPortfolio(realDirectorId);
      }
      return _defaultDirectorPortfolio;
    }
    if (isProductionId(id)) {
      if (_portfolios.containsKey(realProductionId)) {
        return getPortfolio(realProductionId);
      }
      return _defaultProductionPortfolio;
    }
    if (isActorId(id)) {
      if (_portfolios.containsKey(realActorId)) {
        return getPortfolio(realActorId);
      }
      return _defaultActorPortfolio;
    }

    return defaultPort;
  }

  void savePortfolio(String id, UserPortfolioState updated) {
    final user = Supabase.instance.client.auth.currentUser;
    final defaultPort = _resolveDefaultPortfolio(id);

    final safeVideos =
        updated.videos.isNotEmpty ? updated.videos : defaultPort.videos;
    final safePhotos =
        updated.photos.isNotEmpty ? updated.photos : defaultPort.photos;
    final safeUpdated =
        updated.copyWith(videos: safeVideos, photos: safePhotos);

    // Ensure all media items have valid RFC 4122 v4 UUIDs for Postgres compatibility
    final sanitizedVideos = safeUpdated.videos.map((v) {
      if (ConnectionRepository.isValidUuid(v.id)) return v;
      return v.copyWith(id: ChatRepository.generateUuid());
    }).toList();
    final sanitizedPhotos = safeUpdated.photos.map((p) {
      if (ConnectionRepository.isValidUuid(p.id)) return p;
      return p.copyWith(id: ChatRepository.generateUuid());
    }).toList();
    final cleanUpdated = UserPortfolioState(videos: sanitizedVideos, photos: sanitizedPhotos);

    final jsonStr = jsonEncode(cleanUpdated.toJson());

    _portfolios[id] = cleanUpdated;
    _prefs.setString('user_work_portfolio_$id', jsonStr);

    if (isActorId(id)) {
      _portfolios['actor'] = cleanUpdated;
      _portfolios[actorDefaultId] = cleanUpdated;
      _prefs.setString('user_work_portfolio_actor', jsonStr);
      _prefs.setString('user_work_portfolio_$actorDefaultId', jsonStr);
    }

    _flush();
    if (user != null && (id == user.id || id == _activePersonaId || isActorId(id))) {
      _syncActorPortfolioToCloud(cleanUpdated);
    }
    notifyListeners();
  }

  // ─── Casting Calls & Applications Queries ──────────────────

  List<CastingCallModel> getCastingCalls() {
    return List.unmodifiable(_castingCalls);
  }

  void saveCastingCalls(List<CastingCallModel> calls) {
    _castingCalls
      ..clear()
      ..addAll(calls);
    _flush();
    notifyListeners();
  }

  List<CastingApplicationModel> getCastingApplications() {
    return List.unmodifiable(_castingApplications);
  }

  void saveCastingApplications(List<CastingApplicationModel> apps) {
    _castingApplications
      ..clear()
      ..addAll(apps);
    _flush();
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
              final p = UserPersona.fromJson(
                entry.value as Map<String, dynamic>,
              );
              if (p.name.trim().isNotEmpty && p.name != 'Muhammad Wajahat') {
                _personas[entry.key] = p;
              }
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

        // Followers Counts
        if (decoded['followers_counts'] is Map) {
          final fMap = decoded['followers_counts'] as Map<String, dynamic>;
          for (final entry in fMap.entries) {
            final val = int.tryParse(entry.value.toString());
            if (val != null) _followersCounts[entry.key] = val;
          }
        }

        // Following Sets
        if (decoded['following_sets'] is Map) {
          final sMap = decoded['following_sets'] as Map<String, dynamic>;
          for (final entry in sMap.entries) {
            if (entry.value is List) {
              _followingSets[entry.key] = (entry.value as List)
                  .map((e) => e.toString())
                  .toSet();
            }
          }
        }

        // Deleted conversations by user
        if (decoded['deleted_convs_by_user'] is Map) {
          final dMap = decoded['deleted_convs_by_user'] as Map<String, dynamic>;
          for (final entry in dMap.entries) {
            if (entry.value is List) {
              _deletedConvsByUser[entry.key] = (entry.value as List)
                  .map((e) => e.toString())
                  .toSet();
            }
          }
        }

        // Casting Calls
        if (decoded['casting_calls'] is List) {
          final cList = decoded['casting_calls'] as List<dynamic>;
          _castingCalls.clear();
          for (final item in cList) {
            try {
              final c =
                  CastingCallModel.fromJson(item as Map<String, dynamic>);
              if (!isSeedCall(c.id, c.projectTitle, c.authorId)) {
                _castingCalls.add(c);
              }
            } catch (_) {}
          }
        }

        // Casting Applications
        if (decoded['casting_applications'] is List) {
          final aList = decoded['casting_applications'] as List<dynamic>;
          _castingApplications.clear();
          for (final item in aList) {
            try {
              final a = CastingApplicationModel.fromJson(
                  item as Map<String, dynamic>);
              if (!isSeedApp(a.id, a.castingCallId, a.projectTitle)) {
                _castingApplications.add(a);
              }
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
    final ids = [
      'actor',
      actorDefaultId,
      realActorId,
      alexanderId,
      realDirectorId,
      filmfareId,
      realProductionId,
      jeremiahId,
      singerId,
    ];
    if (user != null && !ids.contains(user.id)) {
      ids.insert(0, user.id);
    }
    for (final id in ids) {
      final pStr = _prefs.getString('persona_profile_$id');
      if (pStr != null && pStr.trim().isNotEmpty) {
        try {
          final p = UserPersona.fromJson(
            jsonDecode(pStr) as Map<String, dynamic>,
          );
          if (p.name.isNotEmpty && p.name != 'Muhammad Wajahat') {
            _personas[id] = p;
          }
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

    // Also scan all dynamically saved personas and portfolios
    for (final k in _prefs.getKeys()) {
      if (k.startsWith('persona_profile_')) {
        final id = k.substring('persona_profile_'.length);
        if (!_personas.containsKey(id)) {
          final pStr = _prefs.getString(k);
          if (pStr != null && pStr.trim().isNotEmpty) {
            try {
              final p = UserPersona.fromJson(
                jsonDecode(pStr) as Map<String, dynamic>,
              );
              if (p.name.isNotEmpty && p.name != 'Muhammad Wajahat') {
                _personas[id] = p;
              }
            } catch (_) {}
          }
        }
      } else if (k.startsWith('user_work_portfolio_')) {
        final id = k.substring('user_work_portfolio_'.length);
        if (!_portfolios.containsKey(id)) {
          final portStr = _prefs.getString(k);
          if (portStr != null && portStr.trim().isNotEmpty) {
            try {
              _portfolios[id] = UserPortfolioState.fromJson(
                jsonDecode(portStr) as Map<String, dynamic>,
              );
            } catch (_) {}
          }
        }
      }
    }

    final callsStr = _prefs.getString('you_too_art_casting_calls_v2');
    if (callsStr != null && callsStr.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(callsStr) as List<dynamic>;
        final prefCalls = <CastingCallModel>[];
        for (final item in decoded) {
          try {
            final c =
                CastingCallModel.fromJson(item as Map<String, dynamic>);
            if (!isSeedCall(c.id, c.projectTitle, c.authorId)) {
              prefCalls.add(c);
            }
          } catch (_) {}
        }
        if (prefCalls.isNotEmpty) {
          final Map<String, CastingCallModel> callMap = {};
          for (final c in prefCalls) {
            callMap[c.id] = c;
          }
          for (final c in _castingCalls) {
            callMap.putIfAbsent(c.id, () => c);
          }
          _castingCalls
            ..clear()
            ..addAll(callMap.values);
        }
      } catch (_) {}
    }

    final appsStr = _prefs.getString('you_too_art_casting_apps_v2');
    if (appsStr != null && appsStr.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(appsStr) as List<dynamic>;
        final prefApps = <CastingApplicationModel>[];
        for (final item in decoded) {
          try {
            final a =
                CastingApplicationModel.fromJson(item as Map<String, dynamic>);
            if (!isSeedApp(a.id, a.castingCallId, a.projectTitle)) {
              prefApps.add(a);
            }
          } catch (_) {}
        }
        if (prefApps.isNotEmpty) {
          final Map<String, CastingApplicationModel> appMap = {};
          for (final a in prefApps) {
            appMap[a.id] = a;
          }
          for (final a in _castingApplications) {
            appMap.putIfAbsent(a.id, () => a);
          }
          _castingApplications
            ..clear()
            ..addAll(appMap.values);
        }
      } catch (_) {}
    }

    final savedId = _prefs.getString('active_user_persona_id');
    if (savedId != null && hasPersona(savedId)) {
      _activePersonaId = savedId;
    } else if (user != null && _personas.containsKey(user.id)) {
      _activePersonaId = user.id;
    }
  }

  void _ensureDefaultsLoaded() {
    final actor = UserPersonaNotifier.personaActor;
    final director = UserPersonaNotifier.personaAlexander;
    final prod = UserPersonaNotifier.personaFilmFare;

    // Ensure real test profiles are never overwritten by stale/dummy persona data
    for (final id in [actorDefaultId, 'actor', realActorId]) {
      final existing = _personas[id];
      if (existing == null || existing.name == 'Hamza Ali' || existing.name.isEmpty) {
        _personas[id] = actor.copyWith(id: id);
      }
    }

    for (final id in [alexanderId, realDirectorId]) {
      final existing = _personas[id];
      if (existing == null || existing.name == 'Zaid Khan' || existing.name.isEmpty) {
        _personas[id] = director.copyWith(id: id);
      }
    }

    for (final id in [filmfareId, realProductionId]) {
      final existing = _personas[id];
      if (existing == null || existing.name == 'SkyPulse Studios' || existing.name.isEmpty) {
        _personas[id] = prod.copyWith(id: id);
      }
    }

    _personas.putIfAbsent(jeremiahId, () => UserPersonaNotifier.personaJeremiah);
    _personas.putIfAbsent(singerId, () => UserPersonaNotifier.personaSinger);

    // Populate default portfolios if missing or empty
    for (final id in [actorDefaultId, 'actor', realActorId]) {
      final p = _portfolios[id];
      if (p == null || (p.videos.isEmpty && p.photos.isEmpty)) {
        _portfolios[id] = _defaultActorPortfolio;
      } else {
        final videos = p.videos.isNotEmpty ? p.videos : _defaultActorPortfolio.videos;
        final photos = p.photos.isNotEmpty ? p.photos : _defaultActorPortfolio.photos;
        _portfolios[id] = p.copyWith(videos: videos, photos: photos);
      }
    }

    for (final id in [alexanderId, realDirectorId]) {
      final p = _portfolios[id];
      if (p == null || (p.videos.isEmpty && p.photos.isEmpty)) {
        _portfolios[id] = _defaultDirectorPortfolio;
      } else {
        final videos = p.videos.isNotEmpty ? p.videos : _defaultDirectorPortfolio.videos;
        final photos = p.photos.isNotEmpty ? p.photos : _defaultDirectorPortfolio.photos;
        _portfolios[id] = p.copyWith(videos: videos, photos: photos);
      }
    }

    for (final id in [filmfareId, realProductionId]) {
      final p = _portfolios[id];
      if (p == null || (p.videos.isEmpty && p.photos.isEmpty)) {
        _portfolios[id] = _defaultProductionPortfolio;
      } else {
        final videos = p.videos.isNotEmpty ? p.videos : _defaultProductionPortfolio.videos;
        final photos = p.photos.isNotEmpty ? p.photos : _defaultProductionPortfolio.photos;
        _portfolios[id] = p.copyWith(videos: videos, photos: photos);
      }
    }
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
        'followers_counts': _followersCounts,
        'following_sets': {
          for (final e in _followingSets.entries) e.key: e.value.toList(),
        },
        'deleted_convs_by_user': {
          for (final e in _deletedConvsByUser.entries) e.key: e.value.toList(),
        },
        'casting_calls': _castingCalls.map((c) => c.toJson()).toList(),
        'casting_applications':
            _castingApplications.map((a) => a.toJson()).toList(),
      };

      final encoded = jsonEncode(data);

      // 1. Write to platform storage driver (File on desktop, chunked cookies/localStorage on web)
      PlatformStorageDriver.writeRawData(encoded);

      // 2. Write to SharedPreferences master snapshot
      _prefs.setString(_masterKey, encoded);

      // 3. Write individual keys for every persona, portfolio, calls and apps
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
      _prefs.setString(
        'you_too_art_casting_calls_v2',
        jsonEncode(_castingCalls.map((c) => c.toJson()).toList()),
      );
      _prefs.setString(
        'you_too_art_casting_apps_v2',
        jsonEncode(_castingApplications.map((a) => a.toJson()).toList()),
      );
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
          if (decoded['casting_calls'] is List) {
            final cList = decoded['casting_calls'] as List<dynamic>;
            final existingIds = _castingCalls.map((c) => c.id).toSet();
            for (final item in cList) {
              try {
                final call =
                    CastingCallModel.fromJson(item as Map<String, dynamic>);
                if (!isSeedCall(call.id, call.projectTitle, call.authorId) &&
                    !existingIds.contains(call.id)) {
                  _castingCalls.add(call);
                  existingIds.add(call.id);
                }
              } catch (_) {}
            }
          }
          if (decoded['casting_applications'] is List) {
            final aList = decoded['casting_applications'] as List<dynamic>;
            final existingIds = _castingApplications.map((a) => a.id).toSet();
            for (final item in aList) {
              try {
                final app = CastingApplicationModel.fromJson(
                    item as Map<String, dynamic>);
                if (!isSeedApp(app.id, app.castingCallId, app.projectTitle) &&
                    !existingIds.contains(app.id)) {
                  _castingApplications.add(app);
                  existingIds.add(app.id);
                }
              } catch (_) {}
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
            final item = WorkMediaItem.fromJson(row);
            if (item.isVideo) {
              videos.add(item);
            } else {
              photos.add(item);
            }
          }
          final dbPort = UserPortfolioState(videos: videos, photos: photos);
          final userRole = ((user.userMetadata?['role'] as String?) ?? '').toLowerCase();

          if (user.id == realDirectorId || userRole.contains('director')) {
            _portfolios[user.id] = dbPort;
            _portfolios[realDirectorId] = dbPort;
            _portfolios[alexanderId] = dbPort;
          } else if (user.id == realProductionId || userRole.contains('production') || userRole.contains('studio')) {
            _portfolios[user.id] = dbPort;
            _portfolios[realProductionId] = dbPort;
            _portfolios[filmfareId] = dbPort;
          } else if (user.id == realActorId) {
            _portfolios['actor'] = dbPort;
            _portfolios[actorDefaultId] = dbPort;
            _portfolios[realActorId] = dbPort;
            _portfolios[user.id] = dbPort;
          } else {
            _portfolios[user.id] = dbPort;
          }
        } else {
          // If remote portfolio_items is empty, do NOT wipe local portfolio.
          // Check if local portfolio has items and push them to Supabase!
          final localPort = getPortfolio(user.id);
          if (localPort.videos.isNotEmpty || localPort.photos.isNotEmpty) {
            _syncActorPortfolioToCloud(localPort);
          }
        }
      } catch (_) {}

      // 2. Merge non-empty user metadata fields into persona
      final metaName = user.userMetadata?['name'] as String?;
      final metaRole = user.userMetadata?['role'] as String?;
      final metaAvatar = user.userMetadata?['avatar_url'] as String?;
      final metaBio = user.userMetadata?['bio'] as String?;
      final metaWebsite = user.userMetadata?['website'] as String?;
      final metaExp = user.userMetadata?['experience'] as String?;
      final metaLoc = user.userMetadata?['location'] as String?;

      _activePersonaId = user.id;

      final emailHandle = user.email != null && user.email!.contains('@')
          ? user.email!.split('@').first
          : 'User';

      final userRoleStr = ((metaRole != null && metaRole.isNotEmpty) ? metaRole : '').toLowerCase();
      final isDir = user.id == realDirectorId || user.id == alexanderId || userRoleStr.contains('director');
      final isProd = user.id == realProductionId || user.id == filmfareId || userRoleStr.contains('production') || userRoleStr.contains('studio');

      var currentPersona = UserPersona(
        id: user.id,
        name: (metaName != null && metaName.trim().isNotEmpty)
            ? metaName
            : emailHandle,
        email: user.email ?? '',
        role: (metaRole != null && metaRole.trim().isNotEmpty)
            ? metaRole
            : (isProd ? 'Production House' : (isDir ? 'Director' : 'actor')),
        avatarUrl: (metaAvatar != null && metaAvatar.trim().isNotEmpty)
            ? metaAvatar
            : '',
        isProductionHouse: isProd,
        bio: metaBio ?? '',
        website: metaWebsite ?? '',
        experience: metaExp ?? '',
        location: metaLoc ?? '',
      );

      if (user.id == realDirectorId || userRoleStr.contains('director')) {
        _personas[user.id] = currentPersona;
        _personas[realDirectorId] = currentPersona;
        _personas[alexanderId] = currentPersona;
      } else if (user.id == realProductionId || userRoleStr.contains('production') || userRoleStr.contains('studio')) {
        final p = currentPersona.copyWith(isProductionHouse: true);
        _personas[user.id] = p;
        _personas[realProductionId] = p;
        _personas[filmfareId] = p;
      } else if (user.id == realActorId) {
        _personas[user.id] = currentPersona;
        _personas[realActorId] = currentPersona;
        _personas[actorDefaultId] = currentPersona;
        _personas['actor'] = currentPersona;
      } else {
        _personas[user.id] = currentPersona;
      }

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
          final updatedWithRow = currentPersona.copyWith(
            name: combinedName.isNotEmpty ? combinedName : currentPersona.name,
            role: (row['role'] as String? ?? '').isNotEmpty && row['role'] != 'unset'
                ? row['role'] as String
                : currentPersona.role,
            bio: (row['bio'] as String? ?? '').isNotEmpty
                ? row['bio'] as String
                : currentPersona.bio,
            location: (row['location'] as String? ?? '').isNotEmpty
                ? row['location'] as String
                : currentPersona.location,
            avatarUrl: (row['profile_image_path'] as String? ?? '').isNotEmpty
                ? row['profile_image_path'] as String
                : currentPersona.avatarUrl,
          );

          if (user.id == realDirectorId || userRoleStr.contains('director')) {
            _personas[user.id] = updatedWithRow;
            _personas[realDirectorId] = updatedWithRow;
            _personas[alexanderId] = updatedWithRow;
          } else if (user.id == realProductionId || userRoleStr.contains('production') || userRoleStr.contains('studio')) {
            final p = updatedWithRow.copyWith(isProductionHouse: true);
            _personas[user.id] = p;
            _personas[realProductionId] = p;
            _personas[filmfareId] = p;
          } else if (user.id == realActorId) {
            _personas[user.id] = updatedWithRow;
            _personas[realActorId] = updatedWithRow;
            _personas[actorDefaultId] = updatedWithRow;
            _personas['actor'] = updatedWithRow;
          } else {
            _personas[user.id] = updatedWithRow;
          }
        }

        // Auto-upsert to users table with authenticated token
        final names = currentPersona.name.trim().split(' ');
        final firstName = names.first;
        final lastName = names.length > 1 ? names.skip(1).join(' ') : '';
        await client.from('users').upsert({
          'id': user.id,
          'name': currentPersona.name,
          'first_name': firstName,
          'last_name': lastName,
          'email': user.email ?? currentPersona.email,
          'role': currentPersona.role.isNotEmpty ? currentPersona.role : (isProd ? 'production_house' : (isDir ? 'director' : 'actor')),
          'bio': currentPersona.bio,
          'profile_image_path': currentPersona.avatarUrl,
          'location': currentPersona.location,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
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
            'casting_calls_snapshot':
                jsonEncode(_castingCalls.map((c) => c.toJson()).toList()),
            'casting_apps_snapshot':
                jsonEncode(_castingApplications.map((a) => a.toJson()).toList()),
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
      final remoteRows = await client
          .from('portfolio_items')
          .select('id')
          .eq('user_id', user.id);
      final currentIds = {
        ...portfolio.videos.map((v) => v.id),
        ...portfolio.photos.map((p) => p.id),
      };
      for (final row in remoteRows) {
        final rId = row['id']?.toString() ?? '';
        if (rId.isNotEmpty && !currentIds.contains(rId)) {
          await client.from('portfolio_items').delete().eq('id', rId);
        }
      }

      for (final video in portfolio.videos) {
        final vId = ConnectionRepository.isValidUuid(video.id)
            ? video.id
            : ChatRepository.generateUuid();
        await client.from('portfolio_items').upsert({
          'id': vId,
          'user_id': user.id,
          'title': video.title,
          'media_url': video.mediaUrl,
          'media_type': 'video',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      for (final photo in portfolio.photos) {
        final pId = ConnectionRepository.isValidUuid(photo.id)
            ? photo.id
            : ChatRepository.generateUuid();
        await client.from('portfolio_items').upsert({
          'id': pId,
          'user_id': user.id,
          'title': photo.title,
          'media_url': photo.mediaUrl,
          'media_type': 'photo',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  static bool isSeedCall(String id, [String? title, String? authorId]) {
    if (id.startsWith('call_') || id == 'my_call_1') {
      return true;
    }
    if (title == 'Echoes of Rawal' ||
        title == 'The Next Short Film' ||
        title == 'Lahore Tales' ||
        title == 'Melody in the Rain' ||
        title == 'Shadows & Dust' ||
        title == 'Midnight Sun') {
      return true;
    }
    if (authorId == 'james_geidt' ||
        authorId == 'angel_culhane' ||
        authorId == 'angel_culhane_2' ||
        authorId == 'filmfare' ||
        authorId == filmfareId ||
        authorId == alexanderId) {
      return true;
    }
    return false;
  }

  static bool isSeedApp(String id, [String? callId, String? title]) {
    if (id.startsWith('app_')) {
      return true;
    }
    if (callId != null && (callId.startsWith('call_') || callId == 'my_call_1')) {
      return true;
    }
    if (title == 'Echoes of Rawal' ||
        title == 'The Next Short Film' ||
        title == 'Lahore Tales' ||
        title == 'Melody in the Rain' ||
        title == 'Midnight Sun') {
      return true;
    }
    return false;
  }
}
