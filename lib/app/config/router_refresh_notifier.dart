import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:you_too_art/features/auth/providers/auth_provider.dart';

/// A [ChangeNotifier] that listens to [authProvider] changes and notifies
/// [GoRouter] to re-evaluate its redirect logic.
///
/// This bridges Riverpod state to GoRouter's `refreshListenable`.
class RouterRefreshNotifier extends ChangeNotifier {
  late final ProviderSubscription<AppAuthState> _subscription;

  RouterRefreshNotifier(Ref ref) {
    bool? previousIsLoggedIn;
    bool? previousIsFirstTime;

    _subscription = ref.listen<AppAuthState>(authProvider, (previous, next) {
      // Only notify when navigation-relevant state actually changes.
      final loggedInChanged = previousIsLoggedIn != next.isLoggedIn;
      final firstTimeChanged = previousIsFirstTime != next.isFirstTime;

      if (loggedInChanged || firstTimeChanged) {
        previousIsLoggedIn = next.isLoggedIn;
        previousIsFirstTime = next.isFirstTime;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
