import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository wrapping Supabase Auth operations.
///
/// All authentication calls go through this class.
/// No UI code or BuildContext should be used here.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  GoTrueClient get _auth => _client.auth;

  // ─── Streams ──────────────────────────────────────

  /// Stream of auth state changes (sign in, sign out, token refresh).
  Stream<AuthState> authStateChanges() => _auth.onAuthStateChange;

  // ─── Getters ──────────────────────────────────────

  /// The currently authenticated user, or null.
  User? get currentUser => _auth.currentUser;

  /// The current user's UID, or null.
  String? get currentUid => _auth.currentUser?.id;

  /// Whether a user is currently authenticated.
  bool get isLoggedIn => _auth.currentUser != null;

  /// Whether the current user's email has been verified.
  bool get isEmailVerified =>
      _auth.currentUser?.emailConfirmedAt != null;

  // ─── Auth Methods ─────────────────────────────────

  /// Sign up with email and password.
  /// [name] and [role] are stored in `user_metadata` for later profile creation.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      return await _auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role,
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('AuthRepository.signUp: $e');
      rethrow;
    }
  }

  /// Sign in with email and password.
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('AuthRepository.login: $e');
      rethrow;
    }
  }

  /// Sign out the current user.
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('AuthRepository.logout: $e');
      rethrow;
    }
  }

  /// Send a password reset email.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
    } catch (e) {
      if (kDebugMode) debugPrint('AuthRepository.sendPasswordReset: $e');
      rethrow;
    }
  }

  /// Resend the verification email to the current user.
  Future<void> resendVerificationEmail() async {
    try {
      final email = _auth.currentUser?.email;
      if (email == null) throw Exception('No user email found.');
      await _auth.resend(type: OtpType.signup, email: email);
    } catch (e) {
      if (kDebugMode) debugPrint('AuthRepository.resendVerificationEmail: $e');
      rethrow;
    }
  }

  /// Stream that emits `true` when the user's email has been verified.
  Stream<bool> emailVerifiedChanges() {
    return _auth.onAuthStateChange.map((state) {
      return state.session?.user.emailConfirmedAt != null;
    });
  }

  /// Sign in with Google (OAuth).
  /// Placeholder — implement with Supabase OAuth when ready.
  Future<void> signInWithGoogle() async {
    throw UnimplementedError('Google Sign-In not yet configured.');
  }
}
