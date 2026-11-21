import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/repositories/connection_repository.dart';
import 'package:you_too_art/core/repositories/notification_repository.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/chats/providers/chat_provider.dart';
import 'package:you_too_art/features/network/providers/network_provider.dart';
import 'package:you_too_art/features/notifications/models/notification_item.dart';
import 'package:you_too_art/features/talent/providers/talent_provider.dart';

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
  late NotificationRepository _notifRepo;
  late ConnectionRepository _connectionRepo;
  StreamSubscription<List<NotificationItem>>? _sub;

  @override
  NotificationState build() {
    _notifRepo = ref.watch(notificationRepositoryProvider);
    _connectionRepo = ref.watch(connectionRepositoryProvider);
    final currentUid = ref.watch(currentUidProvider);
    final activePersona = ref.watch(userPersonaProvider);
    final effectiveUserId = (currentUid != null && currentUid.isNotEmpty)
        ? currentUid
        : activePersona.id;

    ref.onDispose(() {
      _sub?.cancel();
    });

    if (effectiveUserId.isNotEmpty) {
      Future.microtask(() => _subscribe(effectiveUserId));
    }
    return const NotificationState(isLoading: true);
  }

  void _subscribe(String userId) {
    _sub?.cancel();
    _sub = _notifRepo.watchNotifications(userId).listen((items) {
      Future.microtask(() {
        state = state.copyWith(items: items, isLoading: false);
      });
    });
  }

  String _currentEffectiveId() {
    final curUid = ref.read(currentUidProvider);
    if (curUid != null && curUid.isNotEmpty) return curUid;
    return ref.read(userPersonaProvider).id;
  }

  /// Accept connection request from notification tile
  Future<bool> acceptConnection(NotificationItem item) async {
    final myId = _currentEffectiveId();
    final senderId = item.senderId ?? item.actorId;

    if (senderId != null && senderId.isNotEmpty) {
      final success = await _connectionRepo.acceptConnection(
        userId: myId,
        senderUserId: senderId,
      );
      if (!success) {
        await _notifRepo.deleteNotification(item.id);
        return false;
      }
      // Immediately refresh all screens: chats, talent, and network
      ref.read(chatListProvider.notifier).refreshConnections();
      ref.read(talentListProvider.notifier).fetchTalents();
      ref.read(networkProvider.notifier).refresh();
      return true;
    } else {
      await _notifRepo.updateRequestStatus(
        item.id,
        ConnectionRequestNotificationStatus.accepted,
      );
      return true;
    }
  }

  /// Decline connection request from notification tile
  Future<void> declineConnection(NotificationItem item) async {
    final myId = _currentEffectiveId();
    final senderId = item.senderId ?? item.actorId;

    if (senderId != null && senderId.isNotEmpty) {
      await _connectionRepo.declineConnection(
        userId: myId,
        senderUserId: senderId,
      );
      // Immediately refresh all screens: chats, talent, and network
      ref.read(chatListProvider.notifier).refreshConnections();
      ref.read(talentListProvider.notifier).fetchTalents();
      ref.read(networkProvider.notifier).refresh();
    } else {
      await _notifRepo.updateRequestStatus(
        item.id,
        ConnectionRequestNotificationStatus.rejected,
      );
    }
  }

  /// Delete single notification
  Future<void> deleteNotification(String id) async {
    await _notifRepo.deleteNotification(id);
  }

  /// Mark single notification as read
  Future<void> markAsRead(String id) async {
    await _notifRepo.markAsRead(id);
  }

  /// Mark all notifications as read for current persona
  Future<void> markAllAsRead() async {
    final myId = _currentEffectiveId();
    await _notifRepo.markAllAsRead(myId);
  }

  /// Clear all notifications for current persona
  Future<void> clearAll() async {
    final myId = _currentEffectiveId();
    await _notifRepo.clearAll(myId);
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
  NotificationNotifier.new,
);
