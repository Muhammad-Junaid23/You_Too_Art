import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/features/notifications/models/notification_item.dart';

/// Centralized repository for managing in-app notifications.
/// Backed by Supabase Realtime with automatic local fallback cache
/// ensuring full-fidelity notification delivery in the free tier.
class NotificationRepository {
  final SupabaseClient _client;

  static NotificationRepository? instance;

  NotificationRepository(this._client) {
    instance = this;
    _initLocalStore();
  }

  static const String _notificationsPrefKey = 'yt_notifications_clean_v1';
  static bool? _isSupabaseTableAvailable;

  SupabaseQueryBuilder get _db => _client.from(SupabaseTables.notifications);

  // In-memory cache for ultra-fast UI rendering & local fallbacks
  final Map<String, List<NotificationItem>> _userNotifications = {};
  final StreamController<void> _updateController =
      StreamController<void>.broadcast();

  String _normalizeUserId(String uid) {
    return uid.trim();
  }

  static bool isValidUuid(String id) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  static List<NotificationItem> _deduplicateNotifications(List<NotificationItem> items) {
    final result = <NotificationItem>[];
    final seenIds = <String>{};
    final seenSemanticKeys = <String>{};

    for (final it in items) {
      if (seenIds.contains(it.id)) continue;

      final semKey = _semanticKey(it);
      if (semKey != null) {
        if (seenSemanticKeys.contains(semKey)) {
          // Skip duplicate item representing the same user action
          continue;
        }
        seenSemanticKeys.add(semKey);
      }

      seenIds.add(it.id);
      result.add(it);
    }

    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  static String? _semanticKey(NotificationItem item) {
    final sender = item.senderId ?? item.actorId;
    if (sender == null || sender.isEmpty) return null;

    if (item.type == NotificationType.connectionRequest ||
        item.type == NotificationType.connectionAccepted) {
      return '${item.type.name}_$sender';
    }

    if (item.entityId != null && item.entityId!.isNotEmpty) {
      return '${item.type.name}_${sender}_${item.entityId}';
    }

    // Generic notification: deduplicate by sender within 2-minute bucket
    final bucket = item.timestamp.millisecondsSinceEpoch ~/ (1000 * 120);
    return '${item.type.name}_${sender}_$bucket';
  }

  Future<void> _initLocalStore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_notificationsPrefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final list = (entry.value as List)
              .map((it) => NotificationItem.fromJson(Map<String, dynamic>.from(it as Map)))
              .toList();

          _userNotifications[entry.key] = _deduplicateNotifications(list);
        }
      }
      _updateController.add(null);
    } catch (_) {
      _updateController.add(null);
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _userNotifications.map(
        (key, list) => MapEntry(key, list.map((it) => it.toJson()).toList()),
      );
      await prefs.setString(_notificationsPrefKey, jsonEncode(map));
    } catch (_) {}
  }

  void _replaceLocalId(String recipientId, String oldId, String newId) {
    final list = _userNotifications[recipientId];
    if (list == null) return;
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == oldId) {
        list[i] = list[i].copyWith(id: newId);
        break;
      }
    }
    _saveToPrefs();
  }

  /// Watches notifications for [userId] in realtime.
  Stream<List<NotificationItem>> watchNotifications(String userId) {
    late StreamController<List<NotificationItem>> controller;
    StreamSubscription<dynamic>? supabaseSub;
    StreamSubscription<void>? localSub;
    final normUserId = _normalizeUserId(userId);

    void emitMerged(List<NotificationItem> incoming) {
      if (controller.isClosed) return;
      final currentList = _userNotifications[normUserId] ?? [];

      // Merge remote incoming rows and local optimistic list.
      // Remote incoming rows appear first so their authoritative IDs win.
      final combined = <NotificationItem>[...incoming, ...currentList];
      final deduped = _deduplicateNotifications(combined);

      // Strictly isolate notifications:
      // 1. Only show notifications addressed to this user (recipientId == normUserId)
      // 2. Never show notifications where this user was the sender/actor
      final filtered = deduped.where((item) {
        final rId = _normalizeUserId(item.recipientId ?? '');
        final aId = _normalizeUserId(item.actorId ?? item.senderId ?? '');
        if (rId.isNotEmpty && rId != normUserId) return false;
        if (aId.isNotEmpty && aId == normUserId) return false;
        return true;
      }).toList();

      _userNotifications[normUserId] = filtered;
      controller.add(filtered);
    }

    controller = StreamController<List<NotificationItem>>.broadcast(
      onListen: () {
        // Emit in-memory local state first for immediate UI display
        final local = _userNotifications[normUserId] ?? [];
        emitMerged(local);

        // Listen to local store mutations
        localSub = _updateController.stream.listen((_) {
          final currentLocal = _userNotifications[normUserId] ?? [];
          final filtered = currentLocal.where((item) {
            final rId = _normalizeUserId(item.recipientId ?? '');
            final aId = _normalizeUserId(item.actorId ?? item.senderId ?? '');
            if (rId.isNotEmpty && rId != normUserId) return false;
            if (aId.isNotEmpty && aId == normUserId) return false;
            return true;
          }).toList();
          if (!controller.isClosed) {
            controller.add(filtered);
          }
        });

        // Listen to Supabase Realtime if table is available and userId is UUID
        if (_isSupabaseTableAvailable != false && isValidUuid(userId)) {
          try {
            supabaseSub = _db
                .stream(primaryKey: ['id'])
                .eq('recipient_id', userId)
                .order('created_at', ascending: false)
                .listen(
                  (rows) {
                    _isSupabaseTableAvailable = true;
                    final remoteList =
                        rows.map((r) => NotificationItem.fromRow(r)).toList();
                    emitMerged(remoteList);
                    _saveToPrefs();
                  },
                  onError: (e) {
                    final str = e.toString();
                    if (str.contains('PGRST205') ||
                        str.contains('404') ||
                        str.contains('Could not find the table')) {
                      _isSupabaseTableAvailable = false;
                      if (kDebugMode) {
                        debugPrint(
                          'Notice: Supabase table "notifications" not found in cloud. Operating in local mode.',
                        );
                      }
                    }
                  },
                );
          } catch (_) {
            _isSupabaseTableAvailable = false;
          }
        }
      },
      onCancel: () {
        supabaseSub?.cancel();
        localSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Sends a real notification to [recipientId].
  Future<NotificationItem> sendNotification({
    required String recipientId,
    required String actorId,
    required NotificationType type,
    required String primarySubject,
    required String actionText,
    String? targetObject,
    String? entityType,
    String? entityId,
    String? avatarUrl,
    bool isFilmfare = false,
    bool isCastingIcon = false,
    ConnectionRequestNotificationStatus requestStatus =
        ConnectionRequestNotificationStatus.none,
  }) async {
    final normRecipient = _normalizeUserId(recipientId);
    final now = DateTime.now().toUtc();
    final notifId = isValidUuid(recipientId) && isValidUuid(actorId)
        ? _generateUuid()
        : 'notif-${DateTime.now().millisecondsSinceEpoch}';

    final notif = NotificationItem(
      id: notifId,
      type: type,
      primarySubject: primarySubject,
      actionText: actionText,
      targetObject: targetObject,
      timeAgo: 'Just now',
      timestamp: now,
      avatarUrl: avatarUrl,
      isFilmfare: isFilmfare,
      isCastingIcon: isCastingIcon,
      senderId: actorId,
      recipientId: recipientId,
      actorId: actorId,
      entityType: entityType,
      entityId: entityId,
      requestStatus: requestStatus,
      isRead: false,
    );

    // Store in local cache first
    _userNotifications.putIfAbsent(normRecipient, () => []).insert(0, notif);
    _saveToPrefs();
    _updateController.add(null);

    // Sync to Supabase if available
    if (_isSupabaseTableAvailable != false &&
        isValidUuid(recipientId) &&
        isValidUuid(actorId)) {
      try {
        final row = notif.toRow();
        // Remove client-generated 'id' to let PostgreSQL default gen_random_uuid()
        // generate a cryptographically unique primary key, avoiding 409 Conflict.
        row.remove('id');
        final inserted = await _db.insert(row).select().maybeSingle();
        _isSupabaseTableAvailable = true;
        if (inserted != null && inserted['id'] != null) {
          final serverId = inserted['id'].toString();
          _replaceLocalId(normRecipient, notifId, serverId);
        }
      } catch (e) {
        final str = e.toString();
        if (str.contains('409') || str.contains('duplicate') || str.contains('conflict')) {
          if (kDebugMode) {
            debugPrint('Notice: notification insert conflict handled cleanly.');
          }
        } else if (str.contains('PGRST205') || str.contains('404')) {
          _isSupabaseTableAvailable = false;
        }
      }
    }

    return notif;
  }

  /// Synchronizes connection request status across all notifications
  /// whenever a connection is accepted or rejected anywhere in the app
  /// (Talent page, UserProfile page, Network screen, or Notification Center).
  Future<void> syncConnectionStatus({
    required String recipientId,
    required String senderUserId,
    required ConnectionRequestNotificationStatus status,
  }) async {
    final normRecipient = _normalizeUserId(recipientId);
    final normSender = _normalizeUserId(senderUserId);

    // 1. Update in local in-memory cache for all matching notifications
    for (final entry in _userNotifications.entries) {
      final list = entry.value;
      for (var i = 0; i < list.length; i++) {
        final it = list[i];
        final itRecipient = _normalizeUserId(it.recipientId ?? '');
        final itSender = _normalizeUserId(it.senderId ?? it.actorId ?? '');

        final isMatchingRequest = it.type == NotificationType.connectionRequest &&
            ((itRecipient == normRecipient && itSender == normSender) ||
                (itRecipient == normSender && itSender == normRecipient));

        if (isMatchingRequest) {
          list[i] = it.copyWith(
            requestStatus: status,
            isRead: true,
          );
        }
      }
    }

    _saveToPrefs();
    _updateController.add(null);

    // 2. Sync to Supabase notifications table
    if (_isSupabaseTableAvailable != false &&
        isValidUuid(recipientId) &&
        isValidUuid(senderUserId)) {
      try {
        await _db
            .update({
              'request_status': status.name,
              'is_read': true,
            })
            .eq('recipient_id', recipientId)
            .eq('actor_id', senderUserId)
            .eq('type', 'connection_request');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Notice updating notification status in Supabase: $e');
        }
      }
    }
  }

  /// Mark an individual notification as read.
  Future<void> markAsRead(String id, {String? userId}) async {
    for (final entry in _userNotifications.entries) {
      final list = entry.value;
      for (var i = 0; i < list.length; i++) {
        if (list[i].id == id) {
          list[i] = list[i].copyWith(isRead: true);
        }
      }
    }
    _saveToPrefs();
    _updateController.add(null);

    if (_isSupabaseTableAvailable != false && isValidUuid(id)) {
      try {
        await _db.update({'is_read': true}).eq('id', id);
      } catch (_) {}
    }
  }

  /// Mark all notifications as read for [userId].
  Future<void> markAllAsRead(String userId) async {
    final normUserId = _normalizeUserId(userId);
    final list = _userNotifications[normUserId];
    if (list != null) {
      for (var i = 0; i < list.length; i++) {
        list[i] = list[i].copyWith(isRead: true);
      }
      _saveToPrefs();
      _updateController.add(null);
    }

    if (_isSupabaseTableAvailable != false && isValidUuid(userId)) {
      try {
        await _db.update({'is_read': true}).eq('recipient_id', userId);
      } catch (_) {}
    }
  }

  /// Update the connection request status on a notification (e.g. accepted / rejected).
  Future<void> updateRequestStatus(
    String id,
    ConnectionRequestNotificationStatus status,
  ) async {
    for (final entry in _userNotifications.entries) {
      final list = entry.value;
      for (var i = 0; i < list.length; i++) {
        if (list[i].id == id ||
            list[i].senderId == id ||
            list[i].actorId == id) {
          list[i] = list[i].copyWith(
            requestStatus: status,
            isRead: true,
          );
        }
      }
    }
    _saveToPrefs();
    _updateController.add(null);

    if (_isSupabaseTableAvailable != false && isValidUuid(id)) {
      try {
        await _db.update({
          'request_status': status.name,
          'is_read': true,
        }).eq('id', id);
      } catch (_) {}
    }
  }

  /// Delete an individual notification.
  Future<void> deleteNotification(String id) async {
    for (final entry in _userNotifications.entries) {
      entry.value.removeWhere((it) => it.id == id);
    }
    _saveToPrefs();
    _updateController.add(null);

    if (_isSupabaseTableAvailable != false && isValidUuid(id)) {
      try {
        await _db.delete().eq('id', id);
      } catch (_) {}
    }
  }

  /// Clear all notifications for [userId].
  Future<void> clearAll(String userId) async {
    final normUserId = _normalizeUserId(userId);
    _userNotifications[normUserId] = [];
    _saveToPrefs();
    _updateController.add(null);

    if (_isSupabaseTableAvailable != false && isValidUuid(userId)) {
      try {
        await _db.delete().eq('recipient_id', userId);
      } catch (_) {}
    }
  }

  static String _generateUuid() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
      RegExp(r'[xy]'),
      (match) {
        final r = (DateTime.now().microsecondsSinceEpoch +
                (match.start * 13)) %
            16;
        final v = match[0] == 'x' ? r : (r & 0x3 | 0x8);
        return v.toRadixString(16);
      },
    );
  }
}
