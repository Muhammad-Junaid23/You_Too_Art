import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/home/models/post_item.dart';

/// Provider for the current logged-in user's profile.
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) async* {
  final uid = ref.watch(currentUidProvider);
  if (uid == null || uid.trim().isEmpty) {
    yield null;
    return;
  }
  final repo = ref.watch(userRepositoryProvider);
  final immediate = await repo.getById(uid);
  if (immediate != null) yield immediate;
  yield* repo.watch(uid);
});

/// Riverpod 3.x AsyncNotifier for the Home Social Feed.
class HomeFeedNotifier extends AsyncNotifier<List<PostItem>> {
  @override
  Future<List<PostItem>> build() async {
    ref.watch(currentUidProvider);
    return _fetchFeed();
  }

  Future<List<PostItem>> _fetchFeed() async {
    final repo = ref.read(postRepositoryProvider);
    final currentUid = ref.read(currentUidProvider) ??
        ref.read(supabaseClientProvider).auth.currentUser?.id;

    final prefs = ref.read(sharedPreferencesProvider);
    final savedIds =
        prefs.getStringList('saved_post_ids')?.toSet() ?? <String>{};

    try {
      final rawPosts = await repo.fetchFeedWithAuthors();
      if (rawPosts.isNotEmpty) {
        return rawPosts.map((json) {
          final id = json['id']?.toString() ?? '';
          final localTags = prefs.getStringList('post_tags_$id') ?? [];
          final post = PostItem.fromJson(
            json,
            currentUserId: currentUid,
            isSaved: savedIds.contains(id),
          );
          if (localTags.isNotEmpty && post.taggedUsers.isEmpty) {
            return post.copyWith(taggedUsers: localTags);
          }
          return post;
        }).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('HomeFeedNotifier._fetchFeed error: $e');
    }

    // Clean feed: only display real user-created posts
    return [];
  }

  /// Pull-to-refresh the feed.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchFeed());
  }

  /// Optimistically toggle like on a post.
  Future<void> toggleLike(String postId) async {
    final currentPosts = state.value ?? [];
    final postIndex = currentPosts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final targetPost = currentPosts[postIndex];
    final newIsLiked = !targetPost.isLiked;
    final newLikeCount = newIsLiked
        ? targetPost.likeCount + 1
        : (targetPost.likeCount > 0 ? targetPost.likeCount - 1 : 0);

    // Optimistic state update
    final updatedList = List<PostItem>.from(currentPosts);
    updatedList[postIndex] = targetPost.copyWith(
      isLiked: newIsLiked,
      likeCount: newLikeCount,
    );
    state = AsyncValue.data(updatedList);

    final currentUid = ref.read(currentUidProvider) ??
        ref.read(supabaseClientProvider).auth.currentUser?.id;
    final isSample =
        postId.startsWith('sample-') || postId.startsWith('00000000-');

    if (currentUid != null &&
        !isSample &&
        ref.read(supabaseClientProvider).auth.currentUser != null) {
      try {
        await ref.read(postRepositoryProvider).toggleLike(
              postId: postId,
              userId: currentUid,
            );
      } catch (e) {
        if (kDebugMode) debugPrint('HomeFeedNotifier.toggleLike backend notice: $e');
      }
    }
  }

  /// Toggle saved bookmark state for a post and persist to local preferences.
  Future<bool> toggleSavePost(String postId) async {
    final currentPosts = state.value ?? [];
    final postIndex = currentPosts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return false;

    final target = currentPosts[postIndex];
    final newIsSaved = !target.isSaved;

    final updatedList = List<PostItem>.from(currentPosts);
    updatedList[postIndex] = target.copyWith(isSaved: newIsSaved);
    state = AsyncValue.data(updatedList);

    final prefs = ref.read(sharedPreferencesProvider);
    final savedIds =
        prefs.getStringList('saved_post_ids')?.toSet() ?? <String>{};
    if (newIsSaved) {
      savedIds.add(postId);
    } else {
      savedIds.remove(postId);
    }
    await prefs.setStringList('saved_post_ids', savedIds.toList());
    return newIsSaved;
  }

  /// Immediately increment comment count in memory when a user posts a comment.
  void incrementCommentCount(String postId) {
    final currentPosts = state.value ?? [];
    final postIndex = currentPosts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final target = currentPosts[postIndex];
    final updatedList = List<PostItem>.from(currentPosts);
    updatedList[postIndex] = target.copyWith(
      commentCount: target.commentCount + 1,
    );
    state = AsyncValue.data(updatedList);
  }

