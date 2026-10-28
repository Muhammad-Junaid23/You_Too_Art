import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:you_too_art/core/constants/test_accounts.dart';
import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/home/models/post_item.dart';

/// Provider for the current logged-in user's profile.
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watch(uid);
});

/// Riverpod 3.x AsyncNotifier for the Home Social Feed.
class HomeFeedNotifier extends AsyncNotifier<List<PostItem>> {
  @override
  Future<List<PostItem>> build() async {
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
          return PostItem.fromJson(
            json,
            currentUserId: currentUid,
            isSaved: savedIds.contains(id),
          );
        }).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('HomeFeedNotifier._fetchFeed error: $e');
    }

    // Default sample posts matching the Figma design to ensure immediate rich aesthetics
    return _samplePosts.map((p) => p.copyWith(isSaved: savedIds.contains(p.id))).toList();
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
        !TestAccounts.isTestId(currentUid) &&
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
        !TestAccounts.isTestId(currentUid) &&
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

    final newPost = PostItem(
      id: postUuid,
      authorId: currentUid ?? 'local-user',
      authorName: userProfile?.name.isNotEmpty == true
          ? userProfile!.name
          : 'Muhammad Wajahat',
      authorAvatar: userProfile?.profileImagePath ??
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      authorRole: userProfile?.role ?? 'Actor',
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

  static final List<PostItem> _samplePosts = [
    PostItem(
      id: '00000000-0000-4000-8000-000000000001',
      authorId: 'b2222222-2222-2222-2222-222222222222',
      authorName: 'SkyPulse Studios',
      authorAvatar:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=150',
      authorRole: 'Production House',
      caption:
          "Official Announcement: SkyPulse Studios is thrilled to begin principal casting for 'Echoes of Rawal'! Check out the Casting section to apply for Lead & Supporting roles. 🎬🎥\n#EchoesOfRawal #CastingCall #SkyPulseStudios #PakistaniCinema",
      mediaUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      likeCount: 2480,
      isLiked: false,
      commentCount: 142,
      shareCount: 68,
    ),
    PostItem(
      id: '00000000-0000-4000-8000-000000000002',
      authorId: '00000000-0000-0000-0000-000000000001',
      authorName: 'Hamza Ali',
      authorAvatar:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      authorRole: 'Actor',
      caption:
          "Rehearsal wrapped for today's dramatic monologue sequence. Loving the script and character depth! Can't wait to share the final cut soon. 🎭\n#ActorLife #CharacterStudy #AuditionTape #Theater",
      mediaUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      likeCount: 1820,
      isLiked: false,
      commentCount: 96,
      shareCount: 34,
    ),
    PostItem(
      id: '00000000-0000-4000-8000-000000000003',
      authorId: 'a1111111-1111-1111-1111-111111111111',
      authorName: 'Zaid Khan',
      authorAvatar:
          'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150',
      authorRole: 'Director',
      caption:
          "Location scouting across the historic alleys of Old Lahore for 'Lahore Tales'. The natural ambient lighting at magic hour is breathtaking. 📽️\n#Filmmaking #DirectorDiaries #IndieFilm #LahoreTales",
      mediaUrl:
          'https://images.unsplash.com/photo-1485846234645-a62644f84728?w=800',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      likeCount: 940,
      isLiked: false,
      commentCount: 48,
      shareCount: 22,
    ),
    PostItem(
      id: '00000000-0000-4000-8000-000000000004',
      authorId: 'c3333333-3333-3333-3333-333333333333',
      authorName: 'Sara Ahmed',
      authorAvatar:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      authorRole: 'Cinematographer',
      caption:
          "Rigging the anamorphic prime package on our soundstage today. Soft atmospheric diffusion paired with high-contrast keys creates that pure cinema feel. 🎥⚡\n#Cinematography #DoP #ArriMini #LightingDesign",
      mediaUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      likeCount: 760,
      isLiked: false,
      commentCount: 31,
      shareCount: 15,
    ),
  ];
}

final homeFeedProvider =
    AsyncNotifierProvider<HomeFeedNotifier, List<PostItem>>(
  HomeFeedNotifier.new,
);
