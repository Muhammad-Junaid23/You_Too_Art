import 'package:flutter/material.dart';
import 'package:you_too_art/core/widgets/app_avatar.dart';
import 'package:you_too_art/features/home/models/post_item.dart';

/// Modal bottom sheet showing users who liked a post, matching Figma Image 5.
class PostLikesSheet extends StatelessWidget {
  final PostItem post;

  const PostLikesSheet({
    super.key,
    required this.post,
  });

  static Future<void> show(BuildContext context, PostItem post) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PostLikesSheet(post: post),
    );
  }

  static const List<Map<String, String>> _sampleLikers = [
    {
      'name': 'Muhammad Ali Nizami',
      'subtitle': 'Connection',
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
    },
    {
      'name': 'Yasir Hafeez',
      'subtitle': 'Connection',
      'avatar': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
    },
    {
      'name': 'Qasim Muneer',
      'subtitle': 'Actor',
      'avatar': 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=150',
    },
    {
      'name': 'Shabir Jan',
      'subtitle': 'Veteran Actor',
      'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
    },
    {
      'name': 'Kashif Saeed',
      'subtitle': 'Director',
      'avatar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
    },
    {
      'name': 'Muhammad Saeed',
      'subtitle': 'Producer',
      'avatar': 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150',
    },
    {
      'name': 'Usman Nazer',
      'subtitle': 'Cinematographer',
      'avatar': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150',
    },
    {
      'name': 'Irfan Naeem',
      'subtitle': 'Model',
      'avatar': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=150',
    },
    {
      'name': 'Touseef Ahmed',
      'subtitle': 'Writer',
      'avatar': 'https://images.unsplash.com/photo-1463453091185-61582044d556?w=150',
    },
    {
      'name': 'Abdurrehman',
      'subtitle': 'Editor',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    },
    {
      'name': 'Salman Khan Yousafzai',
      'subtitle': 'Actor',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    },
    {
      'name': 'Tariq Iqbal',
      'subtitle': 'Voice Artist',
      'avatar': 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150',
    },
  ];

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) {
      final value = (count / 1000).toStringAsFixed(1);
      return '${value.endsWith('.0') ? value.substring(0, value.length - 2) : value}k';
    }
    final value = (count / 1000000).toStringAsFixed(1);
    return '${value.endsWith('.0') ? value.substring(0, value.length - 2) : value}m';
  }

  @override
  Widget build(BuildContext context) {
    final likeDisplay = _formatCount(post.likeCount > 0 ? post.likeCount : 141200);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFB8BFC8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Post Likes ($likeDisplay)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF000000),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF2F4F7),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF474B51),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFE6E7E8)),

          // List of likers
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _sampleLikers.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 0.5,
                indent: 68,
                color: Color(0xFFE6E7E8),
              ),
              itemBuilder: (context, index) {
                final liker = _sampleLikers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      AppAvatar(
                        imageUrl: liker['avatar'],
                        name: liker['name'] ?? 'User',
                        radius: 20,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              liker['name']!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF000000),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              liker['subtitle']!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9B9B9B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
