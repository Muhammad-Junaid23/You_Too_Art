import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/repositories/connection_repository.dart';
import 'package:you_too_art/core/widgets/app_avatar.dart';
import 'package:you_too_art/features/chats/providers/chat_provider.dart';
import 'package:you_too_art/features/home/widgets/post_card.dart';
import 'package:you_too_art/features/network/providers/network_provider.dart';
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
  ConnectionStatus? _currentStatus;
  StreamSubscription<void>? _connSub;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.initialTalent.connectionStatus;
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
    if (!mounted) return;
    setState(() {
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
                title: const Text('Block User', style: TextStyle(color: Colors.red)),
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
    final talentState = ref.watch(talentListProvider);
    final fromState = talentState.findById(widget.initialTalent.id);
    final baseTalent = fromState ?? widget.initialTalent;
    final effectiveStatus = _currentStatus ?? baseTalent.connectionStatus;
    final talent = baseTalent.copyWith(connectionStatus: effectiveStatus);
    final isProd = talent.isProductionHouse;

    return Scaffold(
      backgroundColor: Colors.white,
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

                  // Centered Circular Avatar
                  Center(
                    child: isProd && talent.name.toLowerCase().contains('filmfare')
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
                        : Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: AppAvatar(
                              imageUrl: talent.avatarUrl,
                              name: talent.name,
                              radius: 50,
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Name
                  Text(
                    talent.name,
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
                    talent.roles,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E95A0),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Stat Capsules: Centered compact capsules (Fixed width, matching Figma)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Left Capsule: Connects / Followers
                      Container(
                        width: 146,
                        height: 62,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE0F7EF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.hub_outlined,
                                color: Color(0xFF00C48C),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isProd ? 'Followers' : 'Connects',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF8E95A0),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    isProd
                                        ? talent.followersCount
                                        : talent.connectsCount,
                                    style: const TextStyle(
                                      fontSize: 16,
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
                      const SizedBox(width: 12),

                      // Right Capsule: Posts
                      Container(
                        width: 146,
                        height: 62,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F2FD),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.collections_outlined,
                                color: Color(0xFF3899F3),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'posts',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF8E95A0),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    talent.postsCount,
                                    style: const TextStyle(
                                      fontSize: 16,
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
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Action Buttons Row (Connect / Follow / Remove / Message)
                  _buildActionButtons(context, talent, isProd),
                  const SizedBox(height: 18),
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
            if (talent.posts.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.feed_outlined, size: 54, color: Color(0xFFB8BFC8)),
                        SizedBox(height: 12),
                        Text(
                          'No activity yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'No public updates shared recently.',
                          style: TextStyle(color: Color(0xFF8E95A0), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return PostCard(post: talent.posts[index]);
                  },
                  childCount: talent.posts.length,
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 36),
            ),
          ] else if (_selectedTabIndex == 1) ...[
            // About Tab Content
            SliverToBoxAdapter(
              child: _buildAboutContent(talent, isProd),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 36),
            ),
          ] else if (_selectedTabIndex == 2 && !isProd) ...[
            // Work Tab Content (Talent only)
            if (talent.workPortfolio.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 54, color: Color(0xFFB8BFC8)),
                        SizedBox(height: 12),
                        Text(
                          'No portfolio items yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Work samples and credits will appear here.',
                          style: TextStyle(color: Color(0xFF8E95A0), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final imageUrl = talent.workPortfolio[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFF0F6FE),
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFF8E95A0),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: talent.workPortfolio.length,
                  ),
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
      if (talent.isFollowing) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 140,
              height: 42,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(talentListProvider.notifier).toggleFollow(talent.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Unfollowed ${talent.name}'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
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
                  'Unfollow',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
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
          ],
        );
      } else {
        return SizedBox(
          width: 160,
          height: 42,
          child: ElevatedButton(
            onPressed: () {
              ref.read(talentListProvider.notifier).toggleFollow(talent.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Now following ${talent.name}!'),
                  backgroundColor: const Color(0xFF3899F3),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
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

  Widget _buildAboutContent(TalentModel talent, bool isProd) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              talent.bio ?? 'No biography provided yet.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            isProd ? 'Company Details' : 'Professional Details',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: talent.aboutInfo.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF8E95A0),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
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
            _TabItem(icon: Icons.grid_view_rounded, label: 'Activity'),
            _TabItem(icon: Icons.settings_suggest_outlined, label: 'About'),
          ]
        : [
            _TabItem(icon: Icons.grid_view_rounded, label: 'Activity'),
            _TabItem(icon: Icons.person_outline_rounded, label: 'About'),
            _TabItem(icon: Icons.image_outlined, label: 'Work'),
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

                return GestureDetector(
                  onTap: () => onTabSelected(index),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.icon,
                          size: 19,
                          color: isSelected
                              ? Colors.black
                              : const Color(0xFF8E95A0),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.black
                                : const Color(0xFF8E95A0),
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
