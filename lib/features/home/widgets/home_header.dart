import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:you_too_art/features/home/providers/home_feed_provider.dart';

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

    final displayName = user?.firstName.isNotEmpty == true
        ? user!.firstName
        : (user?.name.isNotEmpty == true ? user!.name : 'Wajahat');

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
          IconButton(
            onPressed: onNotificationTap ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications coming soon!')),
                  );
                },
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF3899F3),
              size: 26,
            ),
            splashRadius: 24,
          ),
        ],
      ),
    );
  }
}
