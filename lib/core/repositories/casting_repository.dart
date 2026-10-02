import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:you_too_art/core/constants/supabase_tables.dart';

/// Repository for casting call and application operations.
class CastingRepository {
  final SupabaseClient _client;

  CastingRepository(this._client);

  SupabaseQueryBuilder get _calls =>
      _client.from(SupabaseTables.castingCalls);
  SupabaseQueryBuilder get _applications =>
      _client.from(SupabaseTables.castingApplications);

  /// Real-time stream of casting calls.
  /// Optionally filter by [roleType] or other criteria.
  Stream<List<Map<String, dynamic>>> watchCastingCalls({
    String? roleType,
  }) {
    var query = _calls.stream(primaryKey: ['id']);
    if (roleType != null) {
      query = query.eq('role_type', roleType);
    }
    return query.order('created_at', ascending: false);
  }

  /// Create a new casting call.
  Future<Map<String, dynamic>> createCastingCall({
    required String postedById,
    required String title,
    required String description,
    required String roleType,
    String? location,
    DateTime? deadline,
  }) async {
    try {
      final data = await _calls
          .insert({
            'posted_by_id': postedById,
            'title': title,
            'description': description,
            'role_type': roleType,
            'location': location,
            'deadline': deadline?.toUtc().toIso8601String(),
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      return data;
    } catch (e) {
      if (kDebugMode) debugPrint('CastingRepository.createCastingCall: $e');
      rethrow;
    }
  }

  /// Apply to a casting call.
  Future<Map<String, dynamic>> applyToCastingCall({
    required String castingCallId,
    required String applicantId,
  }) async {
    try {
      final data = await _applications
          .insert({
            'casting_call_id': castingCallId,
            'applicant_id': applicantId,
            'status': 'pending',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      return data;
    } catch (e) {
      if (kDebugMode) debugPrint('CastingRepository.applyToCastingCall: $e');
      rethrow;
    }
  }

  /// Real-time stream of applications submitted by a given [userId].
  Stream<List<Map<String, dynamic>>> watchApplications(String userId) {
    return _applications
        .stream(primaryKey: ['id'])
        .eq('applicant_id', userId)
        .order('created_at', ascending: false);
  }
}
