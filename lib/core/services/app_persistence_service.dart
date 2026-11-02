import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
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

  static const String actorDefaultId = '00000000-0000-0000-0000-000000000001';
  static const String alexanderId = 'a1111111-1111-1111-1111-111111111111';
  static const String filmfareId = 'b2222222-2222-2222-2222-222222222222';
  static const String jeremiahId = 'c3333333-3333-3333-3333-333333333333';
  static const String singerId = 'd4444444-4444-4444-4444-444444444444';

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
    final hasPurgedV5 = prefs.getBool('purged_seed_personas_v5') ?? false;
    if (!hasPurgedV5) {
      PlatformStorageDriver.clearRawData();
      prefs.remove('active_user_persona_id');
      prefs.remove('is_test_role_logged_in');
      prefs.remove(_masterKey);
      prefs.remove('you_too_art_master_state_v3');
      for (final k in prefs.getKeys().where((k) => k.startsWith('persona_profile_') || k.startsWith('user_work_portfolio_')).toList()) {
        prefs.remove(k);
      }
      prefs.setBool('purged_seed_personas_v5', true);
    }
    final hasPurgedV4 = prefs.getBool('purged_seed_personas_v4') ?? false;
    if (!hasPurgedV4) {
      prefs.remove('active_user_persona_id');
      prefs.remove('is_test_role_logged_in');
      for (final k in prefs.getKeys().where((k) => k.startsWith('persona_profile_') || k.startsWith('user_work_portfolio_')).toList()) {
        prefs.remove(k);
      }
      prefs.setBool('purged_seed_personas_v4', true);
    }
    final hasPurgedV3 = prefs.getBool('purged_seed_data_v3') ?? false;
    if (!hasPurgedV3) {
      prefs.remove('you_too_art_casting_calls_v2');
      prefs.remove('you_too_art_casting_apps_v2');
      prefs.remove('saved_post_ids');
      prefs.setBool('purged_seed_data_v3', true);
    }
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
    return id == 'actor' || id == actorDefaultId;
  }

  bool isSamePersona(String id1, String id2) {
    if (id1 == id2) return true;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (id1 == user.id && (isActorId(id2) || id2 == _activePersonaId)) return true;
      if (id2 == user.id && (isActorId(id1) || id1 == _activePersonaId)) return true;
    }
    return isActorId(id1) && isActorId(id2);
  }

  UserPersona getActorPersona() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && _personas.containsKey(user.id)) {
      final p = _personas[user.id]!;
      if (p.name.trim().isNotEmpty && p.name != 'Hamza Ali' && p.name != 'Muhammad Wajahat') {
        return p;
      }
    }
    if (user != null) {
      final handle = user.email != null && user.email!.contains('@')
          ? user.email!.split('@').first
          : 'User';
      final p = UserPersona(
        id: user.id,
        name: user.userMetadata?['name'] as String? ?? handle,
        email: user.email ?? '',
        role: user.userMetadata?['role'] as String? ?? '',
        avatarUrl: user.userMetadata?['avatar_url'] as String? ?? '',
      );
      _personas[user.id] = p;
      return p;
    }
    return const UserPersona(
      id: '',
      name: '',
      email: '',
      role: '',
      avatarUrl: '',
    );
  }

  UserPersona getPersona(String id) {
    if (isActorId(id)) return getActorPersona();
    if (_personas.containsKey(id)) return _personas[id]!;
    return getActorPersona();
  }

  bool hasPersona(String id) {
    return _personas.containsKey(id);
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
    final active = getActivePersona();
    if (active.id.isEmpty) return [];
    return [active];
  }

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
    if (_portfolios.containsKey(id)) {
      return _portfolios[id]!;
    }
    final fromPrefs = _prefs.getString('user_work_portfolio_$id') ??
        _prefs.getString('user_work_portfolio_');
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      try {
        final decoded = UserPortfolioState.fromJson(
          jsonDecode(fromPrefs) as Map<String, dynamic>,
        );
        _portfolios[id] = decoded;
        return decoded;
      } catch (_) {}
    }
    return const UserPortfolioState(videos: [], photos: []);
  }

  void savePortfolio(String id, UserPortfolioState updated) {
    final user = Supabase.instance.client.auth.currentUser;
    final jsonStr = jsonEncode(updated.toJson());

    _portfolios[id] = updated;
    _prefs.setString('user_work_portfolio_$id', jsonStr);

    if (isActorId(id)) {
      _portfolios['actor'] = updated;
      _portfolios[actorDefaultId] = updated;
      _prefs.setString('user_work_portfolio_actor', jsonStr);
    }

    _flush();
    if (user != null && (id == user.id || id == _activePersonaId || isActorId(id))) {
      _syncActorPortfolioToCloud(updated);
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
              if (p.name == 'Hamza Ali' ||
                  p.name == 'Muhammad Wajahat' ||
                  p.name == 'Zaid Khan' ||
                  p.name == 'Alexander Vance' ||
                  p.name == 'Sara Ahmed' ||
                  p.name == 'Jeremiah Cole' ||
                  p.name == 'Bilal Tariq' ||
                  p.name == 'Aria Montgomery' ||
                  p.name == 'Filmfare Productions' ||
                  p.email.contains('@youtooart.com') ||
                  p.id == actorDefaultId ||
                  p.id == alexanderId ||
                  p.id == filmfareId ||
                  p.id == jeremiahId ||
                  p.id == singerId) {
                continue;
              }
              _personas[entry.key] = p;
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
    // 1. Purge legacy dummy personas
    _personas.removeWhere((key, p) =>
        p.name == 'Hamza Ali' ||
        p.name == 'Zaid Khan' ||
        p.name == 'SkyPulse Studios' ||
        p.name == 'Sara Ahmed' ||
        p.name == 'Bilal Tariq' ||
        p.name == 'Muhammad Wajahat' ||
        p.email == 'actor@youtooart.com' ||
        p.email == 'director@youtooart.com' ||
        p.email == 'production@youtooart.com' ||
        p.email == 'crew@youtooart.com' ||
        p.email == 'singer@youtooart.com');

    // 2. Purge legacy dummy portfolios
    _portfolios.removeWhere((key, port) =>
        port.videos.any((v) => v.title.contains('Gilgit-Baltistan')) ||
        port.videos.any((v) => v.title.contains('Dramatic Monologue')) ||
        key == 'actor' ||
        key == actorDefaultId ||
        key == alexanderId ||
        key == filmfareId ||
        key == jeremiahId ||
        key == singerId);

    // 3. Purge legacy dummy casting calls
    _castingCalls.removeWhere((c) => isSeedCall(c.id, c.projectTitle, c.authorId));

    // 4. Purge legacy dummy casting applications
    _castingApplications.removeWhere((a) => isSeedApp(a.id, a.castingCallId, a.projectTitle));
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

      _activePersonaId = user.id;

      final emailHandle = user.email != null && user.email!.contains('@')
          ? user.email!.split('@').first
          : 'User';

      var currentPersona = UserPersona(
        id: user.id,
        name: (metaName != null && metaName.trim().isNotEmpty)
            ? metaName
            : emailHandle,
        email: user.email ?? '',
        role: (metaRole != null && metaRole.trim().isNotEmpty)
            ? metaRole
            : '',
        avatarUrl: (metaAvatar != null && metaAvatar.trim().isNotEmpty)
            ? metaAvatar
            : '',
        bio: metaBio ?? '',
        website: metaWebsite ?? '',
        experience: metaExp ?? '',
        location: metaLoc ?? '',
      );

      _personas[user.id] = currentPersona;
      _personas['actor'] = currentPersona;
      _personas[actorDefaultId] = currentPersona;

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
          _personas[user.id] = updatedWithRow;
          _personas['actor'] = updatedWithRow;
          _personas[actorDefaultId] = updatedWithRow;
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
      for (final video in portfolio.videos) {
        if (video.id.isNotEmpty && video.id.length >= 30 && !video.id.startsWith('port_')) {
          await client.from('portfolio_items').upsert({
            'id': video.id,
            'user_id': user.id,
            'title': video.title,
            'media_url': video.mediaUrl,
            'media_type': 'video',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }
      for (final photo in portfolio.photos) {
        if (photo.id.isNotEmpty && photo.id.length >= 30 && !photo.id.startsWith('port_')) {
          await client.from('portfolio_items').upsert({
            'id': photo.id,
            'user_id': user.id,
            'title': photo.title,
            'media_url': photo.mediaUrl,
            'media_type': 'photo',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
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
