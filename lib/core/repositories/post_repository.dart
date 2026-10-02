import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:you_too_art/core/constants/supabase_tables.dart';

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

  /// Create a new post.
  Future<Map<String, dynamic>> createPost({
    required String authorId,
    required String caption,
    String? mediaUrl,
    String? mediaType,
  }) async {
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
    try {
      await _db.delete().eq('id', postId);
    } catch (e) {
      if (kDebugMode) debugPrint('PostRepository.deletePost: $e');
      rethrow;
    }
  }

  // ─── Likes ────────────────────────────────────────

  /// Toggle a like on a post. Inserts if not liked, deletes if already liked.
  Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {
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
      }
    } catch (e) {
      if (kDebugMode) debugPrint('PostRepository.toggleLike: $e');
      rethrow;
    }
  }

  // ─── Comments ─────────────────────────────────────

  /// Add a comment to a post.
  Future<Map<String, dynamic>> addComment({
    required String postId,
    required String authorId,
    required String text,
  }) async {
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
      rethrow;
    }
  }

  /// Real-time stream of comments for a given [postId].
  Stream<List<Map<String, dynamic>>> watchComments(String postId) {
    return _comments
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at');
  }
}
