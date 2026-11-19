import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/features/account/presentation/account_sheets.dart';
import 'package:you_too_art/features/account/presentation/help_support_screen.dart';
import 'package:you_too_art/features/account/presentation/transaction_history_screen.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';
import 'package:you_too_art/features/network/providers/network_provider.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';

/// "My Account" screen matching the exact Figma design
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePersona = ref.watch(userPersonaProvider);
    final userAsync = ref.watch(currentUserProfileProvider);
    final currentUser = userAsync.value;
    final netState = ref.watch(networkProvider);
    final feedPosts = ref.watch(homeFeedProvider).value ?? [];

    final displayName = (currentUser?.name.isNotEmpty == true)
        ? currentUser!.name
        : (currentUser?.firstName.isNotEmpty == true
            ? '${currentUser!.firstName} ${currentUser.lastName}'.trim()
            : (activePersona.name.isNotEmpty && !activePersona.name.toLowerCase().contains('wajahat')
                ? activePersona.name
                : (currentUser?.email.split('@').first ?? 'User')));

    final userImg = currentUser?.profileImagePath;
    final avatarUrl = (userImg != null && userImg.isNotEmpty)
        ? userImg
        : (!activePersona.name.toLowerCase().contains('wajahat')
            ? activePersona.avatarUrl
            : '');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header: "My Account" ──────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text(
                'My Account',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // ─── User Profile Row ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Avatar and Name clickable
                  Expanded(
                    child: InkWell(
                      onTap: () => _openUserProfile(
                        context,
                        currentUser,
                        activePersona,
                        netState,
                        feedPosts,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          // Avatar with Verified badge overlay
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFFEEEEEE),
                                backgroundImage: avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl.isEmpty
                                    ? Text(
                                        displayName.isNotEmpty
                                            ? displayName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3899F3),
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF3899F3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),

                          // Name & Verified Subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Account Verified',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF00C48C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // "View Profile ->" Action
                  InkWell(
                    onTap: () => _openUserProfile(
                      context,
                      currentUser,
                      activePersona,
                      netState,
                      feedPosts,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Profile',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3899F3),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Color(0xFF3899F3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 8),

            // ─── Settings / Navigation Options ─────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildOptionTile(
                    context: context,
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Verify Account',
                    onTap: () => AccountSheets.showVerifyAccount(
                      context,
                      email: currentUser?.email.isNotEmpty == true
                          ? currentUser!.email
                          : activePersona.email,
                      isEmailVerified: true,
                    ),
                  ),
                  _buildOptionTile(
                    context: context,
                    icon: Icons.swap_horiz_rounded,
                    title: 'Transaction History',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TransactionHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  _buildOptionTile(
                    context: context,
                    icon: Icons.support_outlined,
                    title: 'Support',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),
                  _buildOptionTile(
                    context: context,
                    icon: Icons.info_outline_rounded,
                    title: 'About us',
                    onTap: () => AccountSheets.showAboutUs(context),
                  ),
                  _buildOptionTile(
                    context: context,
                    icon: Icons.article_outlined,
                    title: 'Terms & Conditions',
                    onTap: () => AccountSheets.showTermsConditions(context),
                  ),
                  _buildOptionTile(
                    context: context,
                    icon: Icons.article_outlined,
                    title: 'Privacy Policy',
                    onTap: () => AccountSheets.showPrivacyPolicy(context),
                  ),
                  _buildOptionTile(
                    context: context,
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    iconColor: const Color(0xFFFF4D4F),
                    titleColor: const Color(0xFFFF4D4F),
                    onTap: () => AccountSheets.showLogoutModal(
                      context,
                      onLogout: () {
                        ref.read(authProvider.notifier).logout();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF8E95A0),
    Color titleColor = const Color(0xFF1A1A2E),
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 22, color: iconColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Color(0xFF3899F3),
                ),
              ],
            ),
          ),
        ),
        const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFF0F0F0),
        ),
      ],
    );
  }

  void _openUserProfile(
    BuildContext context,
    UserModel? user,
    UserPersona persona,
    NetworkState netState,
    List<dynamic> feedPosts,
  ) {
    TalentModel talent;
    if (persona.name.isNotEmpty) {
      final portfolio = AppPersistenceService.instance.getPortfolio(persona.id);
      final userPosts = feedPosts.where((p) => p.authorId == persona.id).length;
      talent = TalentModel.fromPersona(
        persona,
        connectsCount: '${netState.connections.length}',
        postsCount: '$userPosts',
        workPortfolio: portfolio.photos.map((p) => p.mediaUrl).toList(),
      );
    } else if (user != null) {
      final userPosts = feedPosts.where((p) => p.authorId == user.id).length;
      final portfolio = AppPersistenceService.instance.getPortfolio(user.id);
      talent = TalentModel.fromUser(
        user,
      ).copyWith(
        connectsCount: '${netState.connections.length}',
        postsCount: '$userPosts',
        workPortfolio: portfolio.photos.map((p) => p.mediaUrl).toList(),
      );
    } else {
      final portfolio = AppPersistenceService.instance.getPortfolio(persona.id);
      talent = TalentModel.fromPersona(
        persona,
        connectsCount: '${netState.connections.length}',
        postsCount: '0',
        workPortfolio: portfolio.photos.map((p) => p.mediaUrl).toList(),
      );
    }

    context.push(AppRoutes.profileDetail, extra: talent);
  }
}
