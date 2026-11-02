import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/core/constants/talent_directory.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/repositories/notification_repository.dart';
import 'package:you_too_art/features/notifications/models/notification_item.dart';

/// Centralized repository for managing user connections and follows.
/// Synchronizes seamlessly with Supabase Postgres while maintaining a persistent
/// local cache so testing multi-user flows works reliably offline or online.
class ConnectionRepository {
  final SupabaseClient _client;

  ConnectionRepository(this._client);

  SupabaseQueryBuilder get _db => _client.from(SupabaseTables.connections);

  static const String _connectionsPrefKey = 'yt_connections_clean_v1';
  static const String _followingPrefKeyPrefix = 'yt_following_set_';

  static bool? _isSupabaseTableAvailable;

  /// Global broadcast stream of connection changes so all screens (Talent, Network, Notifications, Chat)
  /// immediately update reactively whenever a connection is created, accepted, rejected, or removed.
  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();
  static Stream<void> get connectionChanges => _changesController.stream;

  static void notifyChanges() {
    if (!_changesController.isClosed) {
      _changesController.add(null);
    }
  }

  static void resetSupabaseTableCheck() {
    _isSupabaseTableAvailable = null;
  }

  static bool isValidUuid(String id) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  List<String> _actorIds() {
    final ids = <String>{UserPersonaNotifier.actorDefaultId};
    final currentUid = _client.auth.currentUser?.id;
    if (currentUid != null && currentUid.isNotEmpty) ids.add(currentUid);
    try {
      final actorPersona = UserPersonaNotifier.buildActorPersona();
      ids.add(actorPersona.id);
    } catch (_) {}
    return ids.toList();
  }

  bool _isActorId(String id) {
    return _actorIds().contains(id);
  }

  bool _isUserMatch(String a, String b) {
    if (a == b) return true;
    if (_isActorId(a) && _isActorId(b)) return true;
    return false;
  }

  String _toEffectiveId(String id) {
    if (_isActorId(id)) {
      return _client.auth.currentUser?.id ?? id;
    }
    return id;
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
      if (kDebugMode) {
        debugPrint('ConnectionRepository local cache active for talent.');
      }
    } else if (kDebugMode) {
      debugPrint('ConnectionRepository Supabase notice: $e');
    }
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

