import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/app/constants/app_assets.dart';
import 'package:you_too_art/app/constants/app_colors.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';

/// Splash screen. Shows the logo, waits for auth state to resolve,
/// then routes: first-time → onboarding, logged-in → home, else → login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideNext();
  }

  Future<void> _decideNext() async {
    // Minimum display time so the logo doesn't flash.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final auth = ref.read(authProvider);
    context.go(auth.isLoggedIn ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo. If AppAssets.logo is empty, fall back to a placeholder box.
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
          ],
        ),
      ),
    );
  }
}
