import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/core/constants/test_accounts.dart';
import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';

/// Repository for user profile CRUD operations.
///
/// All user-related Supabase calls go through this class.
class UserRepository {
  final SupabaseClient _client;

  UserRepository(this._client);

  SupabaseQueryBuilder get _db => _client.from(SupabaseTables.users);

  /// Fetch a user profile by [uid].
  Future<UserModel?> getById(String uid) async {
    if (TestAccounts.isTestId(uid)) {
      return TestAccounts.findById(uid)?.toUserModel();
    }
    if (AppPersistenceService.instance.hasPersona(uid)) {
      final p = AppPersistenceService.instance.getPersona(uid);
      return UserModel(
        id: p.id,
        firstName: p.name.split(' ').first,
        lastName: p.name.split(' ').skip(1).join(' '),
        email: p.email,
        role: p.role,
        bio: p.bio,
        location: p.location,
        profileImagePath: p.avatarUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    try {
      final data = await _db.select().eq('id', uid).maybeSingle();
      if (data == null) return null;
      return UserModel.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('UserRepository.getById: $e');
      return null;
    }
  }

  /// Real-time stream of a user profile by [uid].
  Stream<UserModel?> watch(String uid) {
    if (TestAccounts.isTestId(uid)) {
      final model = TestAccounts.findById(uid)?.toUserModel();
      return Stream.value(model);
    }
    if (AppPersistenceService.instance.hasPersona(uid)) {
      final p = AppPersistenceService.instance.getPersona(uid);
      return Stream.value(UserModel(
        id: p.id,
        firstName: p.name.split(' ').first,
        lastName: p.name.split(' ').skip(1).join(' '),
        email: p.email,
        role: p.role,
        bio: p.bio,
        location: p.location,
        profileImagePath: p.avatarUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    return _db.stream(primaryKey: ['id']).eq('id', uid).map((rows) {
      if (rows.isEmpty) return null;
      return UserModel.fromJson(rows.first);
    });
  }

  /// Create a user profile if one does not already exist.
  Future<UserModel> createIfMissing(UserModel user) async {
    // If it's a synthetic test account or no Supabase auth session exists,
    // operate completely locally without making an unauthenticated network call.
    if (TestAccounts.isTestId(user.id) || _client.auth.currentUser == null) {
      return user;
    }

    try {
      final existing = await getById(user.id);
      if (existing != null) return existing;

      final json = user.toJson();
      // Let Postgres fill in updated_at if not provided
      if (json['updated_at'] == null) json.remove('updated_at');

      final data = await _db.insert(json).select().single();
      return UserModel.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('UserRepository.createIfMissing: $e');
      return user;
    }
  }

  /// Update a user's profile fields.
  Future<UserModel> updateProfile({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    if (TestAccounts.isTestId(uid) || _client.auth.currentUser == null) {
      if (AppPersistenceService.instance.hasPersona(uid)) {
        final current = AppPersistenceService.instance.getPersona(uid);
        final updated = current.copyWith(
          name: updates['name'] as String? ??
              (updates['first_name'] != null
                  ? '${updates['first_name']} ${updates['last_name'] ?? ''}'
                      .trim()
                  : null),
          bio: updates['bio'] as String?,
          location: updates['location'] as String?,
          avatarUrl: updates['profile_image_path'] as String?,
        );
        AppPersistenceService.instance.savePersona(updated);
        return UserModel(
          id: updated.id,
          firstName: updated.name.split(' ').first,
          lastName: updated.name.split(' ').skip(1).join(' '),
          email: updated.email,
          role: updated.role,
          bio: updated.bio,
          location: updated.location,
          profileImagePath: updated.avatarUrl,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      final test = TestAccounts.findById(uid);
      if (test != null) return test.toUserModel();
    }

    try {
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
      final data = await _db.update(updates).eq('id', uid).select().single();
      return UserModel.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('UserRepository.updateProfile: $e');
      rethrow;
    }
  }

  /// Update the user's FCM token for push notifications.
  /// No-op for now — implement when push notifications are set up.
  Future<void> updateFcmToken({
    required String uid,
    required String token,
  }) async {
    // TODO: Add fcmToken column to users table and implement.
    if (kDebugMode) debugPrint('UserRepository.updateFcmToken: no-op');
  }
}
