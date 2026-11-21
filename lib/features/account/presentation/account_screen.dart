import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/core/utils/role_formatter.dart';
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

    final displayRoles =
        RoleFormatter.format(currentUser?.role ?? activePersona.role);
    final isVerified = currentUser?.isVerified == true;

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
                              if (isVerified)
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
                                Text(
                                  isVerified
                                      ? 'Verified Profile'
                                      : (displayRoles.isNotEmpty
                                          ? displayRoles
                                          : 'Creative Artist'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isVerified
                                        ? const Color(0xFF3899F3)
                                        : const Color(0xFF6B7280),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                    onTap: () {
                      final clientUser = Supabase.instance.client.auth.currentUser;
                      final isEmailConfirmed = clientUser?.emailConfirmedAt != null;
                      AccountSheets.showVerifyAccount(
                        context,
                        email: currentUser?.email.isNotEmpty == true
                            ? currentUser!.email
                            : (clientUser?.email ?? activePersona.email),
                        isEmailVerified: isEmailConfirmed,
                        isArtistVerified: isVerified,
                        onSendVerificationEmail: () async {
                          final ok = await ref
                              .read(authProvider.notifier)
                              .sendVerificationEmail();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Verification email sent! Check your inbox and click Confirm Email.'
                                      : 'Failed to send verification email. Please try again.',
                                ),
                                backgroundColor: ok
                                    ? const Color(0xFF3899F3)
                                    : const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                          return ok;
                        },
                        onCheckVerification: () async {
                          final confirmed = await ref
                              .read(authProvider.notifier)
                              .checkEmailVerification();
                          ref.invalidate(currentUserProfileProvider);
                          if (context.mounted) {
                            if (confirmed) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Congratulations! Your email is confirmed and your verified badge is now active!',
                                  ),
                                  backgroundColor: Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Email not confirmed yet. Please click the link in your email and tap Check Status again.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                          return confirmed;
                        },
                        onToggleVerification: () async {
                          final newStatus = !isVerified;
                          await ref
                              .read(authProvider.notifier)
                              .setVerificationStatus(newStatus);
                          ref.invalidate(currentUserProfileProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  newStatus
                                      ? 'Congratulations! Your profile is now verified with the official badge.'
                                      : 'Verification badge removed.',
                                ),
                                backgroundColor: newStatus
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF1E293B),
                              ),
                            );
                          }
                        },
                      );
                    },
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
                  _buildOptionTile(
                    context: context,
                    icon: Icons.delete_outline_rounded,
                    title: 'Delete Account',
                    iconColor: const Color(0xFFDC2626),
                    titleColor: const Color(0xFFDC2626),
                    onTap: () => AccountSheets.showDeleteAccountModal(
                      context,
                      onDelete: () async {
                        final success = await ref
                            .read(authProvider.notifier)
                            .deleteAccount();
                        if (context.mounted) {
                          if (success) {
                            context.go(AppRoutes.login);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Your account has been deleted.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to delete account. Please try again.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
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
