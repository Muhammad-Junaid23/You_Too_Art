import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:you_too_art/core/constants/supabase_tables.dart';

/// Repository for managing user connections (mutual follows).
class ConnectionRepository {
  final SupabaseClient _client;

  ConnectionRepository(this._client);

  SupabaseQueryBuilder get _db => _client.from(SupabaseTables.connections);

  /// Send a connection request from [userId] to [targetUserId].
  Future<void> sendConnectionRequest({
    required String userId,
    required String targetUserId,
  }) async {
    try {
      await _db.insert({
        'user_id': userId,
        'connected_user_id': targetUserId,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('ConnectionRepository.sendConnectionRequest: $e');
      rethrow;
    }
  }

  /// Accept a pending connection request.
  Future<void> acceptConnection({
    required String userId,
    required String connectedUserId,
  }) async {
    try {
      await _db
          .update({'status': 'accepted'})
          .eq('user_id', connectedUserId)
          .eq('connected_user_id', userId);
    } catch (e) {
      if (kDebugMode) debugPrint('ConnectionRepository.acceptConnection: $e');
      rethrow;
    }
  }

  /// Remove or reject a connection.
  Future<void> removeConnection({
    required String userId,
    required String connectedUserId,
  }) async {
    try {
      // Remove in both directions.
      await _db
          .delete()
          .eq('user_id', userId)
          .eq('connected_user_id', connectedUserId);
      await _db
          .delete()
          .eq('user_id', connectedUserId)
          .eq('connected_user_id', userId);
    } catch (e) {
      if (kDebugMode) debugPrint('ConnectionRepository.removeConnection: $e');
      rethrow;
    }
  }

  /// Real-time stream of connections for a given [uid].
  Stream<List<Map<String, dynamic>>> watchConnections(String uid) {
    return _db
        .stream(primaryKey: ['id'])
        .eq('user_id', uid);
  }
}
