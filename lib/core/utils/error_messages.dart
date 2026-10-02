import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts raw exceptions into user-friendly error messages.
String friendlyError(Object error) {
  // ─── Supabase Auth ────────────────────────────────
  if (error is AuthException) {
    final code = error.statusCode;
    final message = error.message.toLowerCase();

    // Check for common auth error codes / messages
    if (message.contains('invalid_credentials') ||
        message.contains('invalid login credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (message.contains('email_not_confirmed') ||
        message.contains('email not confirmed')) {
      return 'Please verify your email before logging in.';
    }
    if (message.contains('user_already_exists') ||
        message.contains('user already registered')) {
      return 'An account with this email already exists.';
    }
    if (message.contains('weak_password') ||
        message.contains('password should be')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (message.contains('over_email_send_rate_limit') ||
        message.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }

    // Fallback by status code
    if (code == '400') return 'Invalid request. Please check your input.';
    if (code == '401') return 'Session expired. Please log in again.';
    if (code == '422') return 'Invalid data provided.';
    if (code == '429') return 'Too many requests. Try again later.';

    return error.message;
  }

  // ─── Supabase Postgrest ───────────────────────────
  if (error is PostgrestException) {
    final code = error.code;
    if (code == '23505') return 'This record already exists.';
    if (code == '23503') return 'Referenced record not found.';
    if (code == '42501') return 'You don\'t have permission for this action.';
    return error.message;
  }

  // ─── Supabase Storage ─────────────────────────────
  if (error is StorageException) {
    return 'File upload failed: ${error.message}';
  }

  // ─── Network ──────────────────────────────────────
  if (error is http.ClientException) {
    return 'Network error. Please try again.';
  }

  // ─── General ──────────────────────────────────────
  if (error is FormatException) {
    return 'Unexpected response format.';
  }
  if (error is TimeoutException) {
    return 'Request timed out. Please try again.';
  }

  return error.toString();
}
