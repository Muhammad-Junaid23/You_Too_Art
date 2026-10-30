import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/features/account/presentation/account_sheets.dart';
import 'package:you_too_art/features/account/presentation/help_support_screen.dart';
import 'package:you_too_art/features/account/presentation/transaction_history_screen.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';
import 'package:you_too_art/features/network/providers/network_provider.dart';
import 'package:you_too_art/features/profile/presentation/user_profile_screen.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';

/// "My Account" screen matching the exact Figma design
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final currentUser = userAsync.value;
    final activePersona = ref.watch(userPersonaProvider);
    final netState = ref.watch(networkProvider);
    final feedPosts = ref.watch(homeFeedProvider).value ?? [];

    final displayName = currentUser?.name.isNotEmpty == true
        ? currentUser!.name
        : (currentUser?.firstName.isNotEmpty == true
            ? '${currentUser!.firstName} ${currentUser.lastName}'.trim()
            : (activePersona.name.isNotEmpty
                ? activePersona.name
                : (currentUser?.email.split('@').first ?? 'User')));

    final avatarUrl = currentUser?.profileImagePath ?? activePersona.avatarUrl;

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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                              fontSize: 14,
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
                children: [
                  _buildOptionTile(
                    context: context,
                    icon: Icons.receipt_long_outlined,
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
                    icon: Icons.shield_outlined,
                    title: 'Privacy Policy',
                    onTap: () => AccountSheets.showPrivacyPolicy(context),
                  ),
                  _buildOptionTile(
                    context: context,
                    icon: Icons.description_outlined,
                    title: 'Terms of Use',
                    onTap: () => AccountSheets.showTermsConditions(context),
                  ),
                  _buildOptionTile(
                    context: context,
                    icon: Icons.headset_mic_outlined,
                    title: 'Help & Support',
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
                    icon: Icons.delete_outline_rounded,
                    title: 'Delete Account',
                    iconColor: const Color(0xFFFF5252),
                    titleColor: const Color(0xFFFF5252),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Account'),
                          content: const Text(
                              'Are you sure you want to delete your account? This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                ref.read(authProvider.notifier).logout();
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  _buildOptionTile(
                    context: context,
                    icon: Icons.logout_rounded,
                    title: 'Logout',
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
    Color iconColor = const Color(0xFF9E9E9E),
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
          color: Color(0xFFF5F5F5),
          indent: 20,
          endIndent: 20,
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
    if (user != null) {
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

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(initialTalent: talent),
      ),
    );
  }
}
