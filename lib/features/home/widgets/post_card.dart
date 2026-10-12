import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/home/models/post_item.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';
import 'package:you_too_art/features/home/widgets/post_comments_sheet.dart';
import 'package:you_too_art/features/home/widgets/post_likes_sheet.dart';

/// Post card component strictly matching Figma Image 1 & Image 5.
class PostCard extends ConsumerStatefulWidget {
  final PostItem post;

  const PostCard({
    super.key,
    required this.post,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _likeAnimController;
  late Animation<double> _likeScaleAnimation;

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(_likeAnimController);
  }

  @override
  void dispose() {
    _likeAnimController.dispose();
    super.dispose();
  }

  void _onLikePressed() {
    _likeAnimController.forward(from: 0.0);
    HapticFeedback.lightImpact();
    ref.read(homeFeedProvider.notifier).toggleLike(widget.post.id);
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) {
      final value = (count / 1000).toStringAsFixed(1);
      return '${value.endsWith('.0') ? value.substring(0, value.length - 2) : value}K';
    }
    final value = (count / 1000000).toStringAsFixed(1);
    return '${value.endsWith('.0') ? value.substring(0, value.length - 2) : value}M';
  }

  String _formatTimestamp(DateTime? date) {
    if (date == null) return '2 Days Ago';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return '1 Day Ago';
    if (diff.inDays < 7) return '${diff.inDays} Days Ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} Weeks Ago';
    return '${(diff.inDays / 30).floor()} Months Ago';
  }

  void _showOptionsModal(BuildContext context) {
    final currentUid = ref.read(currentUidProvider);
    final isAuthor = currentUid != null && currentUid == widget.post.authorId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8BFC8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: const Text('Copy Link'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(
                      text: 'https://youtooart.com/post/${widget.post.id}',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bookmark_border_rounded),
                  title: const Text('Save Post'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post saved!')),
                    );
                  },
                ),
                if (isAuthor)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red),
                    title: const Text(
                      'Delete Post',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref
                          .read(homeFeedProvider.notifier)
                          .deletePost(widget.post.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post deleted')),
                      );
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.flag_outlined, color: Colors.red),
                    title: const Text(
                      'Report Post',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thank you. We will review this post.'),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRichCaption(String text) {
    final words = text.split(RegExp(r'\s+'));
    final normalWords = <String>[];
    final hashTags = <String>[];

    for (final word in words) {
      if (word.startsWith('#') && word.length > 1) {
        hashTags.add(word);
      } else if (word.isNotEmpty) {
        normalWords.add(word);
      }
    }

    final normalText = normalWords.join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (normalText.isNotEmpty)
          Text(
            normalText,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF000000),
              height: 1.4,
            ),
          ),
        if (hashTags.isNotEmpty) ...[
          if (normalText.isNotEmpty) const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: hashTags.map((tag) {
              return Text(
                tag,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF3899F3),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Author Info + Circular 3-Dots Button
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 14, bottom: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFE7F3FE),
                  backgroundImage: (post.authorAvatar != null &&
                          post.authorAvatar!.isNotEmpty)
                      ? NetworkImage(post.authorAvatar!)
                      : const NetworkImage(
                          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000000),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestamp(post.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9B9B9B),
                        ),
                      ),
                    ],
                  ),
                ),
                // Circular Outline 3-Dots Button matching Image 1
                GestureDetector(
                  onTap: () => _showOptionsModal(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE6E7E8),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      color: Color(0xFF9B9B9B),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Caption Text
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 12,
              ),
              child: _buildRichCaption(post.caption),
            ),

          // Media Preview Image (Full Width matching Image 1)
          if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty)
            Image.network(
              post.mediaUrl!,
              width: double.infinity,
              height: 320,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 260,
                  color: const Color(0xFFF2F4F7),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 220,
                  color: const Color(0xFFF2F4F7),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 40,
                      color: Color(0xFF9B9B9B),
                    ),
                  ),
                );
              },
            ),

          // Bottom Action Bar: Likes, Comments, Share (Blue outline icons matching Image 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // Like Button (Tapping heart toggles, tapping count opens PostLikesSheet)
                Row(
                  children: [
                    InkWell(
                      onTap: _onLikePressed,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ScaleTransition(
                          scale: _likeScaleAnimation,
                          child: Icon(
                            post.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border_rounded,
                            color: const Color(0xFF3899F3),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => PostLikesSheet.show(context, post),
                      child: Text(
                        _formatCount(post.likeCount),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF000000),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 20),

                // Comment Button (Tapping opens PostCommentsSheet matching Image 5)
                InkWell(
                  onTap: () => PostCommentsSheet.show(context, post),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Color(0xFF3899F3),
                          size: 19,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatCount(post.commentCount),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF000000),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                // Share Button
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(
                      text: 'https://youtooart.com/post/${post.id}',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Post link copied to share!'),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.reply_rounded,
                          color: Color(0xFF3899F3),
                          size: 21,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(post.shareCount),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF000000),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider between posts
          const Divider(height: 1, thickness: 1, color: Color(0xFFE6E7E8)),
        ],
      ),
    );
  }
}
