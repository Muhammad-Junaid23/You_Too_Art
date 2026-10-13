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
import 'package:you_too_art/features/auth/presentation/choose_category_screen.dart';
import 'package:you_too_art/features/profile/presentation/complete_profile_individual_screen.dart';
import 'package:you_too_art/features/profile/presentation/complete_profile_production_screen.dart';
import 'package:you_too_art/features/home/presentation/create_post_screen.dart';
import 'package:you_too_art/features/home/presentation/search_screen.dart';

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
  static const String chooseCategory = '/choose-category';
  static const String completeProfileIndividual =
      '/complete-profile/individual';
  static const String completeProfileProduction =
      '/complete-profile/production';
  static const String createPost = '/create-post';
  static const String search = '/search';

  // ─── Navigator Key ────────────────────────────────
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  // Screens to bounce a logged-in user away from (true auth entry screens)

  static const Set<String> _publicOnly = {splash, login, signup};

  static const Set<String> _noAuthRequired = {
    verifyOtp,
    chooseCategory,
    completeProfileIndividual,
    completeProfileProduction,
  };

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

        // Splash handles its own navigation.
        if (currentPath == AppRoutes.splash) return null;

        // Public-only screens: bounce logged-in users to home.
        if (_publicOnly.contains(currentPath)) {
          return auth.isLoggedIn ? AppRoutes.home : null;
        }

        // Auth-flow screens: always allowed (logged in or not).
        if (_noAuthRequired.contains(currentPath)) return null;

        // Everything else: requires login.
        if (!auth.isLoggedIn) return AppRoutes.login;

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
        GoRoute(
          path: chooseCategory,
          builder: (context, state) => const ChooseCategoryScreen(),
        ),
        GoRoute(
          path: completeProfileIndividual,
          builder: (context, state) => const CompleteProfileIndividualScreen(),
        ),
        GoRoute(
          path: completeProfileProduction,
          builder: (context, state) => const CompleteProfileProductionScreen(),
        ),
        GoRoute(
          path: createPost,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final initialWithPhoto = extra?['initialWithPhoto'] as bool? ?? false;
            return CreatePostScreen(initialWithPhoto: initialWithPhoto);
          },
        ),
        GoRoute(
          path: search,
          builder: (context, state) => const SearchScreen(),
        ),

        // ─── Main Shell with Bottom Navigation ───────
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainWrapper(navigationShell: navigationShell),
          branches: [
            // 0 — Talent
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: talent,
                  builder: (context, state) => const TalentScreen(),
                ),
              ],
            ),
            // 1 — Network
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: network,
                  builder: (context, state) => const NetworkScreen(),
                ),
              ],
            ),
            // 2 — Chats
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: chats,
                  builder: (context, state) => const ChatsScreen(),
                ),
              ],
            ),
            // 3 — Home
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: home,
                  builder: (context, state) => const HomeScreen(),
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
