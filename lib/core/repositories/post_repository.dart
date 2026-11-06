import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/core/constants/talent_directory.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';

/// Repository for social feed post operations.
///
/// Handles CRUD for posts, likes, and comments.
class PostRepository {
  final SupabaseClient _client;

  PostRepository(this._client);

  SupabaseQueryBuilder get _db => _client.from(SupabaseTables.posts);
  SupabaseQueryBuilder get _likes => _client.from(SupabaseTables.postLikes);
  SupabaseQueryBuilder get _comments =>
      _client.from(SupabaseTables.postComments);

  // ─── Feed ─────────────────────────────────────────

  /// Real-time stream of the latest posts ordered by creation date.
  Stream<List<Map<String, dynamic>>> watchFeed({int limit = 50}) {
    return _db
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit);
  }

  /// Fetches latest feed posts joined with author profile and likes.
  Future<List<Map<String, dynamic>>> fetchFeedWithAuthors({
    int limit = 50,
  }) async {
    try {
      final data = await _db
          .select('''
            id,
            author_id,
            caption,
            media_url,
            media_type,
            created_at,
            author:users(id, name, first_name, last_name, profile_image_path, role),
            post_likes(user_id),
            post_comments(id)
          ''')
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if (kDebugMode) debugPrint('PostRepository.fetchFeedWithAuthors: $e');
      rethrow;
    }
  }

  /// Create a new post.
  Future<Map<String, dynamic>> createPost({
    required String authorId,
    required String caption,
    String? mediaUrl,
    String? mediaType,
  }) async {
    if (_client.auth.currentUser == null) {
      return {
        'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
        'author_id': authorId,
        'caption': caption,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
    }
    try {
      final data = await _db
          .insert({
            'author_id': authorId,
            'caption': caption,
            'media_url': mediaUrl,
            'media_type': mediaType,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      return data;
    } catch (e) {
      if (kDebugMode) debugPrint('PostRepository.createPost: $e');
      rethrow;
    }
  }

  /// Delete a post by [postId].
  Future<void> deletePost(String postId) async {
    if (_client.auth.currentUser == null ||
        postId.startsWith('local-') ||
        postId.startsWith('sample-') ||
        postId.startsWith('00000000-')) {
      return;
    }
    try {
      await _db.delete().eq('id', postId);
    } catch (e) {
      if (kDebugMode) debugPrint('PostRepository.deletePost: $e');
    }
  }

  /// Update caption and media of an existing post.
  Future<void> updatePost({
    required String postId,
    required String caption,
    String? mediaUrl,
    bool clearMediaUrl = false,
  }) async {
    if (_client.auth.currentUser == null ||
        postId.startsWith('local-') ||
        postId.startsWith('sample-') ||
        postId.startsWith('00000000-')) {
      return;
    }
    try {
      final updates = <String, dynamic>{'caption': caption};
      if (clearMediaUrl) {
        updates['media_url'] = null;
        updates['media_type'] = null;
      } else if (mediaUrl != null) {
        updates['media_url'] = mediaUrl;
        updates['media_type'] = 'image';
      }
      await _db.update(updates).eq('id', postId);
    } catch (e) {
      if (kDebugMode) debugPrint('PostRepository.updatePost: $e');
    }
  }

  // ─── Likes ────────────────────────────────────────

  /// Toggle a like on a post. Inserts if not liked, deletes if already liked.
  Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {
    if (_client.auth.currentUser == null) {
      // Test accounts or unauthenticated users store likes in-memory / locally
      return;
    }

    try {
      final existing = await _likes
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        await _likes
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else {
        await _likes.insert({
          'post_id': postId,
          'user_id': userId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        _notifyPostAuthorOnLike(postId: postId, likingUserId: userId);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('PostRepository.toggleLike: $e');
    }
  }

  void _notifyPostAuthorOnLike({
    required String postId,
    required String likingUserId,
  }) async {
    try {
      final post = await _db
          .select('author_id, caption')
          .eq('id', postId)
          .maybeSingle();
      if (post == null) return;
      final authorId = post['author_id']?.toString() ?? '';
      if (authorId.isEmpty || authorId == likingUserId) return;

      final likingTalent = TalentDirectory.findById(likingUserId);
      final likingPersona = UserPersonaNotifier.allPersonas
          .where((p) => p.id == likingUserId)
          .firstOrNull;

      final name = likingTalent?.name ??
          likingPersona?.name ??
          'A fellow artist';
      final avatarUrl = likingTalent?.avatarUrl ?? likingPersona?.avatarUrl;
      final isFilmfare = likingUserId == UserPersonaNotifier.filmfareId ||
          likingPersona?.isProductionHouse == true;

      await _client.from(SupabaseTables.notifications).insert({
        'recipient_id': authorId,
        'actor_id': likingUserId,
        'type': 'post_like',
        'primary_subject': name,
        'action_text': 'liked your post',
        'avatar_url': avatarUrl,
        'is_filmfare': isFilmfare,
        'entity_type': 'post',
        'entity_id': postId,
        'request_status': 'none',
        'is_read': false,
      });
    } catch (_) {}
  }

  // ─── Comments ─────────────────────────────────────

  /// Add a comment to a post.
  Future<Map<String, dynamic>> addComment({
    required String postId,
    required String authorId,
    required String text,
  }) async {
    if (_client.auth.currentUser == null) {
      return {
        'id': 'local-cmt-${DateTime.now().millisecondsSinceEpoch}',
        'post_id': postId,
        'author_id': authorId,
        'text': text,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
    }
    try {
      final data = await _comments
          .insert({
            'post_id': postId,
            'author_id': authorId,
            'text': text,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      return data;
    } catch (e) {
      if (kDebugMode) debugPrint('PostRepository.addComment: $e');
      return {
        'id': 'local-cmt-${DateTime.now().millisecondsSinceEpoch}',
        'post_id': postId,
        'author_id': authorId,
        'text': text,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
    }
  }

  /// Real-time stream of comments for a given [postId].
  Stream<List<Map<String, dynamic>>> watchComments(String postId) {
    return _comments
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at');
  }

  /// Fetch comments for a post joined with author info.
  Future<List<Map<String, dynamic>>> fetchCommentsWithAuthors(String postId) async {
    try {
      final data = await _comments
          .select('''
            id,
            post_id,
            author_id,
            text,
            created_at,
            author:users(id, name, first_name, last_name, profile_image_path)
          ''')
          .eq('post_id', postId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if (kDebugMode) debugPrint('PostRepository.fetchCommentsWithAuthors: $e');
      return [];
    }
  }
}
