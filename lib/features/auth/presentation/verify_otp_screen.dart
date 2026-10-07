import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/app/constants/app_colors.dart';
import 'package:you_too_art/core/widgets/primary_button.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  static const int _otpLength = 6;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onVerify() async {
    final code = _controller.text.trim();
    if (code.length != _otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code')),
      );
      return;
    }

    final ok = await ref
        .read(authProvider.notifier)
        .verifyEmailOtp(email: widget.email, token: code);
    if (!mounted) return;

    if (ok) {
      context.go(AppRoutes.chooseCategory);
    } else {
      final msg =
          ref.read(authProvider).errorMessage ?? 'Invalid or expired code.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _controller.clear();
      _focusNode.requestFocus();
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back arrow
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 24,
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Verify Your Account',
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Enter OTP',
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _OtpBoxes(
                      controller: _controller,
                      focusNode: _focusNode,
                      length: _otpLength,
                      enabled: !isLoading,
                      onCompleted: _onVerify,
                    ),

                    const SizedBox(height: 16),

                    // Helper text
                    RichText(
                      text: TextSpan(
                        style: text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                        children: [
                          const TextSpan(text: 'Please enter '),
                          TextSpan(
                            text: '6 digits OTP',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(
                            text: ' you received on your registered email ',
                          ),
                          TextSpan(
                            text: widget.email,
                            style: TextStyle(
                              color: colors.link,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom pinned: button + terms
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    text: 'Verify',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _onVerify,
                  ),
                  const SizedBox(height: 12),
                  _TermsLine(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Six visual boxes backed by a single hidden TextField.
class _OtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool enabled;
  final VoidCallback onCompleted;

  const _OtpBoxes({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.enabled,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        // The real, invisible input
        Opacity(
          opacity: 0,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            keyboardType: TextInputType.number,
            maxLength: length,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => (context as Element).markNeedsBuild(),
            onSubmitted: (_) => onCompleted(),
          ),
        ),
        GestureDetector(
          onTap: () => focusNode.requestFocus(),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final code = value.text;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(length, (i) {
                  final filled = i < code.length;
                  return Container(
                    width: 48,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: filled ? colors.primary : colors.border,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      filled ? code[i] : '',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TermsLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Text.rich(
      TextSpan(
        style: text.bodySmall?.copyWith(color: colors.textSecondary),
        children: [
          const TextSpan(text: 'by Signing In, you agree with the '),
          TextSpan(
            text: 'Terms & Conditions',
            style: TextStyle(color: colors.link, fontWeight: FontWeight.w700),
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
    );
  }
}
