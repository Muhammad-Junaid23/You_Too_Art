import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';
import 'package:you_too_art/features/notifications/providers/notification_provider.dart';

/// Top header for Home Screen with greeting and notification bell matching Image 1.
class HomeHeader extends ConsumerWidget {
  final VoidCallback? onNotificationTap;

  const HomeHeader({
    super.key,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final user = userAsync.value;
    final notifState = ref.watch(notificationProvider);
    final unreadCount = notifState.unreadCount;

    final displayName = user?.firstName.isNotEmpty == true
        ? user!.firstName
        : (user?.name.isNotEmpty == true
            ? user!.name
            : (user?.email.split('@').first ?? 'there'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Hi $displayName!',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF000000),
              letterSpacing: -0.3,
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onNotificationTap ??
                    () => context.push(AppRoutes.notifications),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF3899F3),
                  size: 26,
                ),
                splashRadius: 24,
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
