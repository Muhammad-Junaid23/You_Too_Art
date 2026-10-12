import 'package:you_too_art/core/utils/json_utils.dart';

/// Represents a post item in the social feed.
class PostItem {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String? authorRole;
  final String caption;
  final String? mediaUrl;
  final String? mediaType;
  final DateTime? createdAt;
  final int likeCount;
  final bool isLiked;
  final int commentCount;
  final int shareCount;

  const PostItem({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.authorRole,
    required this.caption,
    this.mediaUrl,
    this.mediaType,
    this.createdAt,
    this.likeCount = 0,
    this.isLiked = false,
    this.commentCount = 0,
    this.shareCount = 0,
  });

  factory PostItem.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final author = json['author'] as Map<String, dynamic>?;
    final likes = json['post_likes'] as List<dynamic>? ?? [];

    String name = 'User';
    String? avatar;
    String? role;

    if (author != null) {
      final firstName = author['first_name'] as String? ?? '';
      final lastName = author['last_name'] as String? ?? '';
      final fullName = '$firstName $lastName'.trim();
      name = fullName.isNotEmpty ? fullName : (author['name'] as String? ?? 'User');
      avatar = author['profile_image_path'] as String?;
      role = author['role'] as String?;
    }

    final isLiked = currentUserId != null &&
        likes.any((l) => l is Map && l['user_id'] == currentUserId);

    return PostItem(
      id: parseString(json['id']),
      authorId: parseString(json['author_id']),
      authorName: name,
      authorAvatar: avatar,
      authorRole: role,
      caption: parseString(json['caption']),
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String? ?? 'image',
      createdAt: parseDateTime(json['created_at']),
      likeCount: likes.length,
      isLiked: isLiked,
      commentCount: parseInt(json['comment_count'], defaultValue: 0),
      shareCount: parseInt(json['share_count'], defaultValue: 0),
    );
  }

  PostItem copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? authorRole,
    String? caption,
    String? mediaUrl,
    String? mediaType,
    DateTime? createdAt,
    int? likeCount,
    bool? isLiked,
    int? commentCount,
    int? shareCount,
  }) {
    return PostItem(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      authorRole: authorRole ?? this.authorRole,
      caption: caption ?? this.caption,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
    );
  }
}
