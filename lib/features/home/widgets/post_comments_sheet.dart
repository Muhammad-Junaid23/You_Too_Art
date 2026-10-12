import 'package:flutter/material.dart';
import 'package:you_too_art/features/home/models/post_item.dart';

/// Modal bottom sheet showing post comments matching Figma Image 5.
class PostCommentsSheet extends StatefulWidget {
  final PostItem post;

  const PostCommentsSheet({
    super.key,
    required this.post,
  });

  static Future<void> show(BuildContext context, PostItem post) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PostCommentsSheet(post: post),
    );
  }

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  final _commentController = TextEditingController();

  final List<Map<String, String>> _comments = [
    {
      'name': 'Muhammad Ali Nizami',
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      'time': '2 Days Ago',
      'text': 'Good to see you again. Best of Luck!',
    },
    {
      'name': 'Yusra Hafeez',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
      'time': '2 Days Ago',
      'text': 'Best of Luck!',
    },
    {
      'name': 'Qasim Muneer',
      'avatar': 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=150',
      'time': '2 Days Ago',
      'text': 'I am glad, you\'re back. You were supposed to be back soon. Best of Luck Champ!',
    },
    {
      'name': 'Shabir Jan',
      'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
      'time': '2 Days Ago',
      'text': 'Good to see you again. Best of Luck!',
    },
    {
      'name': 'Kashaf Saeed',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      'time': '2 Days Ago',
      'text': 'Good to see you again. Best of Luck!',
    },
    {
      'name': 'Qasim Muneer',
      'avatar': 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=150',
      'time': '2 Days Ago',
      'text': 'Looking forward to this exciting project!',
    },
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _comments.insert(0, {
        'name': 'You',
        'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        'time': 'Just now',
        'text': text,
      });
      _commentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  'Post Comments (14k)',
                  style: TextStyle(
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
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                final comment = _comments[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFE7F3FE),
                        backgroundImage: NetworkImage(comment['avatar']!),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  color: const Color(0xFFE6E7E8).withValues(alpha: 0.5),
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

          // Bottom comment input bar
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE6E7E8)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE6E7E8)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9B9B9B),
                        ),
                        border: InputBorder.none,
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
