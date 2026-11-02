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
import 'package:supabase_flutter/supabase_flutter.dart';
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
    final rel = await repo.getRelationshipStatus(
      currentUserId: activePersona.id,
      targetUserId: widget.initialTalent.id,
    );
    final followingSet = await repo.getFollowingIds(activePersona.id);
    final isFol = followingSet.contains(widget.initialTalent.id);
    final folCount = await repo.getFollowersCount(widget.initialTalent.id);

    if (!mounted) return;
    setState(() {
      _isFollowing = isFol;
      _followersCount = folCount;
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
    final isMessageable = isProd
        ? talent.isFollowing
        : (talent.connectionStatus == ConnectionStatus.connected ||
            ref.read(chatListProvider.notifier).canMessageUser(talent.id));

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
            isProd
                ? 'Follow ${talent.name} first to start chatting!'
                : 'Connect with ${talent.name} first to start chatting!',
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

    final isOwnProfile = (currentUid != null && widget.initialTalent.id == currentUid) ||
        (currentUser != null && widget.initialTalent.id == currentUser.id) ||
        UserPersonaNotifier.isSamePersona(
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

    final baseTalent = (isOwnProfile && currentUser != null)
        ? TalentModel.fromUser(
            currentUser,
            connectionStatus: _currentStatus ?? widget.initialTalent.connectionStatus,
          ).copyWith(
            connectsCount: '',
            postsCount: dynamicPostsCount,
            workPortfolio: portfolio.photos.map((p) => p.mediaUrl).toList(),
          )
        : (isOwnProfile
            ? TalentModel.fromPersona(
                activePersona,
                connectsCount: '',
                postsCount: dynamicPostsCount,
                workPortfolio: portfolio.photos.map((p) => p.mediaUrl).toList(),
              )
            : (targetPersona != null
                ? TalentModel.fromPersona(
                    targetPersona,
                    postsCount: dynamicPostsCount,
                    workPortfolio: portfolio.photos.map((p) => p.mediaUrl).toList(),
                  )
                : (fromState ??
                    TalentDirectory.findById(widget.initialTalent.id) ??
                    widget.initialTalent)));

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
            : (effectiveFollowing ? '1' : '0'))
        : '0';

    final talent = baseTalent.copyWith(
      connectionStatus: effectiveStatus,
      isFollowing: effectiveFollowing,
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
                                          : talent.connectsCount,
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
      if (isCurrentlyFollowing) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: ElevatedButton(
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Unfollow',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 42,
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
                  child: const Text(
                    'Message',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        return SizedBox(
          width: 160,
          height: 42,
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
            child: const Text(
              'Follow',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    } else {
      final effectiveStatus = _currentStatus ?? talent.connectionStatus;
      switch (effectiveStatus) {
        case ConnectionStatus.none:
          return SizedBox(
            width: 220,
            height: 42,
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
              child: const Text(
                'Send Connection Request',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          );

        case ConnectionStatus.pendingOutgoing:
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
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
                label: const Text(
                  'Request Sent (Tap to Cancel)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3899F3),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFE7F3FE),
                  side: const BorderSide(color: Color(0xFF3899F3), width: 1.2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          );

        case ConnectionStatus.pendingIncoming:
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 42,
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
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    'Accept Request',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3899F3),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 42,
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
                  label: const Text(
                    'Decline',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF474B51),
                    side:
                        const BorderSide(color: Color(0xFFD0D5DD), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ],
          );

        case ConnectionStatus.connected:
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 175,
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
                  child: const Text(
                    'Remove Connection',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 135,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => _onMessageTapped(context, talent),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3899F3),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Message',
                    maxLines: 1,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
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
    final bioText = (isOwnProfile && currentUser != null && currentUser.bio != null && currentUser.bio!.isNotEmpty)
        ? currentUser.bio!
        : ((effective?.bio.isNotEmpty ?? false)
            ? effective!.bio
            : (talent.bio?.isNotEmpty ?? false
                ? talent.bio!
                : (isProd
                    ? 'Official production house and studio on You Too Art.'
                    : 'Passionate performing artist and creator on You Too Art.')));

    final locationText = (isOwnProfile && currentUser != null && currentUser.location != null && currentUser.location!.isNotEmpty)
        ? currentUser.location!
        : ((effective?.location.isNotEmpty ?? false)
            ? effective!.location
            : (talent.location ?? talent.aboutInfo['Location'] ?? ''));

    final website = (effective?.website.isNotEmpty ?? false)
        ? effective!.website
        : (talent.aboutInfo['Website'] ?? talent.aboutInfo['Personal Website'] ?? '');

    final establishedYear = (isOwnProfile && currentUser != null && currentUser.establishedYear != null)
        ? '${currentUser.establishedYear}'
        : (talent.aboutInfo['Established'] ?? '');

    final incNumber = (isOwnProfile && currentUser != null && currentUser.incorporationNumber != null && currentUser.incorporationNumber!.isNotEmpty)
        ? currentUser.incorporationNumber!
        : (talent.aboutInfo['Incorporation'] ?? '');

    final officeAddress = (isOwnProfile && currentUser != null && currentUser.address != null && currentUser.address!.isNotEmpty)
        ? currentUser.address!
        : (talent.aboutInfo['Address'] ?? '');

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
            if (talent.aboutInfo['Experience'] != null &&
                talent.aboutInfo['Experience']!.isNotEmpty &&
                talent.aboutInfo['Experience'] != '5+ Years') ...[
              _buildAboutSection(
                label: 'Experience',
                value: talent.aboutInfo['Experience']!,
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
                  Stack(
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
                  const SizedBox(height: 10),
                  Text(
                    currentVideo.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentVideo.url,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF3899F3),
                      decoration: TextDecoration.underline,
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
              child: const Column(
                children: [
                  Icon(Icons.video_library_outlined,
                      size: 40, color: Color(0xFFBDBDBD)),
                  SizedBox(height: 8),
                  Text(
                    'No videos yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF757575),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap + above to add video links or showreels',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: buildPortfolioImage(
                      currentPhoto.mediaUrl,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentPhoto.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentPhoto.url,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF3899F3),
                      decoration: TextDecoration.underline,
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
              child: const Column(
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 40, color: Color(0xFFBDBDBD)),
                  SizedBox(height: 8),
                  Text(
                    'No photos yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF757575),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap + above to add photos or portfolio stills',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
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
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(tabs.length, (index) {
                final tab = tabs[index];
                final isSelected = index == selectedIndex;
                final activeColor = isSelected
                    ? const Color(0xFF3899F3)
                    : const Color(0xFF8E95A0);

                return GestureDetector(
                  onTap: () => onTabSelected(index),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.icon,
                          size: 20,
                          color: activeColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: activeColor,
                          ),
                        ),
                      ],
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
