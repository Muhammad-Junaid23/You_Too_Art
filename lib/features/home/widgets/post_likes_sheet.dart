import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/core/constants/talent_directory.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/utils/role_formatter.dart';
import 'package:you_too_art/core/widgets/app_avatar.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/home/models/post_item.dart';

/// Modal bottom sheet showing users who liked a post, matching Figma Image 5.
class PostLikesSheet extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<PostLikesSheet> createState() => _PostLikesSheetState();
}

class _PostLikesSheetState extends ConsumerState<PostLikesSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _likers = [];

  @override
  void initState() {
    super.initState();
    _loadLikers();
  }

  Future<void> _loadLikers() async {
    try {
      final repo = ref.read(postRepositoryProvider);
      final raw = await repo.fetchLikesWithUsers(widget.post.id);

      final currentUid = ref.read(currentUidProvider) ??
          ref.read(supabaseClientProvider).auth.currentUser?.id;

      // If any liker lacks joined user details, batch fetch from users table
      final missingUserIds = raw
          .where((item) => item['user'] == null && item['user_id'] != null)
          .map((item) => item['user_id'].toString())
          .toSet()
          .toList();
      final Map<String, Map<String, dynamic>> fetchedUsers = {};
      if (missingUserIds.isNotEmpty) {
        try {
          final usersData = await ref
              .read(supabaseClientProvider)
              .from('users')
              .select('id, name, first_name, last_name, profile_image_path, role')
              .filter('id', 'in', missingUserIds);
          for (final u in (usersData as List)) {
            final map = Map<String, dynamic>.from(u as Map);
            final uid = map['id']?.toString() ?? '';
            if (uid.isNotEmpty) fetchedUsers[uid] = map;
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Error batch-fetching liker profiles: $e');
        }
      }

      final loaded = raw.map((item) {
        final userId = item['user_id']?.toString() ?? '';
        final user = (item['user'] as Map<String, dynamic>?) ?? fetchedUsers[userId];

        String likerName = 'User';
        String? likerAvatar;
        String likerSubtitle = 'Artist';

        if (user != null) {
          final fName = user['first_name'] as String? ?? '';
          final lName = user['last_name'] as String? ?? '';
          final full = '$fName $lName'.trim();
          likerName = full.isNotEmpty
              ? full
              : (user['name'] as String? ?? 'User');
          likerAvatar = user['profile_image_path'] as String?;
          final rawRole = user['role'] as String? ?? '';
          if (rawRole.isNotEmpty) {
            likerSubtitle = RoleFormatter.format(rawRole);
          }
        }

        // Fallback to TalentDirectory or Personas if name is still 'User'
        if (likerName == 'User' && userId.isNotEmpty) {
          final talent = TalentDirectory.findById(userId);
          if (talent != null) {
            likerName = talent.name;
            likerAvatar ??= talent.avatarUrl;
            likerSubtitle = RoleFormatter.format(talent.roles);
          } else {
            final persona = UserPersonaNotifier.allPersonas
                .where((p) => p.id == userId)
                .firstOrNull;
            if (persona != null) {
              likerName = persona.name;
              likerAvatar ??= persona.avatarUrl;
              likerSubtitle = RoleFormatter.format(persona.role);
            }
          }
        }

        if (currentUid != null && userId == currentUid) {
          likerSubtitle = 'You';
        }

        return {
          'id': userId,
          'name': likerName,
          'subtitle': likerSubtitle,
          'avatar': likerAvatar ?? '',
        };
      }).toList();

      // If the post is currently liked by the active user, ensure they are in the list
      if (widget.post.isLiked && currentUid != null) {
        final exists = loaded.any((l) => l['id'] == currentUid);
        if (!exists) {
          final activeTalent = TalentDirectory.findById(currentUid);
          final activePersona = UserPersonaNotifier.allPersonas
              .where((p) => p.id == currentUid)
              .firstOrNull;
          final myName =
              activeTalent?.name ?? activePersona?.name ?? 'You';
          final myAvatar =
              activeTalent?.avatarUrl ?? activePersona?.avatarUrl ?? '';
          loaded.insert(0, {
            'id': currentUid,
            'name': myName,
            'subtitle': 'You',
            'avatar': myAvatar,
          });
        }
      }

      if (mounted) {
        setState(() {
          _likers = loaded;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading post likers: $e');
    }

    if (mounted) {
      setState(() {
        _likers = [];
        _isLoading = false;
      });
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
    final likeDisplay = _formatCount(_isLoading ? widget.post.likeCount : _likers.length);

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

          // Body: Loading, Empty, or List of likers
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF3899F3),
                    ),
                  )
                : _likers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.favorite_border_rounded,
                                size: 48,
                                color: Color(0xFFB8BFC8),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No likes yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Be the first to like this post!',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _likers.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 68,
                          color: Color(0xFFE6E7E8),
                        ),
                        itemBuilder: (context, index) {
                          final liker = _likers[index];
                          final name = liker['name']?.toString() ?? 'User';
                          final subtitle =
                              liker['subtitle']?.toString() ?? 'Artist';
                          final avatar = liker['avatar']?.toString();

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                AppAvatar(
                                  imageUrl: avatar,
                                  name: name,
                                  radius: 20,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF000000),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
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
