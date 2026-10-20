import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:you_too_art/core/constants/talent_directory.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/repositories/connection_repository.dart';
import 'package:you_too_art/features/chats/providers/chat_provider.dart';
import 'package:you_too_art/features/notifications/models/notification_item.dart';

class NotificationState {
  final List<NotificationItem> items;
  final bool isLoading;

  const NotificationState({
    this.items = const [],
    this.isLoading = false,
  });

  int get unreadCount => items.where((i) => !i.isRead).length;

  NotificationState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
  }) {
    return NotificationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  static const String _prefKey = 'yt_notifications_store_v1';
  late ConnectionRepository _connectionRepo;

  @override
  NotificationState build() {
    _connectionRepo = ref.watch(connectionRepositoryProvider);
    _loadFromStorage();
    return const NotificationState(isLoading: true);
  }

  static List<NotificationItem> _buildDefaultNotifications() {
    final now = DateTime.now();
    return [
      NotificationItem(
        id: 'notif-1',
        type: NotificationType.castingCall,
        primarySubject: 'Ranveer Singh',
        actionText: 'just posted a new casting call.',
        timeAgo: 'Just Now',
        timestamp: now.subtract(const Duration(seconds: 45)),
        avatarUrl: TalentDirectory.ranveerSingh.avatarUrl,
        senderId: TalentDirectory.ranveerSinghId,
      ),
      NotificationItem(
        id: 'notif-2',
        type: NotificationType.like,
        primarySubject: 'Ranveer Singh',
        actionText: 'liked your post',
        timeAgo: '5 mins ago',
        timestamp: now.subtract(const Duration(minutes: 5)),
        avatarUrl: TalentDirectory.ranveerSingh.avatarUrl,
        senderId: TalentDirectory.ranveerSinghId,
      ),
      NotificationItem(
        id: 'notif-3',
        type: NotificationType.connectionRequest,
        primarySubject: 'Ranveer Singh',
        actionText: 'sent you a connection request',
        timeAgo: '20 mins ago',
        timestamp: now.subtract(const Duration(minutes: 20)),
        avatarUrl: TalentDirectory.ranveerSingh.avatarUrl,
        senderId: TalentDirectory.ranveerSinghId,
        requestStatus: ConnectionRequestNotificationStatus.pending,
      ),
      NotificationItem(
        id: 'notif-4',
        type: NotificationType.like,
        primarySubject: 'Filmfare',
        actionText: 'liked your post',
        timeAgo: '1 hour ago',
        timestamp: now.subtract(const Duration(hours: 1)),
        isFilmfare: true,
        senderId: UserPersonaNotifier.filmfareId,
      ),
      NotificationItem(
        id: 'notif-5',
        type: NotificationType.castingApplication,
        primarySubject: '50 People',
        actionText: 'applied to your casting call',
        targetObject: "Don 3'",
        timeAgo: '3 hours ago',
        timestamp: now.subtract(const Duration(hours: 3)),
        isCastingIcon: true,
      ),
      NotificationItem(
        id: 'notif-6',
        type: NotificationType.connectionRequest,
        primarySubject: 'Filmfare',
        actionText: 'sent you a connection request',
        timeAgo: '3 hours ago',
        timestamp: now.subtract(const Duration(hours: 3, minutes: 15)),
        isFilmfare: true,
        senderId: UserPersonaNotifier.filmfareId,
        requestStatus: ConnectionRequestNotificationStatus.pending,
      ),
      NotificationItem(
        id: 'notif-7',
        type: NotificationType.like,
        primarySubject: 'Muhammad Ali',
        actionText: 'liked your post',
        timeAgo: '4 hours ago',
        timestamp: now.subtract(const Duration(hours: 4)),
        avatarUrl: TalentDirectory.muhammadAli.avatarUrl,
        senderId: TalentDirectory.muhammadAliId,
      ),
      NotificationItem(
        id: 'notif-8',
        type: NotificationType.like,
        primarySubject: 'Ranveer Singh',
        actionText: 'liked your post',
        timeAgo: '4 hours ago',
        timestamp: now.subtract(const Duration(hours: 4, minutes: 30)),
        avatarUrl: TalentDirectory.ranveerSingh.avatarUrl,
        senderId: TalentDirectory.ranveerSinghId,
      ),
    ];
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        final list = decoded
            .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        state = state.copyWith(items: list, isLoading: false);
        return;
      }
    } catch (_) {}

    // First run: load initial design mocks
    final defaults = _buildDefaultNotifications();
    state = state.copyWith(items: defaults, isLoading: false);
    _persist(defaults);
  }

  Future<void> _persist(List<NotificationItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(items.map((i) => i.toJson()).toList());
      await prefs.setString(_prefKey, raw);
    } catch (_) {}
  }

  Future<void> acceptConnection(NotificationItem item) async {
    final activePersona = ref.read(userPersonaProvider);
    final senderId = item.senderId;

    if (senderId != null && senderId.isNotEmpty) {
      await _connectionRepo.acceptConnection(
        userId: activePersona.id,
        senderUserId: senderId,
      );
      // Refresh chat list connected users
      ref.read(chatListProvider.notifier).refreshConnections();
    }

    final updated = state.items.map((it) {
      if (it.id == item.id) {
        return it.copyWith(
          requestStatus: ConnectionRequestNotificationStatus.accepted,
          isRead: true,
        );
      }
      return it;
    }).toList();

    state = state.copyWith(items: updated);
    _persist(updated);
  }

  Future<void> declineConnection(NotificationItem item) async {
    final activePersona = ref.read(userPersonaProvider);
    final senderId = item.senderId;

    if (senderId != null && senderId.isNotEmpty) {
      await _connectionRepo.declineConnection(
        userId: activePersona.id,
        senderUserId: senderId,
      );
      ref.read(chatListProvider.notifier).refreshConnections();
    }

    final updated = state.items.map((it) {
      if (it.id == item.id) {
        return it.copyWith(
          requestStatus: ConnectionRequestNotificationStatus.rejected,
          isRead: true,
        );
      }
      return it;
    }).toList();

    state = state.copyWith(items: updated);
    _persist(updated);
  }

  void deleteNotification(String id) {
    final updated = state.items.where((it) => it.id != id).toList();
    state = state.copyWith(items: updated);
    _persist(updated);
  }

  void markAsRead(String id) {
    final updated = state.items.map((it) {
      if (it.id == id) {
        return it.copyWith(isRead: true);
      }
      return it;
    }).toList();

    state = state.copyWith(items: updated);
    _persist(updated);
  }

  void markAllAsRead() {
    final updated = state.items.map((it) => it.copyWith(isRead: true)).toList();
    state = state.copyWith(items: updated);
    _persist(updated);
  }

  void clearAll() {
    state = state.copyWith(items: []);
    _persist([]);
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
  NotificationNotifier.new,
);
