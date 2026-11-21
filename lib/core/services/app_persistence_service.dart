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

  static const UserPortfolioState emptyPortfolio =
      UserPortfolioState(videos: [], photos: []);

  static UserPortfolioState get defaultActorPortfolio => emptyPortfolio;
  static UserPortfolioState get defaultDirectorPortfolio => emptyPortfolio;
  static UserPortfolioState get defaultProductionPortfolio => emptyPortfolio;

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

    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id.trim();

    final actorAliases = {
      realActorId,
      'actor',
      '00000000-0000-0000-0000-000000000001',
      if (userId != null && (userId == realActorId || userId == '00000000-0000-0000-0000-000000000001')) userId,
    };
    if (actorAliases.contains(clean1) && actorAliases.contains(clean2)) return true;

    final dirAliases = {
      realDirectorId,
      'alexander',
      'a1111111-1111-1111-1111-111111111111',
      if (userId != null && (userId == realDirectorId || userId == 'a1111111-1111-1111-1111-111111111111')) userId,
    };
    if (dirAliases.contains(clean1) && dirAliases.contains(clean2)) return true;

    final prodAliases = {
      realProductionId,
      'filmfare',
      'b2222222-2222-2222-2222-222222222222',
      if (userId != null && (userId == realProductionId || userId == 'b2222222-2222-2222-2222-222222222222')) userId,
    };
    if (prodAliases.contains(clean1) && prodAliases.contains(clean2)) return true;

    return false;
  }

  UserPersona getActorPersona() => getActivePersona();

  UserPersona getPersona(String id) {
    if (_personas.containsKey(id)) return _personas[id]!;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.id == id) {
      return getActivePersona();
    }
    return UserPersona(
      id: id,
      name: '',
      email: '',
      role: '',
      avatarUrl: '',
    );
  }

  UserPersona getPersonaById(String id) => getPersona(id);

  bool hasPersona(String id) {
    return _personas.containsKey(id) ||
        (Supabase.instance.client.auth.currentUser?.id == id);
  }

  UserPersona getActivePersona() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (_personas.containsKey(user.id)) {
        return _personas[user.id]!;
      }
      final metaName = user.userMetadata?['name'] as String? ?? '';
      final metaRole = user.userMetadata?['role'] as String? ?? '';
      final metaAvatar = user.userMetadata?['avatar_url'] as String? ?? '';
      final emailPrefix = user.email?.split('@').first ?? 'User';
      return UserPersona(
        id: user.id,
        name: metaName.isNotEmpty ? metaName : emailPrefix,
        email: user.email ?? '',
        role: metaRole,
        avatarUrl: metaAvatar,
        isProductionHouse: metaRole.toLowerCase().contains('production') ||
            metaRole.toLowerCase().contains('studio'),
      );
    }
    if (_activePersonaId.isNotEmpty && _personas.containsKey(_activePersonaId)) {
      return _personas[_activePersonaId]!;
    }
    return const UserPersona(id: '', name: '', email: '', role: '', avatarUrl: '');
  }

  List<UserPersona> get allPersonas {
    final list = <UserPersona>[];
    final active = getActivePersona();
    if (active.id.isNotEmpty) {
      list.add(active);
    }
    for (final p in _personas.values) {
      if (p.id.isNotEmpty && !list.any((x) => x.id == p.id)) {
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

  String get activePersonaId => _activePersonaId;

  void setActivePersonaId(String id) {
    _activePersonaId = id;
    _flush();
  }

  void clearActiveSession() {
    _activePersonaId = '';
    _prefs.remove('active_user_persona_id');
    notifyListeners();
  }

  void deletePersona(String id) {
    _personas.remove(id);
    _portfolios.remove(id);
    _followersCounts.remove(id);
    _followingSets.remove(id);
    _deletedConvsByUser.remove(id);
    _prefs.remove('persona_profile_$id');
    _prefs.remove('portfolio_$id');
    if (_activePersonaId == id) {
      _activePersonaId = '';
      _prefs.remove('active_user_persona_id');
    }
    _flush();
    notifyListeners();
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
    final jsonStr = jsonEncode(updated.toJson());

    _personas[updated.id] = updated;
    _prefs.setString('persona_profile_${updated.id}', jsonStr);

    _flush();
    if (user != null && user.id == updated.id) {
      _syncUserToCloud(updated);
    }
    notifyListeners();
  }

  // ─── Portfolio Queries ──────────────────────────────────────

  UserPortfolioState getPortfolio(String id) {
    if (_portfolios.containsKey(id)) {
      final cached = _portfolios[id]!;
      if (cached.videos.any((v) => v.title.contains('Dramatic Monologue') || v.mediaUrl.contains('cloudinary')) ||
          cached.photos.any((p) => p.title.contains('Dramatic Portrait') || p.mediaUrl.contains('cloudinary'))) {
        _portfolios[id] = emptyPortfolio;
        return emptyPortfolio;
      }
      return cached;
    }
    final fromPrefs = _prefs.getString('user_work_portfolio_$id');
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      try {
        final p = UserPortfolioState.fromJson(
          jsonDecode(fromPrefs) as Map<String, dynamic>,
        );
        if (p.videos.any((v) => v.title.contains('Dramatic Monologue') || v.mediaUrl.contains('cloudinary')) ||
            p.photos.any((p) => p.title.contains('Dramatic Portrait') || p.mediaUrl.contains('cloudinary'))) {
          _portfolios[id] = emptyPortfolio;
          _prefs.remove('user_work_portfolio_$id');
          return emptyPortfolio;
        }
        _portfolios[id] = p;
        return p;
      } catch (_) {}
    }
    return emptyPortfolio;
  }

  void setCachedPortfolio(String id, UserPortfolioState portfolio) {
    _portfolios[id] = portfolio;
    notifyListeners();
  }

  void savePortfolio(String id, UserPortfolioState updated) {
    // Sanitize out any dummy rabbit media
    final cleanVideos = updated.videos.where((v) =>
        !v.title.contains('Dramatic Monologue') && !v.mediaUrl.contains('cloudinary')).toList();
    final cleanPhotos = updated.photos.where((p) =>
        !p.title.contains('Dramatic Portrait') && !p.mediaUrl.contains('cloudinary')).toList();

    // Ensure all media items have valid RFC 4122 v4 UUIDs for Postgres compatibility
    final sanitizedVideos = cleanVideos.map((v) {
      if (ConnectionRepository.isValidUuid(v.id)) return v;
      return v.copyWith(id: ChatRepository.generateUuid());
    }).toList();
    final sanitizedPhotos = cleanPhotos.map((p) {
      if (ConnectionRepository.isValidUuid(p.id)) return p;
      return p.copyWith(id: ChatRepository.generateUuid());
    }).toList();
    final cleanUpdated = UserPortfolioState(videos: sanitizedVideos, photos: sanitizedPhotos);

    final jsonStr = jsonEncode(cleanUpdated.toJson());

    _portfolios[id] = cleanUpdated;
    _prefs.setString('user_work_portfolio_$id', jsonStr);

    _flush();
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
              final n = p.name.trim().toLowerCase();
              if (n.isNotEmpty &&
                  n != 'muhammad wajahat' &&
                  !n.contains('sara ahmed') &&
                  !n.contains('bilal tariq') &&
                  entry.key != jeremiahId &&
                  entry.key != singerId) {
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
    final ids = <String>[];
    if (user != null) {
      ids.add(user.id);
    }
    for (final id in ids) {
      final pStr = _prefs.getString('persona_profile_$id');
      if (pStr != null && pStr.trim().isNotEmpty) {
        try {
          final p = UserPersona.fromJson(
            jsonDecode(pStr) as Map<String, dynamic>,
          );
          final n = p.name.trim().toLowerCase();
          if (n.isNotEmpty &&
              !n.contains('wajahat') &&
              !n.contains('sara ahmed') &&
              !n.contains('bilal tariq')) {
            _personas[id] = p;
          } else {
            _prefs.remove('persona_profile_$id');
          }
        } catch (_) {}
      }

      final portStr = _prefs.getString('user_work_portfolio_$id');
      if (portStr != null && portStr.trim().isNotEmpty) {
        try {
          final port = UserPortfolioState.fromJson(
            jsonDecode(portStr) as Map<String, dynamic>,
          );
          if (!port.videos.any((v) => v.title.contains('Dramatic Monologue') || v.mediaUrl.contains('cloudinary')) &&
              !port.photos.any((p) => p.title.contains('Dramatic Portrait') || p.mediaUrl.contains('cloudinary'))) {
            _portfolios[id] = port;
          } else {
            _prefs.remove('user_work_portfolio_$id');
          }
        } catch (_) {}
      }
    }

    // Also scan all dynamically saved personas and portfolios
    for (final k in _prefs.getKeys().toList()) {
      if (k.startsWith('persona_profile_')) {
        final id = k.substring('persona_profile_'.length);
        final pStr = _prefs.getString(k);
        if (pStr != null && pStr.trim().isNotEmpty) {
          try {
            final p = UserPersona.fromJson(
              jsonDecode(pStr) as Map<String, dynamic>,
            );
            final n = p.name.trim().toLowerCase();
            if (n.isNotEmpty &&
                !n.contains('wajahat') &&
                !n.contains('sara ahmed') &&
                !n.contains('bilal tariq')) {
              if (!_personas.containsKey(id)) {
                _personas[id] = p;
              }
            } else {
              _prefs.remove(k);
              _personas.remove(id);
            }
          } catch (_) {}
        }
      } else if (k.startsWith('user_work_portfolio_')) {
        final id = k.substring('user_work_portfolio_'.length);
        final portStr = _prefs.getString(k);
        if (portStr != null && portStr.trim().isNotEmpty) {
          try {
            final port = UserPortfolioState.fromJson(
              jsonDecode(portStr) as Map<String, dynamic>,
            );
            if (!port.videos.any((v) => v.title.contains('Dramatic Monologue') || v.mediaUrl.contains('cloudinary')) &&
                !port.photos.any((p) => p.title.contains('Dramatic Portrait') || p.mediaUrl.contains('cloudinary'))) {
              if (!_portfolios.containsKey(id)) {
                _portfolios[id] = port;
              }
            } else {
              _prefs.remove(k);
              _portfolios.remove(id);
            }
          } catch (_) {}
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

    if (user != null) {
      _activePersonaId = user.id;
    } else {
      final savedId = _prefs.getString('active_user_persona_id');
      if (savedId != null && hasPersona(savedId)) {
        _activePersonaId = savedId;
      }
    }
  }

  void _ensureDefaultsLoaded() {
    // Portfolios start completely empty for all users.
    // Discard any residual rabbit dummy portfolio items from storage
    _portfolios.removeWhere((key, port) {
      return port.videos.any((v) => v.title.contains('Dramatic Monologue') || v.mediaUrl.contains('cloudinary')) ||
          port.photos.any((p) => p.title.contains('Dramatic Portrait') || p.mediaUrl.contains('cloudinary'));
    });
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

      // Check Supabase portfolio_items table for user's portfolio
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
            if (item.title.contains('Dramatic Monologue') ||
                item.title.contains('Dramatic Portrait') ||
                item.mediaUrl.contains('cloudinary')) {
              continue;
            }
            if (item.isVideo) {
              videos.add(item);
            } else {
              photos.add(item);
            }
          }
          final dbPort = UserPortfolioState(videos: videos, photos: photos);
          _portfolios[user.id] = dbPort;
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
      _prefs.setString('active_user_persona_id', user.id);

      final emailHandle = user.email != null && user.email!.contains('@')
          ? user.email!.split('@').first
          : 'User';

      final cachedPersona = _personas[user.id];

      final userRoleStr = ((metaRole != null && metaRole.isNotEmpty) ? metaRole : (cachedPersona?.role ?? '')).toLowerCase();
      final isDir = userRoleStr.contains('director');
      final isProd = userRoleStr.contains('production') || userRoleStr.contains('studio') || (cachedPersona?.isProductionHouse ?? false);

      var currentPersona = UserPersona(
        id: user.id,
        name: (metaName != null && metaName.trim().isNotEmpty)
            ? metaName
            : (cachedPersona != null && cachedPersona.name.isNotEmpty ? cachedPersona.name : emailHandle),
        email: user.email ?? (cachedPersona?.email ?? ''),
        role: (metaRole != null && metaRole.trim().isNotEmpty)
            ? metaRole
            : (cachedPersona != null && cachedPersona.role.isNotEmpty && cachedPersona.role != 'unset'
                ? cachedPersona.role
                : (isProd ? 'Production House' : (isDir ? 'Director' : 'actor'))),
        avatarUrl: (metaAvatar != null && metaAvatar.trim().isNotEmpty)
            ? metaAvatar
            : (cachedPersona?.avatarUrl ?? ''),
        isProductionHouse: isProd,
        bio: (metaBio != null && metaBio.isNotEmpty)
            ? metaBio
            : (cachedPersona?.bio ?? ''),
        website: (metaWebsite != null && metaWebsite.isNotEmpty)
            ? metaWebsite
            : (cachedPersona?.website ?? ''),
        experience: (metaExp != null && metaExp.isNotEmpty)
            ? metaExp
            : (cachedPersona?.experience ?? ''),
        location: (metaLoc != null && metaLoc.isNotEmpty)
            ? metaLoc
            : (cachedPersona?.location ?? ''),
      );

      _personas[user.id] = currentPersona;

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
          final roleFromRow = row['role'] as String? ?? '';
          final isProdFromRow = roleFromRow.toLowerCase().contains('production') ||
              roleFromRow.toLowerCase().contains('studio') ||
              (row['incorporation_number'] != null && (row['incorporation_number'] as String).isNotEmpty);

          final updatedWithRow = currentPersona.copyWith(
            name: combinedName.isNotEmpty ? combinedName : currentPersona.name,
            role: roleFromRow.isNotEmpty && roleFromRow != 'unset'
                ? roleFromRow
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
            website: (row['website'] as String? ?? '').isNotEmpty
                ? row['website'] as String
                : currentPersona.website,
            experience: (row['experience'] as String? ?? '').isNotEmpty
                ? row['experience'] as String
                : currentPersona.experience,
            isProductionHouse: isProdFromRow || currentPersona.isProductionHouse,
          );

          currentPersona = updatedWithRow;
          _personas[user.id] = updatedWithRow;
          _prefs.setString('persona_profile_${user.id}', jsonEncode(updatedWithRow.toJson()));

          // If email is confirmed via email link or OTP, automatically ensure is_verified is true
          if (user.emailConfirmedAt != null && row['is_verified'] != true) {
            try {
              await client.from('users').update({'is_verified': true}).eq('id', user.id);
            } catch (_) {}
          }
        } else {
          // Only if user row DOES NOT exist in users table yet, create an initial record.
          final names = currentPersona.name.trim().split(' ');
          final firstName = names.first;
          final lastName = names.length > 1 ? names.skip(1).join(' ') : '';
          await client.from('users').insert({
            'id': user.id,
            'name': currentPersona.name,
            'first_name': firstName,
            'last_name': lastName,
            'email': user.email ?? currentPersona.email,
            'role': currentPersona.role.isNotEmpty && currentPersona.role != 'unset'
                ? currentPersona.role
                : (isProd ? 'production_house' : (isDir ? 'director' : 'actor')),
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      } catch (_) {}

      _ensureDefaultsLoaded();
      _flush();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('AppPersistenceService.syncWithSupabaseUser error: $e');
    }
  }

  Future<void> _syncUserToCloud(UserPersona persona) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || user.id != persona.id) return;

    try {
      final authData = <String, dynamic>{
        if (persona.name.trim().isNotEmpty) 'name': persona.name.trim(),
        if (persona.role.trim().isNotEmpty && persona.role != 'unset')
          'role': persona.role.trim(),
        if (persona.bio.trim().isNotEmpty) 'bio': persona.bio.trim(),
        if (persona.website.trim().isNotEmpty) 'website': persona.website.trim(),
        if (persona.experience.trim().isNotEmpty)
          'experience': persona.experience.trim(),
        if (persona.location.trim().isNotEmpty)
          'location': persona.location.trim(),
        if (persona.avatarUrl.trim().isNotEmpty)
          'avatar_url': persona.avatarUrl.trim(),
      };
      if (authData.isNotEmpty) {
        await client.auth.updateUser(UserAttributes(data: authData));
      }
    } catch (_) {}

    try {
      final names = persona.name.trim().split(' ');
      final firstName = names.first;
      final lastName = names.length > 1 ? names.skip(1).join(' ') : '';
      final dbUpdates = <String, dynamic>{
        if (persona.name.trim().isNotEmpty) 'name': persona.name.trim(),
        if (firstName.isNotEmpty) 'first_name': firstName,
        if (lastName.isNotEmpty) 'last_name': lastName,
        if (persona.role.trim().isNotEmpty && persona.role != 'unset')
          'role': persona.role.trim(),
        if (persona.bio.trim().isNotEmpty) 'bio': persona.bio.trim(),
        if (persona.location.trim().isNotEmpty)
          'location': persona.location.trim(),
        if (persona.avatarUrl.trim().isNotEmpty)
          'profile_image_path': persona.avatarUrl.trim(),
        if (persona.website.trim().isNotEmpty)
          'website': persona.website.trim(),
        if (persona.experience.trim().isNotEmpty)
          'experience': persona.experience.trim(),
      };
      if (dbUpdates.isNotEmpty) {
        try {
          await client.from('users').update(dbUpdates).eq('id', user.id);
        } catch (_) {
          final fallbackUpdates = Map<String, dynamic>.from(dbUpdates)
            ..remove('website')
            ..remove('experience');
          if (fallbackUpdates.isNotEmpty) {
            await client.from('users').update(fallbackUpdates).eq('id', user.id);
          }
        }
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
