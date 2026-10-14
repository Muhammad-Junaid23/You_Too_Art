import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/widgets/app_avatar.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/home/models/post_item.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';

/// Modal bottom sheet showing post comments with Supabase persistence and no double border.
class PostCommentsSheet extends ConsumerStatefulWidget {
  final PostItem post;

  const PostCommentsSheet({super.key, required this.post});

  static Future<void> show(BuildContext context, PostItem post) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PostCommentsSheet(post: post),
    );
  }

  @override
  ConsumerState<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends ConsumerState<PostCommentsSheet> {
  final _commentController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, String>> _comments = [];

  static const List<Map<String, String>> _defaultSampleComments = [
    {
      'name': 'Alexander Cole',
      'avatar':
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      'time': '2 Days Ago',
      'text': 'Good to see you again. Best of Luck!',
    },
    {
      'name': 'Yusra Hafeez',
      'avatar':
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
      'time': '2 Days Ago',
      'text': 'Best of Luck!',
    },
    {
      'name': 'Qasim Muneer',
      'avatar':
          'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=150',
      'time': '2 Days Ago',
      'text': 'I am glad, you\'re back. You were supposed to be back soon. Best of Luck Champ!',
    },
    {
      'name': 'Shabir Jan',
      'avatar':
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
      'time': '2 Days Ago',
      'text': 'Good to see you again. Best of Luck!',
    },
    {
      'name': 'Kashaf Saeed',
      'avatar':
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      'time': '2 Days Ago',
      'text': 'Good to see you again. Best of Luck!',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final isSamplePost = widget.post.id.startsWith('00000000-') ||
        widget.post.id.startsWith('sample-');

    try {
      final repo = ref.read(postRepositoryProvider);
      final raw = await repo.fetchCommentsWithAuthors(widget.post.id);
      if (raw.isNotEmpty) {
        final loaded = raw.map((item) {
          final author = item['author'] as Map<String, dynamic>?;
          String authorName = 'User';
          String? authorAvatar;
          if (author != null) {
            final fName = author['first_name'] as String? ?? '';
            final lName = author['last_name'] as String? ?? '';
            final full = '$fName $lName'.trim();
            authorName = full.isNotEmpty
                ? full
                : (author['name'] as String? ?? 'User');
            authorAvatar = author['profile_image_path'] as String?;
          }
          return {
            'name': authorName,
            'avatar': authorAvatar ?? '',
            'time': 'Just now',
            'text': item['text']?.toString() ?? '',
          };
        }).toList();

        if (mounted) {
          setState(() {
            _comments = loaded;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading comments: $e');
    }

    if (mounted) {
      setState(() {
        _comments = isSamplePost ? List.from(_defaultSampleComments) : [];
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final currentUid = ref.read(currentUidProvider) ??
        ref.read(supabaseClientProvider).auth.currentUser?.id;
    final userProfile = currentUid != null
        ? await ref.read(userRepositoryProvider).getById(currentUid)
        : null;

    final myName = userProfile?.name.isNotEmpty == true
        ? userProfile!.name
        : 'You';
    final myAvatar = userProfile?.profileImagePath ?? '';

    setState(() {
      _comments.insert(0, {
        'name': myName,
        'avatar': myAvatar,
        'time': 'Just now',
        'text': text,
      });
      _commentController.clear();
    });

    // Increment comment count in the home feed post immediately
    ref.read(homeFeedProvider.notifier).incrementCommentCount(widget.post.id);

    final isSample = widget.post.id.startsWith('00000000-') ||
        widget.post.id.startsWith('sample-');

    if (currentUid != null && !isSample) {
      try {
        await ref
            .read(postRepositoryProvider)
            .addComment(
              postId: widget.post.id,
              authorId: currentUid,
              text: text,
            );
      } catch (e) {
        if (kDebugMode) debugPrint('Error persisting comment: $e');
      }
    }
  }

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
    final isSample = widget.post.id.startsWith('00000000-') ||
        widget.post.id.startsWith('sample-');
    final count = isSample
        ? (_comments.length > widget.post.commentCount
            ? _comments.length
            : (widget.post.commentCount > 0 ? widget.post.commentCount : 14000))
        : _comments.length;
    final displayCount = _formatCount(count);

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
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
                  'Post Comments ($displayCount)',
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

          // Comments list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3899F3)),
                  )
                : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'No comments yet. Start the conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9B9B9B),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppAvatar(
                                  imageUrl: comment['avatar'],
                                  name: comment['name'] ?? 'User',
                                  radius: 18,
                                ),
                                const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        comment['name']!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF000000),
                                        ),
                                      ),
                                      Text(
                                        comment['time']!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9B9B9B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFE6E7E8)
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: Text(
                                      comment['text']!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1D1F21),
                                        height: 1.35,
                                      ),
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

          // Bottom comment input bar (NO double border, clean OutlineInputBorder)
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE6E7E8))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF000000),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        hintText: 'Write a comment...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9B9B9B),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: Color(0xFFE6E7E8),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: Color(0xFFE6E7E8),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: Color(0xFF3899F3),
                            width: 1,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addComment,
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF3899F3),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
