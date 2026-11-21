import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/core/constants/talent_directory.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/widgets/app_avatar.dart';
import 'package:you_too_art/features/notifications/models/notification_item.dart';
import 'package:you_too_art/features/notifications/providers/notification_provider.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificationProvider);
    final items = notifState.items;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        titleSpacing: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          if (items.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black, size: 22),
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (val) {
                if (val == 'mark_all_read') {
                  ref.read(notificationProvider.notifier).markAllAsRead();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (val == 'clear_all') {
                  ref.read(notificationProvider.notifier).clearAll();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications cleared'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'mark_all_read',
                  child: Row(
                    children: [
                      Icon(Icons.done_all, size: 18, color: Colors.black),
                      SizedBox(width: 10),
                      Text('Mark all as read', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, size: 18, color: Color(0xFFEF4444)),
                      SizedBox(width: 10),
                      Text(
                        'Clear all',
                        style: TextStyle(fontSize: 14, color: Color(0xFFEF4444)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: notifState.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.black,
              ),
            )
          : items.isEmpty
              ? _buildEmptyState(context)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 24,
                    thickness: 0.8,
                    color: Color(0xFFF3F4F6),
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NotificationTile(
                      item: item,
                      onTap: () => _handleItemTap(context, ref, item),
                      onAccept: () async {
                        final success = await ref
                            .read(notificationProvider.notifier)
                            .acceptConnection(item);
                        if (!context.mounted) return;
                        if (!success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'This connection request is no longer available or was cancelled.',
                              ),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'You accepted connection request from ${item.primarySubject}',
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      onReject: () {
                        ref
                            .read(notificationProvider.notifier)
                            .declineConnection(item);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Connection request rejected'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      onDelete: () {
                        ref
                            .read(notificationProvider.notifier)
                            .deleteNotification(item.id);
                      },
                    );
                  },
                ),
    );
  }

  void _handleItemTap(
      BuildContext context, WidgetRef ref, NotificationItem item) {
    ref.read(notificationProvider.notifier).markAsRead(item.id);

    if (item.type == NotificationType.castingCall ||
        item.type == NotificationType.castingApplication) {
      context.go(AppRoutes.casting);
      return;
    }

    // For connection requests or likes, open profile if sender exists
    final senderId = item.senderId;
    if (senderId != null && senderId.isNotEmpty) {
      var talent = TalentDirectory.findById(senderId);
      if (talent == null) {
        final persona = UserPersonaNotifier.allPersonas
            .where((p) => p.id == senderId)
            .firstOrNull;
        if (persona != null) {
          talent = TalentModel(
            id: persona.id,
            name: persona.name,
            roles: persona.role,
            avatarUrl: persona.avatarUrl,
            isProductionHouse: persona.isProductionHouse,
          );
        }
      }
      if (talent != null) {
        context.push(AppRoutes.profileDetail, extra: talent);
      }
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF3F4F6),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'When you receive casting updates, likes, or connection requests, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onAccept,
    required this.onReject,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: !item.isRead
              ? const Color(0xFFF0F7FF)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Leading Avatar / Icon ─────────────────────────────────
            _buildAvatar(),
            const SizedBox(width: 14),

            // ─── Center Content & Actions ──────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: item.primarySubject,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: ' ${item.actionText}',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        if (item.targetObject != null)
                          TextSpan(
                            text: ' ${item.targetObject}',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        item.timeAgo,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      if (!item.isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF3899F3),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Connection Request Action Buttons
                  if (item.type == NotificationType.connectionRequest) ...[
                    const SizedBox(height: 10),
                    if (item.requestStatus ==
                        ConnectionRequestNotificationStatus.pending)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Accept Pill
                          InkWell(
                            onTap: onAccept,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F7EF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 15,
                                    color: Color(0xFF00C48C),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Accept',
                                    style: TextStyle(
                                      color: Color(0xFF00C48C),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Reject Pill
                          InkWell(
                            onTap: onReject,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE8E8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.block,
                                    size: 14,
                                    color: Color(0xFFE02424),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Reject',
                                    style: TextStyle(
                                      color: Color(0xFFE02424),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (item.requestStatus ==
                        ConnectionRequestNotificationStatus.accepted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F7EF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 14,
                              color: Color(0xFF00C48C),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Connected',
                              style: TextStyle(
                                color: Color(0xFF00C48C),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (item.requestStatus ==
                        ConnectionRequestNotificationStatus.rejected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Request rejected',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else if (item.requestStatus ==
                        ConnectionRequestNotificationStatus.cancelled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              size: 14,
                              color: Color(0xFF6B7280),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Request cancelled',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // ─── Trailing More Button ──────────────────────────────────
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1.2,
                ),
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: Color(0xFF374151),
                ),
                padding: EdgeInsets.zero,
                elevation: 3,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (val) {
                  if (val == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: Color(0xFFEF4444)),
                        SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (item.isFilmfare) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFE50914),
        ),
        alignment: Alignment.center,
        child: const Text(
          'FILMFARE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    if (item.isCastingIcon) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFE8F3FF),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.auto_awesome,
          color: Color(0xFF3899F3),
          size: 22,
        ),
      );
    }

    return AppAvatar(
      imageUrl: item.avatarUrl,
      name: item.primarySubject,
      radius: 24,
    );
  }
}
