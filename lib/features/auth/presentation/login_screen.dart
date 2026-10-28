import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/app/constants/app_assets.dart';
import 'package:you_too_art/app/constants/app_colors.dart';
import 'package:you_too_art/core/constants/test_accounts.dart';
import 'package:you_too_art/core/widgets/primary_button.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim();

    final ok = await ref.read(authProvider.notifier).sendEmailOtp(email: email);

    if (!mounted) return;

    if (ok) {
      context.push(AppRoutes.verifyOtp, extra: email);
    } else {
      final msg =
          ref.read(authProvider).errorMessage ?? 'Something went wrong.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Logo ───────────────────────────────
                AppAssets.logo.isEmpty
                    ? Container(
                        width: 124,
                        height: 120,
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          color: colors.textHint,
                          size: 40,
                        ),
                      )
                    : Image.asset(
                        AppAssets.logo,
                        width: 124,
                        height: 120,
                        fit: BoxFit.contain,
                      ),

                const SizedBox(height: 24),

                // ─── Title ──────────────────────────────
                Text(
                  'Login',
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),

                const SizedBox(height: 24),

                // ─── Field label ────────────────────────
                Text(
                  'Email Address',
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // ─── Email input ────────────────────────
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Enter your email address';
                    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(v);
                    return ok ? null : 'Enter a valid email address';
                  },
                  onFieldSubmitted: (_) => _onSendOtp(),
                ),

                const SizedBox(height: 32),

                // ─── Send OTP button ────────────────────
                PrimaryButton(
                  text: 'Send OTP',
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _onSendOtp,
                ),

                const SizedBox(height: 24),

                // ─── Quick Test Role Logins ─────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9ECEF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3899F3).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.speed_rounded,
                              size: 18,
                              color: Color(0xFF3899F3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Quick Role Testing (1-Tap Login)',
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap any role to log in instantly, or use email with OTP: 123456',
                        style: text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: TestAccounts.all.map((account) {
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: isLoading
                                  ? null
                                  : () async {
                                      await ref
                                          .read(authProvider.notifier)
                                          .loginAsTestRole(account);
                                      if (context.mounted) {
                                        context.go(AppRoutes.home);
                                      }
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFDEE2E6),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundImage:
                                          NetworkImage(account.avatarUrl),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          account.name,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          account.roleDisplay,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF6C757D),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 10,
                                      color: Color(0xFF3899F3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ─── Terms ──────────────────────────────
                Text.rich(
                  TextSpan(
                    style: text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                    children: [
                      const TextSpan(
                        text: 'by Signing In, you agree with the ',
                      ),
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: TextStyle(
                          color: colors.link,
                          fontWeight: FontWeight.w700,
                        ),
                        // TODO: wrap with TapGestureRecognizer once T&C screen exists
                      ),
                      const TextSpan(text: ' of '),
                      TextSpan(
                        text: 'You2Art',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
