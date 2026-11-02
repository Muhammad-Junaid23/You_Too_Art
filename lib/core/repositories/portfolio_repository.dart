import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/core/constants/test_accounts.dart';

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
    if (_client.auth.currentUser == null || TestAccounts.isTestId(userId)) {
      return {
        'id': 'local-portfolio-${DateTime.now().millisecondsSinceEpoch}',
        'user_id': userId,
        'title': title,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
    }
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
      return {
        'id': 'local-portfolio-${DateTime.now().millisecondsSinceEpoch}',
        'user_id': userId,
        'title': title,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
    }
  }

  /// Update an existing portfolio item
  Future<void> updatePortfolioItem({
    required String itemId,
    required String title,
    required String mediaUrl,
  }) async {
    if (_client.auth.currentUser == null || itemId.startsWith('local-')) return;
    try {
      if (!itemId.startsWith('port_') && itemId.length >= 30) {
        await _db.update({
          'title': title,
          'media_url': mediaUrl,
        }).eq('id', itemId);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('PortfolioRepository.updatePortfolioItem: $e');
    }
  }

  /// Delete a portfolio item by [itemId].
  Future<void> deletePortfolioItem(
    String itemId, {
    String? userId,
    String? title,
    String? mediaUrl,
  }) async {
    if (_client.auth.currentUser == null) {
      return;
    }
    try {
      if (!itemId.startsWith('local-') &&
          !itemId.startsWith('port_') &&
          itemId.length >= 30) {
        await _db.delete().eq('id', itemId);
      } else if (userId != null && (title != null || mediaUrl != null)) {
        var query = _db.delete().eq('user_id', userId);
        if (title != null && title.isNotEmpty) {
          query = query.eq('title', title);
        }
        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          query = query.eq('media_url', mediaUrl);
        }
        await query;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('PortfolioRepository.deletePortfolioItem: $e');
    }
  }
}
