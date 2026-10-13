import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/repositories/auth_repository.dart';
import 'package:you_too_art/core/repositories/user_repository.dart';
import 'package:you_too_art/core/services/storage_service.dart';
import 'package:you_too_art/core/utils/error_messages.dart';
import 'package:you_too_art/core/models/user_model.dart';

// ─── Foundation Providers ───────────────────────────

/// Override this in main.dart with the actual SharedPreferences instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope.',
  );
});

/// Provides the [StorageService] backed by SharedPreferences.
final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StorageService(prefs);
});

/// Provides the [AuthRepository] backed by Supabase.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});

/// Provides the [UserRepository] backed by Supabase.
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return UserRepository(client);
});

// ─── Auth Streams ───────────────────────────────────

/// Stream of Supabase auth state changes.
final authStateChangesProvider = StreamProvider<supabase.AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});

/// Provider that emits the current user's UID, watching auth state reactively.
final currentUidProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final streamUid = authState.whenData((state) => state.session?.user.id).value;
  if (streamUid != null) return streamUid;
  return ref.watch(supabaseClientProvider).auth.currentUser?.id;
});

/// Stream of whether the current user's email has been verified.
final emailVerifiedProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.emailVerifiedChanges();
});

// ─── Auth State ─────────────────────────────────────

/// Immutable state for the auth layer.
/// Named [AppAuthState] to avoid conflict with Supabase's AuthState.
class AppAuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? errorMessage;
  String? get role => null;

  const AppAuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.errorMessage,
  });

  AppAuthState copyWith({
    bool? isFirstTime,
    bool? isLoggedIn,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AppAuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// ─── Auth Notifier (Riverpod 3.x) ──────────────────

class AuthNotifier extends Notifier<AppAuthState> {
  late final AuthRepository _authRepo;
  late final UserRepository _userRepo;
  String? get currentUid => _authRepo.currentUid;

  @override
  AppAuthState build() {
    _authRepo = ref.watch(authRepositoryProvider);
    _userRepo = ref.watch(userRepositoryProvider);

    return AppAuthState(isLoggedIn: _authRepo.isLoggedIn);
  }

  /// Log in with email and password.
  Future<bool> loginWithCredentials({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _authRepo.login(email: email, password: password);

      // Create the user profile if it doesn't exist yet.
      final user = _authRepo.currentUser;
      if (user != null) {
        await _userRepo.createIfMissing(
          UserModel(
            id: user.id,
            firstName: (user.userMetadata?['name'] as String? ?? '')
                .split(' ')
                .first,
            lastName: (user.userMetadata?['name'] as String? ?? '')
                .split(' ')
                .skip(1)
                .join(' '),
            email: user.email ?? '',
            role: user.userMetadata?['role'] as String? ?? 'actor',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      state = state.copyWith(isLoggedIn: true, isLoading: false);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('AuthNotifier.loginWithCredentials: $e');
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
      return false;
    }
  }

  /// Sign up a new user.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _authRepo.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
      );

      if (response.user != null) {
        await _userRepo.createIfMissing(
          UserModel(
            id: response.user!.id,
            firstName: name.split(' ').first,
            lastName: name.split(' ').skip(1).join(' '),
            email: email,
            role: role,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('AuthNotifier.signUp: $e');
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
      return false;
    }
  }

  /// Sign in with Google (placeholder).
  Future<bool> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _authRepo.signInWithGoogle();
      state = state.copyWith(isLoggedIn: true, isLoading: false);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('AuthNotifier.loginWithGoogle: $e');
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
      return false;
    }
  }

  /// Send an email OTP to [email].
  /// Returns true if Supabase accepted the request.
  Future<bool> sendEmailOtp({required String email}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _authRepo.sendEmailOtp(email: email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('AuthNotifier.sendEmailOtp: $e');
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
      return false;
    }
  }

  // Verifies the OTP, returns the user row, but does NOT set isLoggedIn yet.
  Future<UserModel?> verifyEmailOtpOnly({
    required String email,
    required String token,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _authRepo.verifyEmailOtp(
        email: email,
        token: token,
      );
      if (response.user == null) throw StateError('No user in response');

      final user = await _userRepo.createIfMissing(
        UserModel(
          id: response.user!.id,
          email: response.user!.email ?? email,
          role: 'unset',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      state = state.copyWith(isLoading: false);
      return user;
    } catch (e) {
      if (kDebugMode) debugPrint('AuthNotifier.verifyEmailOtpOnly: $e');
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
      return null;
    }
  }

  // Called AFTER routing is decided.
  void markLoggedIn() {
    state = state.copyWith(isLoggedIn: true);
  }

  /// Log out the current user.
  Future<void> logout() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _authRepo.logout();
      state = state.copyWith(isLoggedIn: false, isLoading: false);
    } catch (e) {
      if (kDebugMode) debugPrint('AuthNotifier.logout: $e');
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
    }
  }

  /// Send a password reset email.
  Future<bool> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _authRepo.sendPasswordReset(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('AuthNotifier.sendPasswordReset: $e');
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
      return false;
    }
  }

  /// Clears any displayed error message.
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// The primary auth provider using Riverpod 3.x Notifier pattern.
final authProvider = NotifierProvider<AuthNotifier, AppAuthState>(
  AuthNotifier.new,
);
