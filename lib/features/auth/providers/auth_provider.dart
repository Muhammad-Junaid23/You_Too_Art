import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/repositories/auth_repository.dart';
import 'package:you_too_art/core/repositories/user_repository.dart';
import 'package:you_too_art/core/services/storage_service.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/core/utils/error_messages.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/constants/test_accounts.dart';
import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/providers/shared_preferences_provider.dart';

// ─── Foundation Providers ───────────────────────────

export 'package:you_too_art/core/providers/shared_preferences_provider.dart';

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

/// Provider that emits the current user's UID, watching auth state reactively,
/// while respecting active developer testing personas when selected.
final currentUidProvider = Provider<String?>((ref) {
  final activePersona = ref.watch(userPersonaProvider);
  if (activePersona.id != UserPersonaNotifier.actorDefaultId) {
    return activePersona.id;
  }

  final authState = ref.watch(authStateChangesProvider);
  final streamUid = authState.whenData((state) => state.session?.user.id).value;
  if (streamUid != null) return streamUid;
  return ref.watch(supabaseClientProvider).auth.currentUser?.id ??
      activePersona.id;
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

    final prefs = ref.watch(sharedPreferencesProvider);
    final isTestLoggedIn = prefs.getBool('is_test_role_logged_in') ?? false;

    return AppAuthState(isLoggedIn: _authRepo.isLoggedIn || isTestLoggedIn);
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
  /// Returns true if Supabase accepted the request (or instantly for test accounts).
  Future<bool> sendEmailOtp({required String email}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    // Bypass external network email dispatch for pre-configured test roles
    if (TestAccounts.isTestEmail(email)) {
      state = state.copyWith(isLoading: false);
      return true;
    }

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

    // Handle test accounts instantly with master OTP (123456)
    if (TestAccounts.isTestEmail(email)) {
      if (token == TestAccounts.masterTestOtp || token == '000000' || token.length == 6) {
        final testAcc = TestAccounts.findByEmail(email)!;
        final persona = testAcc.toPersona();
        AppPersistenceService.instance.savePersona(persona);
        AppPersistenceService.instance.setActivePersonaId(persona.id);
        await ref.read(userPersonaProvider.notifier).switchPersona(persona);

        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.setBool('is_test_role_logged_in', true);

        final userModel = testAcc.toUserModel();
        state = state.copyWith(isLoading: false);
        return userModel;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid test OTP code. Use ${TestAccounts.masterTestOtp}',
        );
        return null;
      }
    }

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

      // Bind persona immediately to the authenticated user (no fallback to dummy mock personas)
      final emailPrefix = email.contains('@') ? email.split('@').first : 'User';
      final persona = UserPersona(
        id: response.user!.id,
        name: user.name.isNotEmpty
            ? user.name
            : (user.firstName.isNotEmpty
                ? '${user.firstName} ${user.lastName}'.trim()
                : emailPrefix),
        email: email,
        role: user.role != 'unset' ? user.role : '',
        avatarUrl: user.profileImagePath ?? '',
      );
      AppPersistenceService.instance.savePersona(persona);
      AppPersistenceService.instance.setActivePersonaId(persona.id);
      await ref.read(userPersonaProvider.notifier).switchPersona(persona);

      state = state.copyWith(isLoading: false);
      return user;
    } catch (e) {
      if (kDebugMode) debugPrint('AuthNotifier.verifyEmailOtpOnly: $e');
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
      return null;
    }
  }

  /// 1-Tap Instant Login for role testing
  Future<void> loginAsTestRole(TestAccount account) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final persona = account.toPersona();
    AppPersistenceService.instance.savePersona(persona);
    AppPersistenceService.instance.setActivePersonaId(persona.id);
    await ref.read(userPersonaProvider.notifier).switchPersona(persona);

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('is_test_role_logged_in', true);

    state = state.copyWith(isLoading: false, isLoggedIn: true);
  }

  // Called AFTER routing is decided.
  void markLoggedIn() {
    final activePersona = ref.read(userPersonaProvider);
    if (TestAccounts.isTestId(activePersona.id)) {
      final prefs = ref.read(sharedPreferencesProvider);
      prefs.setBool('is_test_role_logged_in', true);
    }
    state = state.copyWith(isLoggedIn: true);
  }

  /// Log out the current user.
  Future<void> logout() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('is_test_role_logged_in', false);
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
