import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for reference geography data (countries + cities).
/// Read-only from the client.
class GeoRepository {
  final SupabaseClient _client;

  GeoRepository(this._client);

  /// Fetch all countries sorted by name.
  Future<List<Map<String, dynamic>>> fetchCountries() async {
    try {
      final data = await _client
          .from('countries')
          .select('code, name')
          .order('name');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if (kDebugMode) debugPrint('GeoRepository.fetchCountries: $e');
      rethrow;
    }
  }

  /// Fetch cities for a given [countryCode], sorted by name.
  Future<List<Map<String, dynamic>>> fetchCities(String countryCode) async {
    try {
      final data = await _client
          .from('cities')
          .select('id, name')
          .eq('country_code', countryCode)
          .order('name');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if (kDebugMode) debugPrint('GeoRepository.fetchCities: $e');
      rethrow;
    }
  }
}
