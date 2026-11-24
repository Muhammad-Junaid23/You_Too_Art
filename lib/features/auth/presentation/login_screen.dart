import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/app/constants/app_assets.dart';
import 'package:you_too_art/app/constants/app_colors.dart';
import 'package:you_too_art/core/widgets/primary_button.dart';
import 'package:you_too_art/features/account/presentation/account_sheets.dart';
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
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => AccountSheets.showTermsConditions(context),
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
