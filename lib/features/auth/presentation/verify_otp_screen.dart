import 'dart:async';
import 'package:flutter/foundation.dart';
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

  int _resendCountdown = 30;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _onResend() async {
    if (_resendCountdown > 0) return;
    _startTimer();
    _controller.clear();
    final ok = await ref
        .read(authProvider.notifier)
        .sendEmailOtp(email: widget.email);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification code resent to ${widget.email}'),
          backgroundColor: const Color(0xFF3899F3),
        ),
      );
    } else {
      final err =
          ref.read(authProvider).errorMessage ?? 'Failed to resend code';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onVerify() async {
    if (_isVerifying) return;
    final code = _controller.text.trim();
    if (code.length != _otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    // 1. Verify — no state flip yet.
    final user = await ref
        .read(authProvider.notifier)
        .verifyEmailOtpOnly(email: widget.email, token: code);
    if (!mounted) return;

    if (user == null) {
      final msg =
          ref.read(authProvider).errorMessage ?? 'Invalid or expired code.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _controller.clear();
      setState(() => _isVerifying = false);
      return;
    }

    setState(() => _isVerifying = false);

    // 2. Decide route based on profile state.
    final String next;
    if (user.role == 'unset' || user.role.isEmpty) {
      next = AppRoutes.chooseCategory;
    } else if (user.firstName.isEmpty && user.name.isEmpty) {
      next = user.role == 'production_house'
          ? AppRoutes.completeProfileProduction
          : AppRoutes.completeProfileIndividual;
    } else {
      next = AppRoutes.home;
    }

    if (kDebugMode) {
      debugPrint(
        'VerifyOtp: role=${user.role}, firstName=${user.firstName}, name=${user.name} -> routing to $next',
      );
    }

    // 3. Flip state and navigate in the same tick.
    ref.read(authProvider.notifier).markLoggedIn();
    context.go(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isLoading = ref.watch(authProvider).isLoading;

    final isNarrow = MediaQuery.sizeOf(context).width < 340;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 14 : 20,
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
                      length: _otpLength,
                      isVerifying: _isVerifying,
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

                    const SizedBox(height: 28),

                    // ─── Resend Code Section ────────────────
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Didn't receive code?",
                          style: text.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (_resendCountdown > 0)
                          Text(
                            'Resend in ${_resendCountdown}s',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: isLoading ? null : _onResend,
                            child: const Text(
                              'Resend Code',
                              style: TextStyle(
                                color: Color(0xFF3899F3),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom pinned: button + terms
            Padding(
              padding: EdgeInsets.fromLTRB(isNarrow ? 14 : 20, 0, isNarrow ? 14 : 20, 16),
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

/// Six individual visual input boxes with full keyboard typing, backspace, and paste support.
class _OtpBoxes extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  final bool isVerifying;
  final VoidCallback onCompleted;

  const _OtpBoxes({
    required this.controller,
    required this.length,
    this.isVerifying = false,
    required this.onCompleted,
  });

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  late final List<TextEditingController> _boxControllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _boxControllers = List.generate(widget.length, (i) {
      final char = i < widget.controller.text.length
          ? widget.controller.text[i]
          : '';
      return TextEditingController(text: char);
    });

    _focusNodes = List.generate(widget.length, (i) {
      final fn = FocusNode();
      fn.onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace) {
          if (_boxControllers[i].text.isEmpty && i > 0) {
            _boxControllers[i - 1].clear();
            _focusNodes[i - 1].requestFocus();
            _syncToParent();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      };
      return fn;
    });

    widget.controller.addListener(_onParentControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  void _onParentControllerChanged() {
    final currentFull = _boxControllers.map((c) => c.text).join();
    if (widget.controller.text != currentFull) {
      final text = widget.controller.text;
      for (var i = 0; i < widget.length; i++) {
        final char = i < text.length ? text[i] : '';
        if (_boxControllers[i].text != char) {
          _boxControllers[i].text = char;
        }
      }
      if (text.isEmpty && mounted && _focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    }
  }

  void _syncToParent() {
    final code = _boxControllers.map((c) => c.text).join();
    if (widget.controller.text != code) {
      widget.controller.text = code;
    }
    if (code.length == widget.length) {
      widget.onCompleted();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onParentControllerChanged);
    for (final c in _boxControllers) {
      c.dispose();
    }
    for (final fn in _focusNodes) {
      fn.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isNarrow = MediaQuery.sizeOf(context).width < 340;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (i) {
        return Expanded(
          child: Container(
            height: isNarrow ? 46 : 52,
            margin: EdgeInsets.symmetric(horizontal: isNarrow ? 1.5 : 3),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _boxControllers[i],
              builder: (context, value, _) {
                final isFilled = value.text.isNotEmpty;
                return ListenableBuilder(
                  listenable: _focusNodes[i],
                  builder: (context, _) {
                    final isFocused = _focusNodes[i].hasFocus;
                    return TextField(
                      controller: _boxControllers[i],
                      focusNode: _focusNodes[i],
                      readOnly: widget.isVerifying,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(widget.length),
                      ],
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        fontSize: 18,
                      ),
                      cursorColor: colors.primary,
                      enableInteractiveSelection: true,
                      decoration: InputDecoration(
                        counterText: '',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: isNarrow ? 10 : 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isFocused
                                ? colors.primary
                                : (isFilled ? colors.primary : colors.border),
                            width: isFocused ? 1.5 : 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isFocused
                                ? colors.primary
                                : (isFilled ? colors.primary : colors.border),
                            width: isFocused ? 1.5 : 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: colors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onTap: () {
                        _boxControllers[i].selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _boxControllers[i].text.length,
                        );
                      },
                      onChanged: (val) {
                        final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.length > 1) {
                          // Pasted multiple digits into this box
                          for (var k = 0; k < widget.length; k++) {
                            final char = k < digits.length ? digits[k] : '';
                            _boxControllers[k].text = char;
                          }
                          final nextFocus = digits.length < widget.length
                              ? digits.length
                              : widget.length - 1;
                          _focusNodes[nextFocus].requestFocus();
                          _syncToParent();
                          return;
                        }

                        if (digits.isNotEmpty) {
                          _boxControllers[i].text = digits;
                          _syncToParent();
                          if (i < widget.length - 1) {
                            _focusNodes[i + 1].requestFocus();
                          }
                        } else {
                          _boxControllers[i].clear();
                          _syncToParent();
                        }
                      },
                      onSubmitted: (_) {
                        _syncToParent();
                        if (i < widget.length - 1) {
                          _focusNodes[i + 1].requestFocus();
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      }),
    );
  }
}

class _TermsLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Text.rich(
      textAlign: TextAlign.center,
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