  String _generateUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hex = now.toRadixString(16).padLeft(12, '0');
    return '00000000-0000-4000-8000-$hex';
  }

  /// Add a newly created post to the feed.
  Future<bool> addNewPost({
    required String caption,
    String? mediaUrl,
    String? mediaType,
    List<String> taggedUsers = const [],
  }) async {
    final currentUid = ref.read(currentUidProvider) ??
        ref.read(supabaseClientProvider).auth.currentUser?.id;

    UserModel? userProfile;
    if (currentUid != null) {
      try {
        userProfile = await ref.read(userRepositoryProvider).getById(currentUid);
      } catch (_) {}
    }

    String? createdId;
    if (currentUid != null &&
        ref.read(supabaseClientProvider).auth.currentUser != null) {
      try {
        final repo = ref.read(postRepositoryProvider);
        final rawPost = await repo.createPost(
          authorId: currentUid,
          caption: caption,
          mediaUrl: mediaUrl,
          mediaType: mediaType ?? 'image',
        );
        createdId = rawPost['id']?.toString();
      } catch (e) {
        if (kDebugMode) debugPrint('HomeFeedNotifier.addNewPost Supabase notice: $e');
      }
    }

    final postUuid = createdId ?? _generateUuid();
    final prefs = ref.read(sharedPreferencesProvider);
    if (taggedUsers.isNotEmpty) {
      await prefs.setStringList('post_tags_$postUuid', taggedUsers);
    }

    final activePersona = ref.read(userPersonaProvider);
    final resolvedAuthorName = activePersona.name.isNotEmpty
        ? activePersona.name
        : (userProfile?.name.isNotEmpty == true ? userProfile!.name : 'User');
    final resolvedAuthorAvatar = activePersona.avatarUrl.isNotEmpty
        ? activePersona.avatarUrl
        : (userProfile?.profileImagePath ??
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150');
    final resolvedAuthorRole = activePersona.role.isNotEmpty
        ? activePersona.role
        : (userProfile?.role ?? 'Actor');
    final resolvedAuthorId = activePersona.id.isNotEmpty
        ? activePersona.id
        : (currentUid ?? 'local-user');

    final newPost = PostItem(
      id: postUuid,
      authorId: resolvedAuthorId,
      authorName: resolvedAuthorName,
      authorAvatar: resolvedAuthorAvatar,
      authorRole: resolvedAuthorRole,
      caption: caption,
      mediaUrl: mediaUrl,
      mediaType: mediaType ?? 'image',
      createdAt: DateTime.now(),
      likeCount: 0,
      isLiked: false,
      isSaved: false,
      commentCount: 0,
      shareCount: 0,
      taggedUsers: taggedUsers,
    );

    final current = state.value ?? [];
    state = AsyncValue.data([newPost, ...current]);
    return true;
  }

  /// Edit caption and media of an existing post.
  Future<bool> updatePost({
    required String postId,
    required String caption,
    String? mediaUrl,
    bool clearMediaUrl = false,
    List<String>? taggedUsers,
  }) async {
    final current = state.value ?? [];
    final index = current.indexWhere((p) => p.id == postId);
    if (index == -1) return false;

    if (taggedUsers != null) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setStringList('post_tags_$postId', taggedUsers);
    }

    final updated = current[index].copyWith(
      caption: caption,
      mediaUrl: mediaUrl,
      clearMediaUrl: clearMediaUrl,
      taggedUsers: taggedUsers,
    );
    final updatedList = List<PostItem>.from(current);
    updatedList[index] = updated;
    state = AsyncValue.data(updatedList);

    try {
      await ref.read(postRepositoryProvider).updatePost(
            postId: postId,
            caption: caption,
            mediaUrl: mediaUrl,
            clearMediaUrl: clearMediaUrl,
          );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('HomeFeedNotifier.updatePost error: $e');
      return false;
    }
  }

  /// Delete a post.
  Future<void> deletePost(String postId) async {
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((p) => p.id != postId).toList());

    try {
      await ref.read(postRepositoryProvider).deletePost(postId);
    } catch (e) {
      if (kDebugMode) debugPrint('HomeFeedNotifier.deletePost error: $e');
    }
  }

}

final homeFeedProvider =
    AsyncNotifierProvider<HomeFeedNotifier, List<PostItem>>(
  HomeFeedNotifier.new,
);
