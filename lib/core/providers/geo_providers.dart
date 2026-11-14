import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:you_too_art/core/repositories/geo_repository.dart';

/// Provides the [GeoRepository] backed by local bundled geo data.
final geoRepositoryProvider = Provider<GeoRepository>((ref) {
  return GeoRepository();
});

/// All countries.
final countriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(geoRepositoryProvider).fetchCountries();
});

/// Cities for a given country code.
final citiesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      countryCode,
    ) {
      return ref.watch(geoRepositoryProvider).fetchCities(countryCode);
    });
