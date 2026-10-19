import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';

/// Centralized repository for managing user connections and follows.
/// Synchronizes seamlessly with Supabase Postgres while maintaining a persistent
/// local cache so testing multi-user flows works reliably offline or online.
class ConnectionRepository {
  final SupabaseClient _client;

  ConnectionRepository(this._client);

  SupabaseQueryBuilder get _db => _client.from(SupabaseTables.connections);

  static const String _connectionsPrefKey = 'yt_connections_store_v5';
  static const String _followingPrefKeyPrefix = 'yt_following_set_';

  static bool? _isSupabaseTableAvailable;

  static void resetSupabaseTableCheck() {
    _isSupabaseTableAvailable = null;
  }

  static bool isValidUuid(String id) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  bool _isActorId(String id) {
    if (id == UserPersonaNotifier.actorDefaultId) return true;
    final currentUid = _client.auth.currentUser?.id;
    if (currentUid != null && id == currentUid) return true;
    return false;
  }

  void _recordSupabaseError(dynamic e) {
    final str = e.toString();
    if (str.contains('PGRST205') ||
        str.contains('404') ||
        str.contains('Could not find the table')) {
      _isSupabaseTableAvailable = false;
      if (kDebugMode) {
        debugPrint(
          'Notice: Supabase table "connections" not found in cloud database. '
          'Operating in local persistent cache mode. Run 003_connections_system.sql in Supabase SQL editor to enable cloud syncing.',
        );
      }
    } else if (str.contains('400') || str.contains('violates foreign key')) {
      // Table exists but foreign key constraint rejects non-auth or unseeded IDs.
      // Operates safely with local persistent cache.
      if (kDebugMode) {
        debugPrint('ConnectionRepository local cache active for talent.');
      }
    } else if (kDebugMode) {
      debugPrint('ConnectionRepository Supabase notice: $e');
    }
  }

