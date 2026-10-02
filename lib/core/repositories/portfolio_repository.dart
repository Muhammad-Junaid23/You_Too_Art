import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:you_too_art/core/constants/supabase_tables.dart';

/// Repository for user portfolio item operations.
class PortfolioRepository {
  final SupabaseClient _client;

  PortfolioRepository(this._client);

  SupabaseQueryBuilder get _db =>
      _client.from(SupabaseTables.portfolioItems);

  /// Real-time stream of portfolio items for a given [userId].
  Stream<List<Map<String, dynamic>>> watchPortfolio(String userId) {
    return _db
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  /// Add a new portfolio item.
  Future<Map<String, dynamic>> addPortfolioItem({
    required String userId,
    required String title,
    required String mediaUrl,
    required String mediaType,
  }) async {
    try {
      final data = await _db
          .insert({
            'user_id': userId,
            'title': title,
            'media_url': mediaUrl,
            'media_type': mediaType,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      return data;
    } catch (e) {
      if (kDebugMode) debugPrint('PortfolioRepository.addPortfolioItem: $e');
      rethrow;
    }
  }

  /// Delete a portfolio item by [itemId].
  Future<void> deletePortfolioItem(String itemId) async {
    try {
      await _db.delete().eq('id', itemId);
    } catch (e) {
      if (kDebugMode) debugPrint('PortfolioRepository.deletePortfolioItem: $e');
      rethrow;
    }
  }
}
