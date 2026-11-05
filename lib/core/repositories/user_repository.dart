import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/core/models/user_model.dart';

/// Repository for user profile CRUD operations.
///
/// All user-related Supabase calls go through this class.
class UserRepository {
  final SupabaseClient _client;

  UserRepository(this._client);

  SupabaseQueryBuilder get _db => _client.from(SupabaseTables.users);

  static bool isValidUuid(String id) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  /// Fetch a user profile by [uid].
  Future<UserModel?> getById(String uid) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty || !isValidUuid(cleanUid)) return null;
    try {
      final data = await _db.select().eq('id', cleanUid).maybeSingle();
      if (data == null) return null;
      return UserModel.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('UserRepository.getById: $e');
      return null;
    }
  }

  /// Real-time stream of a user profile by [uid].
  Stream<UserModel?> watch(String uid) {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty || !isValidUuid(cleanUid)) {
      return Stream.value(null);
    }
    return _db.stream(primaryKey: ['id']).eq('id', cleanUid).map((rows) {
      if (rows.isEmpty) return null;
      return UserModel.fromJson(rows.first);
    });
  }

  /// Create a user profile if one does not already exist.
  Future<UserModel> createIfMissing(UserModel user) async {
    if (_client.auth.currentUser == null) {
      return user;
    }

    try {
      final existing = await getById(user.id);
      if (existing != null) return existing;

      final json = user.toJson();
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
  Future<void> updateFcmToken({
    required String uid,
    required String token,
  }) async {
    if (kDebugMode) debugPrint('UserRepository.updateFcmToken: no-op');
  }

  /// Fetch all registered users from Supabase.
  Future<List<UserModel>> getAllUsers() async {
    try {
      final data = await _db.select().order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((row) => UserModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('UserRepository.getAllUsers: $e');
      return [];
    }
  }
}