  Future<void> _mergeRowIntoLocalStore(Map<String, dynamic> row) async {
    try {
      final u1 = row['user_id']?.toString() ?? '';
      final u2 = row['connected_user_id']?.toString() ?? '';
      if (!isValidUuid(u1) || !isValidUuid(u2)) return;

      final local = await _loadLocalStore();
      final idx = local.indexWhere((item) {
        final itemU1 = item['user_id']?.toString() ?? '';
        final itemU2 = item['connected_user_id']?.toString() ?? '';
        final direct = _isUserMatch(itemU1, u1) && _isUserMatch(itemU2, u2);
        final reverse = _isUserMatch(itemU1, u2) && _isUserMatch(itemU2, u1);
        return direct || reverse;
      });

      if (idx != -1) {
        local[idx] = {...local[idx], ...row};
      } else {
        local.add(Map<String, dynamic>.from(row));
      }
      await _saveLocalStore(local);
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

    // 3. Trigger realtime in-app notification for the target user
    final actorTalent = TalentDirectory.findById(effectiveUserId);
    final actorPersona = UserPersonaNotifier.allPersonas
        .where((p) => p.id == effectiveUserId)
        .firstOrNull;

    final name = actorTalent?.name ??
        actorPersona?.name ??
        (_isActorId(effectiveUserId) ? 'Wajahat Ali (Actor)' : 'A fellow artist');
    final avatarUrl = actorTalent?.avatarUrl ?? actorPersona?.avatarUrl;
    final isFilmfare = effectiveUserId == UserPersonaNotifier.filmfareId ||
        actorPersona?.isProductionHouse == true;

    NotificationRepository.instance?.sendNotification(
      recipientId: targetUserId,
      actorId: effectiveUserId,
      type: NotificationType.connectionRequest,
      primarySubject: name,
      actionText: 'sent you a connection request',
      avatarUrl: avatarUrl,
      isFilmfare: isFilmfare,
      requestStatus: ConnectionRequestNotificationStatus.pending,
    );

    notifyChanges();
    return true;
  }

  /// Accept a connection request received by [userId] from [senderUserId].
  Future<bool> acceptConnection({
    required String userId,
    required String senderUserId,
  }) async {
    final effectiveUserId = _toEffectiveId(userId);
    final effectiveSenderId = _toEffectiveId(senderUserId);

    // 1. Update local cache
    final local = await _loadLocalStore();
    bool found = false;
    for (var item in local) {
      final u1 = item['user_id'] as String? ?? '';
      final u2 = item['connected_user_id'] as String? ?? '';
      final isDirect = _isUserMatch(u1, effectiveSenderId) && _isUserMatch(u2, effectiveUserId);
      final isReverse = _isUserMatch(u1, effectiveUserId) && _isUserMatch(u2, effectiveSenderId);

      if (isDirect || isReverse) {
        item['status'] = 'accepted';
        item['created_at'] = DateTime.now().toUtc().toIso8601String();
        found = true;
      }
    }
    if (!found) {
      local.add({
        'id': 'conn-${DateTime.now().millisecondsSinceEpoch}',
        'user_id': effectiveSenderId,
        'connected_user_id': effectiveUserId,
        'status': 'accepted',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    await _saveLocalStore(local);

    // 2. Sync to Supabase if table is available and both IDs are valid UUIDs
    if (_isSupabaseTableAvailable != false &&
        isValidUuid(effectiveUserId) &&
        isValidUuid(effectiveSenderId)) {
      try {
        await _db
            .update({'status': 'accepted'})
            .or(
              'and(user_id.eq.$effectiveSenderId,connected_user_id.eq.$effectiveUserId),'
              'and(user_id.eq.$effectiveUserId,connected_user_id.eq.$effectiveSenderId)',
            );
        _isSupabaseTableAvailable = true;
      } catch (e) {
        _recordSupabaseError(e);
      }
    }

    // 3. Synchronize notifications so the incoming connection request card
    // is instantly updated to "Connected" and marked read across all screens!
    await NotificationRepository.instance?.syncConnectionStatus(
      recipientId: effectiveUserId,
      senderUserId: senderUserId,
      status: ConnectionRequestNotificationStatus.accepted,
    );

    // 4. Send "connection_accepted" realtime notification back to the sender
    final actorTalent = TalentDirectory.findById(effectiveUserId);
    final actorPersona = UserPersonaNotifier.allPersonas
        .where((p) => p.id == effectiveUserId)
        .firstOrNull;

    final name = actorTalent?.name ??
        actorPersona?.name ??
        (_isActorId(effectiveUserId) ? 'Wajahat Ali (Actor)' : 'A fellow artist');
    final avatarUrl = actorTalent?.avatarUrl ?? actorPersona?.avatarUrl;
    final isFilmfare = effectiveUserId == UserPersonaNotifier.filmfareId ||
        actorPersona?.isProductionHouse == true;

    NotificationRepository.instance?.sendNotification(
      recipientId: senderUserId,
      actorId: effectiveUserId,
      type: NotificationType.connectionAccepted,
      primarySubject: name,
      actionText: 'accepted your connection request',
      avatarUrl: avatarUrl,
      isFilmfare: isFilmfare,
      requestStatus: ConnectionRequestNotificationStatus.accepted,
    );

    notifyChanges();
    return true;
  }

  /// Decline / reject a pending connection request received by [userId] from [senderUserId].
  Future<bool> declineConnection({
    required String userId,
    required String senderUserId,
  }) async {
    final effectiveUserId = _toEffectiveId(userId);
    final effectiveSenderId = _toEffectiveId(senderUserId);

    // 1. Update local cache
    final local = await _loadLocalStore();
    local.removeWhere((item) {
      final u1 = item['user_id'] as String? ?? '';
      final u2 = item['connected_user_id'] as String? ?? '';
      final isDirect = _isUserMatch(u1, effectiveSenderId) && _isUserMatch(u2, effectiveUserId);
      final isReverse = _isUserMatch(u1, effectiveUserId) && _isUserMatch(u2, effectiveSenderId);
      return isDirect || isReverse;
    });
    await _saveLocalStore(local);

    // 2. Sync to Supabase if table is available and both IDs are valid UUIDs
    if (_isSupabaseTableAvailable != false &&
        isValidUuid(effectiveUserId) &&
        isValidUuid(effectiveSenderId)) {
      try {
        await _db
            .delete()
            .or(
              'and(user_id.eq.$effectiveSenderId,connected_user_id.eq.$effectiveUserId),'
              'and(user_id.eq.$effectiveUserId,connected_user_id.eq.$effectiveSenderId)',
            );
        _isSupabaseTableAvailable = true;
      } catch (e) {
        _recordSupabaseError(e);
      }
    }

    // 3. Synchronize notifications so incoming request card shows "Request rejected"
    await NotificationRepository.instance?.syncConnectionStatus(
      recipientId: effectiveUserId,
      senderUserId: senderUserId,
      status: ConnectionRequestNotificationStatus.rejected,
    );

    notifyChanges();
    return true;
  }

  /// Remove or cancel a connection between [userId] and [connectedUserId].
  Future<bool> removeConnection({
    required String userId,
    required String connectedUserId,
  }) async {
    final effectiveUserId = _toEffectiveId(userId);
    final effectiveConnectedId = _toEffectiveId(connectedUserId);

    // 1. Update local cache
    final local = await _loadLocalStore();
    local.removeWhere((item) {
      final u1 = item['user_id'] as String? ?? '';
      final u2 = item['connected_user_id'] as String? ?? '';
      final isDirect = _isUserMatch(u1, effectiveUserId) && _isUserMatch(u2, effectiveConnectedId);
      final isReverse = _isUserMatch(u1, effectiveConnectedId) && _isUserMatch(u2, effectiveUserId);
      return isDirect || isReverse;
    });
    await _saveLocalStore(local);

    // 2. Sync to Supabase if table is available and both IDs are valid UUIDs
    if (_isSupabaseTableAvailable != false &&
        isValidUuid(effectiveUserId) &&
        isValidUuid(effectiveConnectedId)) {
      try {
        await _db
            .delete()
            .or(
              'and(user_id.eq.$effectiveUserId,connected_user_id.eq.$effectiveConnectedId),'
              'and(user_id.eq.$effectiveConnectedId,connected_user_id.eq.$effectiveUserId)',
            );
        _isSupabaseTableAvailable = true;
      } catch (e) {
        _recordSupabaseError(e);
      }
    }

    // 3. Reset notification status so UI reflects removed connection
    await NotificationRepository.instance?.syncConnectionStatus(
      recipientId: effectiveUserId,
      senderUserId: connectedUserId,
      status: ConnectionRequestNotificationStatus.none,
    );

    notifyChanges();
    return true;
  }

  /// Fetch incoming pending requests for [userId].
  Future<List<Map<String, dynamic>>> fetchIncomingRequests(String userId) async {
    final effectiveUserId = _toEffectiveId(userId);

    if (_isSupabaseTableAvailable != false && isValidUuid(effectiveUserId)) {
      try {
        final isActor = _isActorId(effectiveUserId);
        final queryIds = isActor
            ? _actorIds().where(isValidUuid).join(',')
            : effectiveUserId;

        final data = await _db
            .select()
            .eq('status', 'pending')
            .or('connected_user_id.in.($queryIds)');
        _isSupabaseTableAvailable = true;
        final list = List<Map<String, dynamic>>.from(data as List);
        if (list.isNotEmpty) {
          for (final row in list) {
            await _mergeRowIntoLocalStore(row);
          }
          return list;
        }
      } catch (e) {
        _recordSupabaseError(e);
      }
    }

    // Fallback to local store with actor normalization
    final local = await _loadLocalStore();
    return local.where((item) {
      final u2 = item['connected_user_id'] as String? ?? '';
      return _isUserMatch(u2, effectiveUserId) && item['status'] == 'pending';
    }).toList();
  }

  /// Fetch outgoing pending requests sent by [userId].
  Future<List<Map<String, dynamic>>> fetchOutgoingRequests(String userId) async {
    final effectiveUserId = _toEffectiveId(userId);

    if (_isSupabaseTableAvailable != false && isValidUuid(effectiveUserId)) {
      try {
        final isActor = _isActorId(effectiveUserId);
        final queryIds = isActor
            ? _actorIds().where(isValidUuid).join(',')
            : effectiveUserId;

        final data = await _db
            .select()
            .eq('status', 'pending')
            .or('user_id.in.($queryIds)');
        _isSupabaseTableAvailable = true;
        final list = List<Map<String, dynamic>>.from(data as List);
        if (list.isNotEmpty) {
          for (final row in list) {
            await _mergeRowIntoLocalStore(row);
          }
          return list;
        }
      } catch (e) {
        _recordSupabaseError(e);
      }
    }

    final local = await _loadLocalStore();
    return local.where((item) {
      final u1 = item['user_id'] as String? ?? '';
      return _isUserMatch(u1, effectiveUserId) && item['status'] == 'pending';
    }).toList();
  }

  /// Fetch accepted connections for [userId].
  Future<List<Map<String, dynamic>>> fetchAcceptedConnections(String userId) async {
    final effectiveUserId = _toEffectiveId(userId);

    if (_isSupabaseTableAvailable != false && isValidUuid(effectiveUserId)) {
      try {
        final isActor = _isActorId(effectiveUserId);
        final queryIds = isActor
            ? _actorIds().where(isValidUuid).join(',')
            : effectiveUserId;

        final data = await _db
            .select()
            .eq('status', 'accepted')
            .or('user_id.in.($queryIds),connected_user_id.in.($queryIds)');

        _isSupabaseTableAvailable = true;
        final all = List<Map<String, dynamic>>.from(data as List);
        if (all.isNotEmpty) {
          for (final row in all) {
            await _mergeRowIntoLocalStore(row);
          }
          return all;
        }
      } catch (e) {
        _recordSupabaseError(e);
      }
    }

    final local = await _loadLocalStore();
    return local.where((item) {
      final u1 = item['user_id'] as String? ?? '';
      final u2 = item['connected_user_id'] as String? ?? '';
      final isMatch = _isUserMatch(u1, effectiveUserId) || _isUserMatch(u2, effectiveUserId);
      return isMatch && item['status'] == 'accepted';
    }).toList();
  }

  /// Fetch all relationship statuses for [currentUserId] across all users in one batch.
  /// Returns a map from peerId -> status ('none', 'pending_outgoing', 'pending_incoming', 'accepted').
  Future<Map<String, String>> getAllRelationshipStatuses(String currentUserId) async {
    final effectiveUserId = _toEffectiveId(currentUserId);
    final Map<String, String> statusMap = {};

    // 1. Fetch from Supabase Postgres
    if (_isSupabaseTableAvailable != false && isValidUuid(effectiveUserId)) {
      try {
        final isActor = _isActorId(effectiveUserId);
        final queryIds = isActor
            ? _actorIds().where(isValidUuid).join(',')
            : effectiveUserId;

        final rows = await _db
            .select()
            .or('user_id.in.($queryIds),connected_user_id.in.($queryIds)');

        if (rows.isNotEmpty) {
          _isSupabaseTableAvailable = true;
          for (final row in rows) {
            await _mergeRowIntoLocalStore(row);

            final u1 = row['user_id']?.toString() ?? '';
            final u2 = row['connected_user_id']?.toString() ?? '';
            final isSender = _isUserMatch(u1, effectiveUserId);
            final peerId = isSender ? u2 : u1;
            final status = row['status']?.toString() ?? 'none';

            if (status == 'accepted') {
              statusMap[peerId] = 'accepted';
            } else if (status == 'pending') {
              statusMap[peerId] =
                  isSender ? 'pending_outgoing' : 'pending_incoming';
            }
          }
        }
      } catch (e) {
        _recordSupabaseError(e);
      }
    }

    // 2. Overlay with local store
    final local = await _loadLocalStore();
    for (final item in local) {
      final u1 = item['user_id'] as String? ?? '';
      final u2 = item['connected_user_id'] as String? ?? '';
      final isSender = _isUserMatch(u1, effectiveUserId);
      final isReceiver = _isUserMatch(u2, effectiveUserId);
      if (!isSender && !isReceiver) continue;

      final peerId = isSender ? u2 : u1;
      // Do not downgrade an accepted status from Supabase
      if (statusMap[peerId] == 'accepted') continue;

      final status = item['status'] as String? ?? 'none';
      if (status == 'accepted') {
        statusMap[peerId] = 'accepted';
      } else if (status == 'pending') {
        statusMap[peerId] =
            isSender ? 'pending_outgoing' : 'pending_incoming';
      }
    }

    return statusMap;
  }

  /// Get relationship status between [currentUserId] and [targetUserId].
  /// Returns 'none', 'pending_outgoing', 'pending_incoming', or 'accepted'.
  Future<String> getRelationshipStatus({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final effectiveUserId = _toEffectiveId(currentUserId);
    final effectiveTargetId = _toEffectiveId(targetUserId);

    // 1. Check Supabase first if available
    if (_isSupabaseTableAvailable != false &&
        isValidUuid(effectiveUserId) &&
        isValidUuid(effectiveTargetId)) {
      try {
        final isUserActor = _isActorId(effectiveUserId);
        final isTargetActor = _isActorId(effectiveTargetId);
        final userIds = isUserActor
            ? _actorIds().where(isValidUuid).join(',')
            : effectiveUserId;
        final targetIds = isTargetActor
            ? _actorIds().where(isValidUuid).join(',')
            : effectiveTargetId;

        final data = await _db
            .select()
            .or(
              'and(user_id.in.($userIds),connected_user_id.in.($targetIds)),'
              'and(user_id.in.($targetIds),connected_user_id.in.($userIds))',
            )
            .maybeSingle();

        if (data != null) {
          _isSupabaseTableAvailable = true;
          await _mergeRowIntoLocalStore(data);

          final status = data['status']?.toString() ?? 'none';
          if (status == 'accepted') return 'accepted';
          if (status == 'pending') {
            final sender = data['user_id']?.toString() ?? '';
            final isOutgoing = _isUserMatch(sender, effectiveUserId);
            return isOutgoing ? 'pending_outgoing' : 'pending_incoming';
          }
        }
      } catch (e) {
        _recordSupabaseError(e);
      }
    }

    // 2. Fallback to resilient local cache
    final local = await _loadLocalStore();
    for (var item in local) {
      final u1 = item['user_id'] as String? ?? '';
      final u2 = item['connected_user_id'] as String? ?? '';

      final isDirect =
          _isUserMatch(u1, effectiveUserId) && _isUserMatch(u2, effectiveTargetId);
      final isReverse =
          _isUserMatch(u2, effectiveUserId) && _isUserMatch(u1, effectiveTargetId);

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

  static const String _followersCountPrefKey = 'yt_prod_followers_count_';

  /// Get total followers count for a production house
  Future<int> getFollowersCount(String targetId) async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('$_followersCountPrefKey$targetId');
    if (count != null) return count;
    return 0;
  }

  Future<void> toggleFollowing(String userId, String targetId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_followingPrefKeyPrefix$userId';
    final countKey = '$_followersCountPrefKey$targetId';
    final set = (prefs.getStringList(key) ?? []).toSet();
    int followers = prefs.getInt(countKey) ?? 0;

    if (set.contains(targetId)) {
      set.remove(targetId);
      followers = (followers - 1).clamp(0, 999999);
    } else {
      set.add(targetId);
      followers = followers + 1;
    }
    await prefs.setStringList(key, set.toList());
    await prefs.setInt(countKey, followers);
    notifyChanges();
  }

  /// Real-time stream of connections for a given [uid].
  Stream<List<Map<String, dynamic>>> watchConnections(String uid) {
    if (_isSupabaseTableAvailable == false || !isValidUuid(uid)) {
      return Stream.value([]);
    }
    return _db.stream(primaryKey: ['id']).eq('user_id', uid);
  }
}
