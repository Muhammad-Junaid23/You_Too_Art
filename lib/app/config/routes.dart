import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:you_too_art/app/config/router_refresh_notifier.dart';
import 'package:you_too_art/core/widgets/main_wrapper.dart';
import 'package:you_too_art/features/auth/presentation/login_screen.dart';
import 'package:you_too_art/features/auth/presentation/signup_screen.dart';
import 'package:you_too_art/features/auth/presentation/verify_otp_screen.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/account/presentation/account_screen.dart';
import 'package:you_too_art/features/casting/presentation/casting_screen.dart';
import 'package:you_too_art/features/chats/presentation/chats_screen.dart';
import 'package:you_too_art/features/home/presentation/home_screen.dart';
import 'package:you_too_art/features/network/presentation/network_screen.dart';
import 'package:you_too_art/features/splash/presentation/splash_screen.dart';
import 'package:you_too_art/features/talent/presentation/talent_screen.dart';

/// Centralized route configuration for the app.
class AppRoutes {
  AppRoutes._();

  // ─── Route Paths ──────────────────────────────────
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String talent = '/talent';
  static const String network = '/network';
  static const String chats = '/chats';
  static const String casting = '/casting';
  static const String account = '/account';
  static const String verifyOtp = '/verify-otp';

  // ─── Navigator Key ────────────────────────────────
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  // ─── Auth Screens (no redirect for these) ─────────
  static const Set<String> _authPaths = {splash, login, signup, verifyOtp};

  // ─── Build Router ─────────────────────────────────

  static GoRouter buildRouter(Ref ref) {
    final refreshNotifier = RouterRefreshNotifier(ref);

    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: splash,
      refreshListenable: refreshNotifier,
      redirect: (context, state) {
        final auth = ref.read(authProvider);
        final currentPath = state.uri.path;

        // Never redirect away from splash — splash decides where to go.
        if (currentPath == AppRoutes.splash) return null;

        // Not logged in → login (unless already on an auth screen)
        if (!auth.isLoggedIn) {
          if (!_authPaths.contains(currentPath)) return AppRoutes.login;
          return null;
        }

        // Logged in but on an auth screen → home
        if (auth.isLoggedIn && _authPaths.contains(currentPath)) {
          return AppRoutes.home;
        }

        return null;
      },
      routes: [
        // ─── Standalone Routes ────────────────────────
        GoRoute(
          path: splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(path: login, builder: (context, state) => const LoginScreen()),
        GoRoute(
          path: signup,
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: verifyOtp,
          builder: (context, state) {
            final email = state.extra as String? ?? '';
            return VerifyOtpScreen(email: email);
          },
        ),

        // ─── Main Shell with Bottom Navigation ───────
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainWrapper(navigationShell: navigationShell),
          branches: [
            // 0 — Home
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: home,
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            // 1 — Talent
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: talent,
                  builder: (context, state) => const TalentScreen(),
                ),
              ],
            ),
            // 2 — Network
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: network,
                  builder: (context, state) => const NetworkScreen(),
                ),
              ],
            ),
            // 3 — Chats
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: chats,
                  builder: (context, state) => const ChatsScreen(),
                ),
              ],
            ),
            // 4 — Casting
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: casting,
                  builder: (context, state) => const CastingScreen(),
                ),
              ],
            ),
            // 5 — Account
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: account,
                  builder: (context, state) => const AccountScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Riverpod provider that creates and caches the [GoRouter] instance.
/// This ensures `buildRouter` receives a real [Ref], not a [WidgetRef].
final routerProvider = Provider<GoRouter>((ref) {
  return AppRoutes.buildRouter(ref);
});
