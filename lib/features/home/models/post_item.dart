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
  final bool isSaved;
  final int commentCount;
  final int shareCount;
  final List<String> taggedUsers;

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
    this.isSaved = false,
    this.commentCount = 0,
    this.shareCount = 0,
    this.taggedUsers = const [],
  });

  factory PostItem.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
    bool isSaved = false,
  }) {
    final author = json['author'] as Map<String, dynamic>?;
    final likes = json['post_likes'] as List<dynamic>? ?? [];
    final comments = json['post_comments'] as List<dynamic>? ?? [];
    final rawTags = json['post_tags'] as List<dynamic>? ?? [];

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

    final commentCount = comments.isNotEmpty
        ? comments.length
        : parseInt(json['comment_count'], defaultValue: 0);

    final taggedUsers = rawTags
        .map((t) => t is Map && t['user'] is Map
            ? (t['user']['name']?.toString() ?? '')
            : (t is String ? t : ''))
        .where((s) => s.isNotEmpty)
        .toList();

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
      isSaved: isSaved,
      commentCount: commentCount,
      shareCount: parseInt(json['share_count'], defaultValue: 0),
      taggedUsers: taggedUsers,
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
    bool clearMediaUrl = false,
    String? mediaType,
    DateTime? createdAt,
    int? likeCount,
    bool? isLiked,
    bool? isSaved,
    int? commentCount,
    int? shareCount,
    List<String>? taggedUsers,
  }) {
    return PostItem(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      authorRole: authorRole ?? this.authorRole,
      caption: caption ?? this.caption,
      mediaUrl: clearMediaUrl ? null : (mediaUrl ?? this.mediaUrl),
      mediaType: clearMediaUrl ? null : (mediaType ?? this.mediaType),
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      taggedUsers: taggedUsers ?? this.taggedUsers,
    );
  }
}
