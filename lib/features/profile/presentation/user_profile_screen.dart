import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/core/constants/talent_directory.dart';
import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart'
    hide userPortfolioProvider;
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/repositories/connection_repository.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:you_too_art/features/account/presentation/edit_profile_screen.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/chats/providers/chat_provider.dart';
import 'package:you_too_art/features/home/models/post_item.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';
import 'package:you_too_art/features/home/widgets/post_card.dart';
import 'package:you_too_art/features/network/providers/network_provider.dart';
import 'package:you_too_art/features/profile/providers/user_portfolio_provider.dart';
import 'package:you_too_art/features/profile/widgets/edit_work_media_modal.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';
import 'package:you_too_art/features/talent/providers/talent_provider.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final TalentModel initialTalent;

  const UserProfileScreen({
    super.key,
    required this.initialTalent,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  int _selectedTabIndex = 0;
  int _currentVideoIndex = 0;
  int _currentPhotoIndex = 0;
  ConnectionStatus? _currentStatus;
  bool? _isFollowing;
  int? _followersCount;
  int? _connectionsCount;
  StreamSubscription<void>? _connSub;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.initialTalent.connectionStatus;
    _isFollowing = widget.initialTalent.isFollowing;
    _connSub = ConnectionRepository.connectionChanges.listen((_) {
      if (mounted) _resolveStatus();
    });
    _resolveStatus();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  Future<void> _resolveStatus() async {
    final repo = ref.read(connectionRepositoryProvider);
    final activePersona = ref.read(userPersonaProvider);
    final currentUid = ref.read(currentUidProvider);
    final effectiveUid = (currentUid != null && currentUid.isNotEmpty)
        ? currentUid
        : activePersona.id;

    final rel = await repo.getRelationshipStatus(
      currentUserId: effectiveUid,
      targetUserId: widget.initialTalent.id,
    );
    final followingSet = await repo.getFollowingIds(effectiveUid);
    final isFol = followingSet.contains(widget.initialTalent.id);
    final folCount = await repo.getFollowersCount(widget.initialTalent.id);
    final connCount = await repo.getConnectionsCount(widget.initialTalent.id);

    // Asynchronously fetch remote portfolio items from Supabase if not cached
    try {
      final client = Supabase.instance.client;
      final targetId = widget.initialTalent.id;
      final pRows = await client
          .from('portfolio_items')
          .select()
          .eq('user_id', targetId)
          .order('created_at', ascending: true);
      if (pRows.isNotEmpty) {
        final videos = <WorkMediaItem>[];
        final photos = <WorkMediaItem>[];
        for (final row in pRows) {
          final item = WorkMediaItem.fromJson(row);
          if (item.title.contains('Dramatic Monologue') ||
              item.title.contains('Dramatic Portrait') ||
              item.mediaUrl.contains('cloudinary')) {
            continue;
          }
          if (item.isVideo) {
            videos.add(item);
          } else {
            photos.add(item);
          }
        }
        final cloudPort = UserPortfolioState(videos: videos, photos: photos);
        AppPersistenceService.instance.setCachedPortfolio(targetId, cloudPort);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isFollowing = isFol;
      _followersCount = folCount;
      _connectionsCount = connCount;
      if (rel == 'pending_outgoing') {
        _currentStatus = ConnectionStatus.pendingOutgoing;
      } else if (rel == 'pending_incoming') {
        _currentStatus = ConnectionStatus.pendingIncoming;
      } else if (rel == 'accepted') {
        _currentStatus = ConnectionStatus.connected;
      } else {
        _currentStatus = ConnectionStatus.none;
      }
    });
  }

  void _showMoreOptions(BuildContext context, TalentModel talent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (UserPersonaNotifier.isSamePersona(
                talent.id,
                ref.read(userPersonaProvider).id,
              )) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Colors.black87),
                  title: const Text('Edit Profile'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final updated = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                    if (updated == true && mounted) {
                      setState(() {});
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined, color: Colors.black87),
                  title: const Text('Share Profile'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Profile link copied: @${talent.name}'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF3899F3),
                      ),
                    );
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.share_outlined, color: Colors.black87),
                  title: const Text('Share Profile'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Profile link copied: @${talent.name}'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF3899F3),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.black87),
                  title: const Text('Report Account'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Thank you. We will review this profile.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block_outlined, color: Colors.red),
                  title:
                      const Text('Block User', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Blocked ${talent.name}'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _onMessageTapped(BuildContext context, TalentModel talent) async {
    final isProd = talent.isProductionHouse;
    // Messaging requires an accepted connection across all users and production houses
    final isMessageable = talent.connectionStatus == ConnectionStatus.connected ||
        ref.read(chatListProvider.notifier).canMessageUser(talent.id);

    if (isMessageable) {
      final convId = await ref
          .read(chatListProvider.notifier)
          .startConversationWith(talent);
      if (context.mounted) {
        context.push(
          AppRoutes.chatRoom,
          extra: ChatRoomArgs(
            conversationId: convId,
            peerTalent: talent,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connect with ${talent.name} first to start chatting!',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: isProd ? 'Follow' : 'Connect',
            textColor: const Color(0xFF3899F3),
            onPressed: () {
              if (isProd) {
                ref.read(talentListProvider.notifier).toggleFollow(talent.id);
              } else {
                ref.read(talentListProvider.notifier).toggleConnection(talent.id);
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePersona = ref.watch(userPersonaProvider);
    final currentUid = ref.watch(currentUidProvider);
    final currentUserAsync = ref.watch(currentUserProfileProvider);
    final currentUser = currentUserAsync.value;

    final isOwnProfile = UserPersonaNotifier.isSamePersona(
      widget.initialTalent.id,
      activePersona.id,
    );

    final isActor = UserPersonaNotifier.isActorId(widget.initialTalent.id);
    final targetPersona = isOwnProfile
        ? activePersona
        : (isActor
            ? UserPersonaNotifier.getActorPersona()
            : (UserPersonaNotifier.hasPersona(widget.initialTalent.id)
                ? UserPersonaNotifier.getPersonaById(widget.initialTalent.id)
                : null));

    final talentState = ref.watch(talentListProvider);
    final fromState = talentState.findById(widget.initialTalent.id);

    final portfolio = isOwnProfile
        ? ref.watch(userWorkPortfolioProvider)
        : UserPortfolioNotifier.getPortfolioFor(targetPersona?.id ?? widget.initialTalent.id);

    final allPosts = ref.watch(homeFeedProvider).value ?? [];
    final userFeedPosts = allPosts
        .where((p) =>
            p.authorId == widget.initialTalent.id ||
            (isOwnProfile && currentUid != null && p.authorId == currentUid))
        .toList();
    final dynamicPostsCount = userFeedPosts.length.toString();

    final dynamicConnectsCount = isOwnProfile
        ? ref.watch(networkProvider).connections.length.toString()
        : (_connectionsCount != null
            ? _connectionsCount.toString()
            : (targetPersona != null ? '0' : (widget.initialTalent.connectsCount.isNotEmpty ? widget.initialTalent.connectsCount : '0')));

    final baseTalent = (isOwnProfile && currentUser != null)
        ? TalentModel.fromUser(
            currentUser,
            connectionStatus: _currentStatus ?? widget.initialTalent.connectionStatus,
          ).copyWith(
            connectsCount: dynamicConnectsCount,
            postsCount: dynamicPostsCount,
            workPortfolio: portfolio.photos.map((p) => p.mediaUrl).toList(),
          )
        : (isOwnProfile
            ? TalentModel.fromPersona(
                activePersona,
                connectsCount: dynamicConnectsCount,
                postsCount: dynamicPostsCount,
                workPortfolio: portfolio.photos.map((p) => p.mediaUrl).toList(),
              )
            : (targetPersona != null
                ? TalentModel.fromPersona(
                    targetPersona,
                    connectsCount: dynamicConnectsCount,
                    postsCount: dynamicPostsCount,
                    workPortfolio: portfolio.photos.map((p) => p.mediaUrl).toList(),
                  )
                : (fromState ??
                    TalentDirectory.findById(widget.initialTalent.id) ??
                    widget.initialTalent).copyWith(
                      connectsCount: dynamicConnectsCount,
                    )));

    final isProd = (isOwnProfile && currentUser != null)
        ? (currentUser.role.toLowerCase().contains('production') ||
            currentUser.role.toLowerCase().contains('studio') ||
            (currentUser.incorporationNumber != null &&
                currentUser.incorporationNumber!.isNotEmpty))
        : (baseTalent.isProductionHouse ||
            baseTalent.roles.toLowerCase().contains('production') ||
            baseTalent.roles.toLowerCase().contains('studio') ||
            (targetPersona?.isProductionHouse ?? false));

    final effectiveStatus = _currentStatus ?? baseTalent.connectionStatus;
    final effectiveFollowing = _isFollowing ?? baseTalent.isFollowing;
    final displayFollowersCount = isProd
        ? (_followersCount != null
            ? _followersCount.toString()
            : (effectiveFollowing
                ? '1'
                : (baseTalent.followersCount.isNotEmpty &&
                        baseTalent.followersCount != '0'
                    ? baseTalent.followersCount
                    : '0')))
        : '0';

    final talent = baseTalent.copyWith(
      connectionStatus: effectiveStatus,
      isFollowing: effectiveFollowing,
      connectsCount: dynamicConnectsCount,
      postsCount: dynamicPostsCount,
      followersCount: displayFollowersCount,
      isProductionHouse: isProd,
    );

    final displayName = (isOwnProfile && currentUser != null && currentUser.name.isNotEmpty)
        ? currentUser.name
        : (targetPersona?.name ?? talent.name);
    final displayRoles = (isOwnProfile && currentUser != null && currentUser.role.isNotEmpty && currentUser.role != 'unset')
        ? (isProd ? 'Production House' : currentUser.role)
        : (targetPersona?.role ?? talent.roles);
    final displayAvatar = (isOwnProfile && currentUser != null && currentUser.profileImagePath != null && currentUser.profileImagePath!.isNotEmpty)
        ? currentUser.profileImagePath!
        : (targetPersona?.avatarUrl ?? talent.avatarUrl);

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: isOwnProfile
          ? FloatingActionButton(
              backgroundColor: Colors.black,
              elevation: 4,
              shape: const CircleBorder(),
              onPressed: () async {
                final updated = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                );
                if (updated == true && mounted) {
                  setState(() {});
                }
              },
              child: const Icon(
                Icons.edit,
                color: Colors.white,
                size: 22,
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE6E7E8), width: 1),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Colors.black87,
                size: 20,
              ),
              onPressed: () => _showMoreOptions(context, talent),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // ─── Profile Header ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Centered Circular Avatar with verified badge
                  Center(
                    child: isProd &&
                            displayName.toLowerCase().contains('filmfare')
                        ? Container(
                            width: 100,
                            height: 100,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE50914),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'FILMFARE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          )
                        : Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 46,
                                backgroundColor: const Color(0xFFEEEEEE),
                                backgroundImage: (displayAvatar != null &&
                                        displayAvatar.isNotEmpty)
                                    ? NetworkImage(displayAvatar)
                                    : null,
                                child: (displayAvatar == null ||
                                        displayAvatar.isEmpty)
                                    ? const Icon(Icons.person,
                                        size: 46, color: Colors.grey)
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF3899F3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Name
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),

                  // Subtitle / Roles
                  Text(
                    displayRoles,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E95A0),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Stat Capsules: Centered compact capsules (Responsive, matching Figma)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Left Capsule: Connects / Followers
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 150),
                          height: 62,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(31),
                            border: Border.all(
                              color: const Color(0xFFE6E7E8),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE0F7EF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.hub_outlined,
                                  color: Color(0xFF00C48C),
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isProd ? 'Followers' : 'Connects',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.0,
                                        color: Color(0xFF8E95A0),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    Text(
                                      isProd
                                          ? talent.followersCount
                                          : (talent.connectsCount.isNotEmpty ? talent.connectsCount : '0'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Right Capsule: Posts
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 150),
                          height: 62,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(31),
                            border: Border.all(
                              color: const Color(0xFFE6E7E8),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8F2FD),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.collections_outlined,
                                  color: Color(0xFF3899F3),
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'posts',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.0,
                                        color: Color(0xFF8E95A0),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    Text(
                                      talent.postsCount,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Action Buttons Row (Connect / Follow / Remove / Message) - hidden on own profile
                  if (!isOwnProfile) ...[
                    _buildActionButtons(context, talent, isProd),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),
          ),

          // ─── Pinned Horizontal Sub-Sections TabBar ────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _HorizontalTabHeaderDelegate(
              isProduction: isProd,
              selectedIndex: _selectedTabIndex,
              onTabSelected: (index) {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
            ),
          ),

          // ─── Tab Content ─────────────────────────────────────────────
          if (_selectedTabIndex == 0) ...[
            // Activity Tab Content
            SliverToBoxAdapter(
              child: _buildActivityContent(
                talent,
                isOwnProfile,
                displayName,
                displayAvatar,
              ),
            ),
          ] else if (_selectedTabIndex == 1) ...[
            // About Tab Content
            SliverToBoxAdapter(
              child: _buildAboutContent(
                talent,
                isProd,
                targetPersona,
                activePersona,
                isOwnProfile,
                currentUser: currentUser,
              ),
            ),
          ] else if (_selectedTabIndex == 2 && !isProd) ...[
            // My Work Tab Content
            SliverToBoxAdapter(
              child: _buildWorkContent(
                context,
                portfolio,
                isOwnProfile,
                talent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    TalentModel talent,
    bool isProd,
  ) {
    if (isProd) {
      final isCurrentlyFollowing = _isFollowing ?? talent.isFollowing;
      final isConnected = (_currentStatus ?? talent.connectionStatus) == ConnectionStatus.connected;
      if (isCurrentlyFollowing) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () async {
                    final repo = ref.read(connectionRepositoryProvider);
                    final activePersona = ref.read(userPersonaProvider);
                    await repo.toggleFollowing(activePersona.id, talent.id);
                    final newCount = await repo.getFollowersCount(talent.id);
                    if (mounted) {
                      setState(() {
                        _isFollowing = false;
                        _followersCount = newCount;
                      });
                    }
                    ref.read(talentListProvider.notifier).fetchTalents();
                    ref.read(networkProvider.notifier).refresh();
                    ConnectionRepository.notifyChanges();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Unfollowed ${talent.name}'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF474B51),
                    side: const BorderSide(color: Color(0xFFD0D5DD), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Following',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
            if (isConnected) ...[
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => _onMessageTapped(context, talent),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3899F3),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Message',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      } else {
        return Container(
          constraints: const BoxConstraints(maxWidth: 220),
          height: 44,
          child: ElevatedButton(
            onPressed: () async {
              final repo = ref.read(connectionRepositoryProvider);
              final activePersona = ref.read(userPersonaProvider);
              await repo.toggleFollowing(activePersona.id, talent.id);
              final newCount = await repo.getFollowersCount(talent.id);
              if (mounted) {
                setState(() {
                  _isFollowing = true;
                  _followersCount = newCount;
                });
              }
              ref.read(talentListProvider.notifier).fetchTalents();
              ref.read(networkProvider.notifier).refresh();
              ConnectionRepository.notifyChanges();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Now following ${talent.name}!'),
                    backgroundColor: const Color(0xFF3899F3),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Follow',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      }
    } else {
      final effectiveStatus = _currentStatus ?? talent.connectionStatus;
      switch (effectiveStatus) {
        case ConnectionStatus.none:
          return Container(
            constraints: const BoxConstraints(maxWidth: 240),
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                setState(
                    () => _currentStatus = ConnectionStatus.pendingOutgoing);
                ref
                    .read(talentListProvider.notifier)
                    .sendConnectionRequest(talent.id);
                ref.read(networkProvider.notifier).refresh();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Connection request sent to ${talent.name}!'),
                    backgroundColor: const Color(0xFF3899F3),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Send Connection Request',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );

        case ConnectionStatus.pendingOutgoing:
          return Container(
            constraints: const BoxConstraints(maxWidth: 260),
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => _currentStatus = ConnectionStatus.none);
                ref
                    .read(talentListProvider.notifier)
                    .removeConnection(talent.id);
                ref.read(networkProvider.notifier).refresh();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cancelled connection request to ${talent.name}',
                    ),
                    backgroundColor: const Color(0xFF474B51),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: Color(0xFF3899F3),
              ),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Request Sent (Tap to Cancel)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3899F3),
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFE7F3FE),
                side: const BorderSide(color: Color(0xFF3899F3), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          );

        case ConnectionStatus.pendingIncoming:
          return Row(
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _currentStatus = ConnectionStatus.connected);
                      ref
                          .read(talentListProvider.notifier)
                          .acceptConnection(talent.id);
                      ref.read(networkProvider.notifier).refresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Connected with ${talent.name}!'),
                          backgroundColor: const Color(0xFF12B76A),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Accept Request',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3899F3),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _currentStatus = ConnectionStatus.none);
                      ref
                          .read(talentListProvider.notifier)
                          .removeConnection(talent.id);
                      ref.read(networkProvider.notifier).refresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Declined request from ${talent.name}'),
                          backgroundColor: const Color(0xFF474B51),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: Color(0xFF474B51)),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Decline',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF474B51),
                      side:
                          const BorderSide(color: Color(0xFFD0D5DD), width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );

        case ConnectionStatus.connected:
          return Row(
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _currentStatus = ConnectionStatus.none);
                      ref
                          .read(talentListProvider.notifier)
                          .removeConnection(talent.id);
                      ref.read(networkProvider.notifier).refresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Removed connection with ${talent.name}'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Remove Connection',
                        maxLines: 1,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => _onMessageTapped(context, talent),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3899F3),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Message',
                        maxLines: 1,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
      }
    }
  }

  Widget _buildAboutContent(
    TalentModel talent,
    bool isProd,
    UserPersona? targetPersona,
    UserPersona activePersona,
    bool isOwnProfile, {
    UserModel? currentUser,
  }) {
    final effective = isOwnProfile ? activePersona : targetPersona;
    final rawBio = (isOwnProfile && currentUser != null && currentUser.bio != null && currentUser.bio!.isNotEmpty)
        ? currentUser.bio!
        : ((effective?.bio.isNotEmpty ?? false)
            ? effective!.bio
            : (talent.bio?.isNotEmpty ?? false
                ? talent.bio!
                : ''));

    final isSeedBio = rawBio.contains('Leading digital film studio') ||
        rawBio.contains('Award-winning independent filmmaker') ||
        rawBio.contains('Passionate actor and performing artist') ||
        rawBio.contains('Official production house and studio') ||
        rawBio.contains('Passionate performing artist and creator') ||
        rawBio.contains('Cinematographer and camera operator') ||
        rawBio.contains('Vocalist, playback singer') ||
        rawBio.contains('Professional performing artist');

    final bioText = (!isSeedBio && rawBio.trim().isNotEmpty)
        ? rawBio.trim()
        : (isProd
            ? 'No company bio provided yet.'
            : 'No bio provided yet.');

    final rawLocation = (isOwnProfile && currentUser != null && currentUser.location != null && currentUser.location!.isNotEmpty)
        ? currentUser.location!
        : ((effective?.location.isNotEmpty ?? false)
            ? effective!.location
            : (talent.location ?? ''));

    final isSeedLocation = rawLocation == 'Islamabad, Pakistan' ||
        rawLocation == 'Lahore, Pakistan' ||
        rawLocation == 'Karachi, Pakistan';
    final locationText = (!isSeedLocation && rawLocation.trim().isNotEmpty) ? rawLocation.trim() : '';

    final rawWebsite = (effective?.website.isNotEmpty ?? false)
        ? effective!.website
        : (talent.aboutInfo['Website'] ??
            talent.aboutInfo['Personal Website'] ??
            talent.aboutInfo['Official Website'] ??
            '');
    final isSeedWebsite = rawWebsite.contains('sara-cinematography') ||
        rawWebsite.contains('bilaltariqmusic') ||
        rawWebsite.contains('youtooart.test') ||
        rawWebsite.contains('example.com');
    final website = !isSeedWebsite ? rawWebsite.trim() : '';

    final rawEstablished = (isOwnProfile && currentUser != null && currentUser.establishedYear != null)
        ? '${currentUser.establishedYear}'
        : '';
    final establishedYear = (rawEstablished.isNotEmpty && rawEstablished != '2019') ? rawEstablished : '';

    final rawInc = (isOwnProfile && currentUser != null && currentUser.incorporationNumber != null && currentUser.incorporationNumber!.isNotEmpty)
        ? currentUser.incorporationNumber!
        : '';
    final incNumber = (rawInc.isNotEmpty && rawInc != 'PK-REG-84920') ? rawInc : '';

    final rawAddress = (isOwnProfile && currentUser != null && currentUser.address != null && currentUser.address!.isNotEmpty)
        ? currentUser.address!
        : '';
    final officeAddress = (rawAddress.isNotEmpty && !rawAddress.contains('Blue Area')) ? rawAddress : '';

    final rawExp = (effective?.experience.isNotEmpty ?? false)
        ? effective!.experience
        : (talent.aboutInfo['Experience'] ?? '');
    final isSeedExp = rawExp == '5+ Years' ||
        rawExp == '7+ Years' ||
        rawExp == '8+ Years' ||
        rawExp == '6+ Years' ||
        rawExp == '4+ Years' ||
        rawExp.contains('Experience');
    final experienceText = (!isSeedExp && rawExp.isNotEmpty) ? rawExp : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio / About
          _buildAboutSection(
            label: isProd ? 'About Company' : 'Bio',
            value: bioText,
          ),
          const SizedBox(height: 24),

          if (isProd) ...[
            // Production House specific fields
            if (establishedYear.isNotEmpty) ...[
              _buildAboutSection(
                label: 'Established Year',
                value: establishedYear,
                isBold: true,
              ),
              const SizedBox(height: 24),
            ],
            if (incNumber.isNotEmpty) ...[
              _buildAboutSection(
                label: 'Incorporation Number',
                value: incNumber,
                isBold: true,
              ),
              const SizedBox(height: 24),
            ],
            if (officeAddress.isNotEmpty) ...[
              _buildAboutSection(
                label: 'Studio / Office Address',
                value: officeAddress,
                isBold: true,
              ),
              const SizedBox(height: 24),
            ],
            _buildAboutSection(
              label: 'Category',
              value: 'Production House',
              isBold: true,
            ),
            const SizedBox(height: 24),
          ] else ...[
            // Individual artist specific fields
            _buildAboutSection(
              label: 'Category',
              value: (targetPersona != null && targetPersona.role.isNotEmpty)
                  ? targetPersona.role
                  : ((currentUser != null && currentUser.id == talent.id && currentUser.role.isNotEmpty && currentUser.role != 'unset')
                      ? currentUser.role.split('_').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ')
                      : (talent.roles.isNotEmpty ? talent.roles : 'Creative Artist')),
              isBold: true,
            ),
            const SizedBox(height: 24),
            if (experienceText.isNotEmpty) ...[
              _buildAboutSection(
                label: 'Experience',
                value: experienceText,
                isBold: true,
              ),
              const SizedBox(height: 24),
            ],
          ],

          // Location
          if (locationText.isNotEmpty) ...[
            _buildAboutSection(
              label: 'Location',
              value: locationText,
              isBold: true,
            ),
            const SizedBox(height: 24),
          ],

          // Website (only if real website present, no fake default)
          if (website.isNotEmpty && website != 'www.youtooart.com') ...[
            _buildAboutSection(
              label: isProd ? 'Official Website' : 'Personal Website',
              value: website,
              isBold: true,
            ),
            const SizedBox(height: 24),
          ],

          // Email
          if (talent.email?.isNotEmpty == true) ...[
            _buildAboutSection(
              label: 'Contact Email',
              value: talent.email!,
              isBold: true,
            ),
            const SizedBox(height: 24),
          ],

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildAboutSection({
    required String label,
    required String value,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF9E9E9E),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: const Color(0xFF1A1A2E),
            height: 1.45,
          ),
        ),
      ],
    );
  }

  void _openMediaPreviewModal(BuildContext context, WorkMediaItem item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Title & Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.title.isNotEmpty
                          ? item.title
                          : (item.isVideo ? 'Video Preview' : 'Photo Preview'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 26),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Media Display Container
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 3.5,
                        child: buildPortfolioImage(
                          item.mediaUrl,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                      if (item.isVideo)
                        GestureDetector(
                          onTap: () async {
                            final targetUrl =
                                item.url.isNotEmpty ? item.url : item.mediaUrl;
                            final uri = Uri.tryParse(targetUrl);
                            if (uri != null) {
                              try {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              } catch (_) {}
                            }
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action button (e.g. Watch Video / Open Link)
              if (item.isVideo && item.url.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(item.url);
                      if (uri != null) {
                        try {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text(
                      'Watch Video / Open Link',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3899F3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkContent(
    BuildContext context,
    UserPortfolioState portfolio,
    bool isOwnProfile,
    TalentModel talent,
  ) {
    final targetId = isOwnProfile ? ref.read(userPersonaProvider).id : talent.id;
    final videos = portfolio.videos;
    final photos = portfolio.photos;

    final videoIndex = videos.isEmpty
        ? 0
        : _currentVideoIndex.clamp(0, videos.length - 1);
    final photoIndex = photos.isEmpty
        ? 0
        : _currentPhotoIndex.clamp(0, photos.length - 1);

    final currentVideo = videos.isNotEmpty ? videos[videoIndex] : null;
    final currentPhoto = photos.isNotEmpty ? photos[photoIndex] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Videos Header ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Videos (${videos.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Last Updated, ${currentVideo?.lastUpdated ?? 'Just Now'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
              if (isOwnProfile)
                Row(
                  children: [
                    _buildWorkActionButton(
                      icon: Icons.edit_outlined,
                      bgColor: const Color(0xFFE8F2FD),
                      iconColor: const Color(0xFF3899F3),
                      onTap: currentVideo == null
                          ? () {}
                          : () {
                              EditWorkMediaModal.showEditOrAddModal(
                                context: context,
                                isVideo: true,
                                isEditing: true,
                                existingItem: currentVideo,
                                onSave: (item) {
                                  ref
                                      .read(userWorkPortfolioProvider.notifier)
                                      .updateVideo(videoIndex, item, targetId);
                                  ref.read(talentListProvider.notifier).fetchTalents();
                                  ref.read(networkProvider.notifier).refresh();
                                  setState(() {});
                                },
                                onDelete: () {
                                  ref
                                      .read(userWorkPortfolioProvider.notifier)
                                      .deleteVideo(videoIndex, targetId);
                                  ref.read(talentListProvider.notifier).fetchTalents();
                                  ref.read(networkProvider.notifier).refresh();
                                  if (_currentVideoIndex > 0) {
                                    setState(() {
                                      _currentVideoIndex =
                                          _currentVideoIndex - 1;
                                    });
                                  } else {
                                    setState(() {});
                                  }
                                },
                              );
                            },
                    ),
                    const SizedBox(width: 8),
                    _buildWorkActionButton(
                      icon: Icons.add,
                      bgColor: const Color(0xFFE8F8F3),
                      iconColor: const Color(0xFF00C48C),
                      onTap: () {
                        EditWorkMediaModal.showEditOrAddModal(
                        context: context,
                        isVideo: true,
                        isEditing: false,
                        onSave: (item) {
                          ref
                              .read(userWorkPortfolioProvider.notifier)
                              .addVideo(item, targetId);
                          ref.read(talentListProvider.notifier).fetchTalents();
                          ref.read(networkProvider.notifier).refresh();
                          setState(() {
                            _currentVideoIndex = videos.length;
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Video Card
          if (currentVideo != null) ...[
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _openMediaPreviewModal(context, currentVideo),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: buildPortfolioImage(
                            currentVideo.mediaUrl,
                            height: 190,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 32,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        if (currentVideo.url.toLowerCase().contains('youtu'))
                          Positioned(
                            bottom: 10,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_circle_fill,
                                      size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'YouTube',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _openMediaPreviewModal(context, currentVideo),
                    child: Text(
                      currentVideo.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _openMediaPreviewModal(context, currentVideo),
                    child: Text(
                      currentVideo.url,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF3899F3),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNavCircleButton(
                        icon: Icons.arrow_back,
                        enabled: videoIndex > 0,
                        onTap: () {
                          if (videoIndex > 0) {
                            setState(
                                () => _currentVideoIndex = videoIndex - 1);
                          }
                        },
                      ),
                      Text(
                        '${videoIndex + 1} of ${videos.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      _buildNavCircleButton(
                        icon: Icons.arrow_forward,
                        enabled: videoIndex < videos.length - 1,
                        onTap: () {
                          if (videoIndex < videos.length - 1) {
                            setState(
                                () => _currentVideoIndex = videoIndex + 1);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8E8E8)),
                color: const Color(0xFFFAFAFA),
              ),
              child: Column(
                children: [
                  const Icon(Icons.video_library_outlined,
                      size: 40, color: Color(0xFFBDBDBD)),
                  const SizedBox(height: 8),
                  const Text(
                    'No videos yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOwnProfile
                        ? 'Tap + above to add video links or showreels'
                        : 'No showreels or videos uploaded yet',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // ─── Photos Header ─────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Photos (${photos.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Last Updated, ${currentPhoto?.lastUpdated ?? '2 days ago'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
              if (isOwnProfile)
                Row(
                  children: [
                    _buildWorkActionButton(
                      icon: Icons.edit_outlined,
                      bgColor: const Color(0xFFE8F2FD),
                      iconColor: const Color(0xFF3899F3),
                    onTap: currentPhoto == null
                        ? () {}
                        : () {
                            EditWorkMediaModal.showEditOrAddModal(
                              context: context,
                              isVideo: false,
                              isEditing: true,
                              existingItem: currentPhoto,
                              onSave: (item) {
                                ref
                                    .read(userWorkPortfolioProvider.notifier)
                                    .updatePhoto(photoIndex, item, targetId);
                                ref.read(talentListProvider.notifier).fetchTalents();
                                ref.read(networkProvider.notifier).refresh();
                                setState(() {});
                              },
                              onDelete: () {
                                ref
                                    .read(userWorkPortfolioProvider.notifier)
                                    .deletePhoto(photoIndex, targetId);
                                ref.read(talentListProvider.notifier).fetchTalents();
                                ref.read(networkProvider.notifier).refresh();
                                if (_currentPhotoIndex > 0) {
                                  setState(() {
                                    _currentPhotoIndex =
                                        _currentPhotoIndex - 1;
                                  });
                                } else {
                                  setState(() {});
                                }
                              },
                            );
                          },
                  ),
                  const SizedBox(width: 8),
                  _buildWorkActionButton(
                    icon: Icons.add,
                    bgColor: const Color(0xFFE8F8F3),
                    iconColor: const Color(0xFF00C48C),
                    onTap: () {
                      EditWorkMediaModal.showEditOrAddModal(
                        context: context,
                        isVideo: false,
                        isEditing: false,
                        onSave: (item) {
                          ref
                              .read(userWorkPortfolioProvider.notifier)
                              .addPhoto(item, targetId);
                          ref.read(talentListProvider.notifier).fetchTalents();
                          ref.read(networkProvider.notifier).refresh();
                          setState(() {
                            _currentPhotoIndex = photos.length;
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Photo Card
          if (currentPhoto != null) ...[
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _openMediaPreviewModal(context, currentPhoto),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: buildPortfolioImage(
                        currentPhoto.mediaUrl,
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _openMediaPreviewModal(context, currentPhoto),
                    child: Text(
                      currentPhoto.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _openMediaPreviewModal(context, currentPhoto),
                    child: Text(
                      currentPhoto.url,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF3899F3),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNavCircleButton(
                        icon: Icons.arrow_back,
                        enabled: photoIndex > 0,
                        onTap: () {
                          if (photoIndex > 0) {
                            setState(
                                () => _currentPhotoIndex = photoIndex - 1);
                          }
                        },
                      ),
                      Text(
                        '${photoIndex + 1} of ${photos.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      _buildNavCircleButton(
                        icon: Icons.arrow_forward,
                        enabled: photoIndex < photos.length - 1,
                        onTap: () {
                          if (photoIndex < photos.length - 1) {
                            setState(
                                () => _currentPhotoIndex = photoIndex + 1);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8E8E8)),
                color: const Color(0xFFFAFAFA),
              ),
              child: Column(
                children: [
                  const Icon(Icons.photo_library_outlined,
                      size: 40, color: Color(0xFFBDBDBD)),
                  const SizedBox(height: 8),
                  const Text(
                    'No photos yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOwnProfile
                        ? 'Tap + above to add photos or portfolio stills'
                        : 'No portfolio photos uploaded yet',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildWorkActionButton({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 17),
      ),
    );
  }

  Widget _buildNavCircleButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? const Color(0xFF3899F3) : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? const Color(0xFF3899F3) : const Color(0xFFBDBDBD),
        ),
      ),
    );
  }

  Widget _buildActivityContent(
    TalentModel talent,
    bool isOwnProfile,
    String displayName,
    String? displayAvatar,
  ) {
    final feedAsync = ref.watch(homeFeedProvider);
    final allFeedPosts = feedAsync.value ?? const <PostItem>[];

    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final activePersona = ref.watch(userPersonaProvider);

    // Filter posts from feed that belong to this profile
    final matchingPosts = allFeedPosts.where((post) {
      if (isOwnProfile) {
        return post.authorId == talent.id ||
            post.authorId == activePersona.id ||
            (currentUid != null && post.authorId == currentUid) ||
            post.authorName.toLowerCase() == displayName.toLowerCase();
      }
      return post.authorId == talent.id ||
          post.authorName.toLowerCase() == talent.name.toLowerCase();
    }).toList();

    // Include talent.posts if not already present
    for (final post in talent.posts) {
      if (!matchingPosts.any((p) => p.id == post.id)) {
        matchingPosts.add(post);
      }
    }

    if (matchingPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_on_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No posts yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isOwnProfile
                    ? 'Share photos, updates, or reels to showcase your work'
                    : 'This user has not posted any updates yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < matchingPosts.length; i++) ...[
          PostCard(post: matchingPosts[i]),
          if (i < matchingPosts.length - 1)
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

/// Horizontal Tab Bar Delegate strictly matching the Figma design specifications.
/// The icon and label are aligned horizontally side-by-side with hairline top and bottom dividers.
class _HorizontalTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isProduction;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  _HorizontalTabHeaderDelegate({
    required this.isProduction,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  double get minExtent => 48.0;

  @override
  double get maxExtent => 48.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final tabs = isProduction
        ? [
            const _TabItem(icon: Icons.grid_view_outlined, label: 'Activity'),
            const _TabItem(icon: Icons.person_outline_rounded, label: 'About'),
          ]
        : [
            const _TabItem(icon: Icons.grid_view_outlined, label: 'Activity'),
            const _TabItem(icon: Icons.person_outline_rounded, label: 'About'),
            const _TabItem(
                icon: Icons.video_collection_outlined, label: 'My Work'),
          ];

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F1F3)),
          Expanded(
            child: Row(
              children: List.generate(tabs.length, (index) {
                final tab = tabs[index];
                final isSelected = index == selectedIndex;
                final activeColor = isSelected
                    ? const Color(0xFF3899F3)
                    : const Color(0xFF8E95A0);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTabSelected(index),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              tab.icon,
                              size: 19,
                              color: activeColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight:
                                    isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: activeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F1F3)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_HorizontalTabHeaderDelegate oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isProduction != isProduction;
  }
}

class _TabItem {
  final IconData icon;
  final String label;

  const _TabItem({
    required this.icon,
    required this.label,
  });
}
