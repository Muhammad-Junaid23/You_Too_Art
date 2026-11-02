import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:you_too_art/core/widgets/app_avatar.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';

/// "Have something to share?" quick creation section matching Figma Image 1.
class QuickShareBox extends ConsumerWidget {
  final VoidCallback? onTapShare;
  final VoidCallback? onTapPhoto;
  final VoidCallback? onTapText;

  const QuickShareBox({
    super.key,
    this.onTapShare,
    this.onTapPhoto,
    this.onTapText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final user = userAsync.value;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Avatar + "Have something to share?"
              InkWell(
                onTap: onTapShare,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      AppAvatar(
                        imageUrl: user?.profileImagePath,
                        name: user?.name.isNotEmpty == true
                            ? user!.name
                            : (user?.email.split('@').first ?? 'User'),
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Have something to share?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9B9B9B),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bottom pills: Photo & Aa Text
              Row(
                children: [
                  // Photo pill
                  InkWell(
                    onTap: onTapPhoto ?? onTapShare,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F3FE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_outlined,
                            size: 16,
                            color: Color(0xFF3899F3),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Photo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3899F3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Aa Text pill
                  InkWell(
                    onTap: onTapText ?? onTapShare,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x19FF5F2D),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Aa',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF5F2D),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Text',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF5F2D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Divider strip between create post section and feed
        Container(
          height: 8,
          width: double.infinity,
          color: const Color(0xFFE6E7E8),
        ),
      ],
    );
  }
}