  /// Ensure initial relations exist.
  /// Seeds initial mutual connection for Jeremiah Green only for clean testing.
  /// Zero default pending requests so Alexander Cole and other talents can be tested cleanly.
  Future<void> ensureDefaultMockConnections(String actorId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_connectionsPrefKey)) return;

    final initialList = <Map<String, dynamic>>[
      // Mutual accepted connection with Jeremiah Green
      {
        'id': 'conn-mock-jeremiah',
        'user_id': UserPersonaNotifier.jeremiahId,
        'connected_user_id': actorId,
        'status': 'accepted',
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
    ];

    await prefs.setString(_connectionsPrefKey, jsonEncode(initialList));
  }

  Future<List<Map<String, dynamic>>> _loadLocalStore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_connectionsPrefKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List;
      // Filter out any invalid non-UUID entries (such as old sample-talent-3 strings)
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((item) {
            final u1 = item['user_id']?.toString() ?? '';
            final u2 = item['connected_user_id']?.toString() ?? '';
            return isValidUuid(u1) && isValidUuid(u2);
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalStore(List<Map<String, dynamic>> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_connectionsPrefKey, jsonEncode(items));
    } catch (_) {}
  }

  /// Send a connection request from [userId] to [targetUserId].
  Future<bool> sendConnectionRequest({
    required String userId,
    required String targetUserId,
  }) async {
    final effectiveUserId = _isActorId(userId)
        ? (_client.auth.currentUser?.id ?? userId)
        : userId;

    // 1. Update local persistent cache
    final local = await _loadLocalStore();
    final isCurrentActor = _isActorId(effectiveUserId);

    local.removeWhere((item) {
      final u1 = item['user_id'] as String? ?? '';
      final u2 = item['connected_user_id'] as String? ?? '';
      final isDirect = (isCurrentActor ? _isActorId(u1) : u1 == effectiveUserId) &&
          u2 == targetUserId;
      final isReverse = (isCurrentActor ? _isActorId(u2) : u2 == effectiveUserId) &&
          u1 == targetUserId;
      return isDirect || isReverse;
    });

    local.add({
      'id': 'conn-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': effectiveUserId,
      'connected_user_id': targetUserId,
      'status': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _saveLocalStore(local);

    // 2. Sync to Supabase if table is available and both IDs are valid UUIDs
    if (_isSupabaseTableAvailable != false &&
        isValidUuid(effectiveUserId) &&
        isValidUuid(targetUserId)) {
      try {
        await _db.upsert(
          {
            'user_id': effectiveUserId,
            'connected_user_id': targetUserId,
            'status': 'pending',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'user_id,connected_user_id',
        );
        _isSupabaseTableAvailable = true;
      } catch (e) {
        _recordSupabaseError(e);
      }
    }
    return true;
  }

  /// Accept a connection request received by [userId] from [senderUserId].
  Future<bool> acceptConnection({
    required String userId,
    required String senderUserId,
  }) async {
    final effectiveUserId = _isActorId(userId)
        ? (_client.auth.currentUser?.id ?? userId)
        : userId;
    final isCurrentActor = _isActorId(effectiveUserId);

    // 1. Update local cache
    final local = await _loadLocalStore();
    bool found = false;
    for (var item in local) {
      final u1 = item['user_id'] as String? ?? '';
      final u2 = item['connected_user_id'] as String? ?? '';
      final isDirect = (isCurrentActor ? _isActorId(u2) : u2 == effectiveUserId) &&
          u1 == senderUserId;
      final isReverse = (isCurrentActor ? _isActorId(u1) : u1 == effectiveUserId) &&
          u2 == senderUserId;

      if (isDirect || isReverse) {
        item['status'] = 'accepted';
        item['created_at'] = DateTime.now().toUtc().toIso8601String();
        found = true;
      }
    }
    if (!found) {
      local.add({
        'id': 'conn-${DateTime.now().millisecondsSinceEpoch}',
        'user_id': senderUserId,
        'connected_user_id': effectiveUserId,
        'status': 'accepted',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    await _saveLocalStore(local);

    // 2. Sync to Supabase if table is available and both IDs are valid UUIDs
    if (_isSupabaseTableAvailable != false &&
        isValidUuid(effectiveUserId) &&
        isValidUuid(senderUserId)) {
      try {
        await _db
            .update({'status': 'accepted'})
            .eq('user_id', senderUserId)
            .eq('connected_user_id', effectiveUserId);
        _isSupabaseTableAvailable = true;
      } catch (e) {
        _recordSupabaseError(e);
      }
    }
    return true;
  }

  /// Decline / reject a pending connection request received by [userId] from [senderUserId].
  Future<bool> declineConnection({
    required String userId,
    required String senderUserId,
  }) async {
    final effectiveUserId = _isActorId(userId)
        ? (_client.auth.currentUser?.id ?? userId)
        : userId;
    final isCurrentActor = _isActorId(effectiveUserId);

    // 1. Update local cache
    final local = await _loadLocalStore();
    local.removeWhere((item) {
      final u1 = item['user_id'] as String? ?? '';
      final u2 = item['connected_user_id'] as String? ?? '';
      return (isCurrentActor ? _isActorId(u2) : u2 == effectiveUserId) &&
          u1 == senderUserId;
    });
    await _saveLocalStore(local);

    // 2. Sync to Supabase if table is available and both IDs are valid UUIDs
    if (_isSupabaseTableAvailable != false &&
        isValidUuid(effectiveUserId) &&
        isValidUuid(senderUserId)) {
      try {
        await _db
            .delete()
            .eq('user_id', senderUserId)
            .eq('connected_user_id', effectiveUserId);
        _isSupabaseTableAvailable = true;
      } catch (e) {
        _recordSupabaseError(e);
      }
    }
    return true;
  }

  /// Remove or cancel a connection between [userId] and [connectedUserId].
  Future<bool> removeConnection({
    required String userId,
    required String connectedUserId,
  }) async {
    final effectiveUserId = _isActorId(userId)
        ? (_client.auth.currentUser?.id ?? userId)
        : userId;
    final isCurrentActor = _isActorId(effectiveUserId);

    // 1. Update local cache
    final local = await _loadLocalStore();
    local.removeWhere((item) {
      final u1 = item['user_id'] as String? ?? '';
      final u2 = item['connected_user_id'] as String? ?? '';
      final isDirect = (isCurrentActor ? _isActorId(u1) : u1 == effectiveUserId) &&
          u2 == connectedUserId;
      final isReverse = (isCurrentActor ? _isActorId(u2) : u2 == effectiveUserId) &&
          u1 == connectedUserId;
      return isDirect || isReverse;
    });
    await _saveLocalStore(local);

    // 2. Sync to Supabase if table is available and both IDs are valid UUIDs
    if (_isSupabaseTableAvailable != false &&
        isValidUuid(effectiveUserId) &&
        isValidUuid(connectedUserId)) {
      try {
        await _db
            .delete()
            .eq('user_id', effectiveUserId)
            .eq('connected_user_id', connectedUserId);
        await _db
            .delete()
            .eq('user_id', connectedUserId)
            .eq('connected_user_id', effectiveUserId);
        _isSupabaseTableAvailable = true;
      } catch (e) {
        _recordSupabaseError(e);
      }
    }
    return true;
  }

  /// Fetch incoming pending requests for [userId].
  Future<List<Map<String, dynamic>>> fetchIncomingRequests(String userId) async {
    final effectiveUserId = _isActorId(userId)
        ? (_client.auth.currentUser?.id ?? userId)
        : userId;

    if (_isSupabaseTableAvailable != false && isValidUuid(effectiveUserId)) {
      try {
        final data = await _db
            .select()
            .eq('connected_user_id', effectiveUserId)
            .eq('status', 'pending');
        _isSupabaseTableAvailable = true;
        final list = List<Map<String, dynamic>>.from(data as List);
        if (list.isNotEmpty) return list;
      } catch (e) {
        _recordSupabaseError(e);
      }
    }

    // Fallback to local store with actor normalization
    final isCurrentActor = _isActorId(effectiveUserId);
    final local = await _loadLocalStore();
    return local.where((item) {
      final u2 = item['connected_user_id'] as String? ?? '';
      final isMatch = isCurrentActor ? _isActorId(u2) : u2 == effectiveUserId;
      return isMatch && item['status'] == 'pending';
    }).toList();
  }

  /// Fetch outgoing pending requests sent by [userId].
  Future<List<Map<String, dynamic>>> fetchOutgoingRequests(String userId) async {
    final effectiveUserId = _isActorId(userId)
        ? (_client.auth.currentUser?.id ?? userId)
        : userId;

    if (_isSupabaseTableAvailable != false && isValidUuid(effectiveUserId)) {
      try {
        final data = await _db
            .select()
            .eq('user_id', effectiveUserId)
            .eq('status', 'pending');
        _isSupabaseTableAvailable = true;
        final list = List<Map<String, dynamic>>.from(data as List);
        if (list.isNotEmpty) return list;
      } catch (e) {
        _recordSupabaseError(e);
      }
    }

    final isCurrentActor = _isActorId(effectiveUserId);
    final local = await _loadLocalStore();
    return local.where((item) {
      final u1 = item['user_id'] as String? ?? '';
      final isMatch = isCurrentActor ? _isActorId(u1) : u1 == effectiveUserId;
      return isMatch && item['status'] == 'pending';
    }).toList();
  }

  /// Fetch accepted connections for [userId].
  Future<List<Map<String, dynamic>>> fetchAcceptedConnections(String userId) async {
    final effectiveUserId = _isActorId(userId)
        ? (_client.auth.currentUser?.id ?? userId)
        : userId;

    if (_isSupabaseTableAvailable != false && isValidUuid(effectiveUserId)) {
      try {
        final sent = await _db
            .select()
            .eq('user_id', effectiveUserId)
            .eq('status', 'accepted');
        final received = await _db
            .select()
            .eq('connected_user_id', effectiveUserId)
            .eq('status', 'accepted');

        _isSupabaseTableAvailable = true;
        final all = <Map<String, dynamic>>[
          ...List<Map<String, dynamic>>.from(sent as List),
          ...List<Map<String, dynamic>>.from(received as List),
        ];
        if (all.isNotEmpty) return all;
      } catch (e) {
        _recordSupabaseError(e);
      }
    }

    final isCurrentActor = _isActorId(effectiveUserId);
    final local = await _loadLocalStore();
    return local.where((item) {
      final u1 = item['user_id'] as String? ?? '';
      final u2 = item['connected_user_id'] as String? ?? '';
      final isMatch = isCurrentActor
          ? (_isActorId(u1) || _isActorId(u2))
          : (u1 == effectiveUserId || u2 == effectiveUserId);
      return isMatch && item['status'] == 'accepted';
    }).toList();
  }

  /// Get relationship status between [currentUserId] and [targetUserId].
  /// Returns 'none', 'pending_outgoing', 'pending_incoming', or 'accepted'.
  Future<String> getRelationshipStatus({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final effectiveUserId = _isActorId(currentUserId)
        ? (_client.auth.currentUser?.id ?? currentUserId)
        : currentUserId;
    final isCurrentActor = _isActorId(effectiveUserId);

    final local = await _loadLocalStore();
    for (var item in local) {
      final u1 = item['user_id'] as String? ?? '';
      final u2 = item['connected_user_id'] as String? ?? '';

      final isUserMatch = isCurrentActor ? _isActorId(u1) : u1 == effectiveUserId;
      final isTargetMatch = u2 == targetUserId;

      final isReverseUserMatch = isCurrentActor ? _isActorId(u2) : u2 == effectiveUserId;
      final isReverseTargetMatch = u1 == targetUserId;

      final isDirect = isUserMatch && isTargetMatch;
      final isReverse = isReverseUserMatch && isReverseTargetMatch;

      if (isDirect || isReverse) {
        final status = item['status'] as String? ?? 'none';
        if (status == 'accepted') return 'accepted';
        if (status == 'pending') {
          return isDirect ? 'pending_outgoing' : 'pending_incoming';
        }
      }
    }
    return 'none';
  }

  /// Check whether [userA] and [userB] are mutually connected (status == 'accepted').
  Future<bool> isMutuallyConnected({
    required String userA,
    required String userB,
  }) async {
    final status = await getRelationshipStatus(currentUserId: userA, targetUserId: userB);
    return status == 'accepted';
  }

  /// Following set for production houses
  Future<Set<String>> getFollowingIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_followingPrefKeyPrefix$userId';
    final list = prefs.getStringList(key) ?? [];
    return list.toSet();
  }

  Future<void> toggleFollowing(String userId, String targetId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_followingPrefKeyPrefix$userId';
    final set = (prefs.getStringList(key) ?? []).toSet();
    if (set.contains(targetId)) {
      set.remove(targetId);
    } else {
      set.add(targetId);
    }
    await prefs.setStringList(key, set.toList());
  }

  /// Real-time stream of connections for a given [uid].
  Stream<List<Map<String, dynamic>>> watchConnections(String uid) {
    if (_isSupabaseTableAvailable == false || !isValidUuid(uid)) {
      return Stream.value([]);
    }
    return _db.stream(primaryKey: ['id']).eq('user_id', uid);
  }
}
