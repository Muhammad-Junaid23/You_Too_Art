import 'package:you_too_art/core/constants/geo_data.dart';

/// Repository for reference geography data (countries + cities).
/// Uses a local bundled dataset — no network call required.
class GeoRepository {
  GeoRepository();

  /// All countries sorted by name.
  Future<List<Map<String, dynamic>>> fetchCountries() async {
    return getCountries();
  }

  /// Cities for a given [countryCode], sorted by name.
  Future<List<Map<String, dynamic>>> fetchCities(String countryCode) async {
    return getCities(countryCode);
  }
}
