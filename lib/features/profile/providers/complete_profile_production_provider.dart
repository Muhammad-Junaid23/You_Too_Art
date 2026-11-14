import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/core/constants/geo_data.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';

/// State for the Complete Profile (Production House) form.
class ProductionProfileState {
  final String companyName;
  final String incorporationNumber;
  final int? establishedYear;
  final String? country;
  final String? city;
  final String address;
  final String bio;
  final String? profileImagePath;
  final bool isSaving;
  final String? errorMessage;

  const ProductionProfileState({
    this.companyName = '',
    this.incorporationNumber = '',
    this.establishedYear,
    this.country,
    this.city,
    this.address = '',
    this.bio = '',
    this.profileImagePath,
    this.isSaving = false,
    this.errorMessage,
  });

  bool get isValid =>
      companyName.trim().isNotEmpty &&
      incorporationNumber.trim().isNotEmpty &&
      establishedYear != null &&
      (country ?? '').isNotEmpty &&
      (city ?? '').isNotEmpty &&
      address.trim().isNotEmpty &&
      bio.trim().isNotEmpty;

  ProductionProfileState copyWith({
    String? companyName,
    String? incorporationNumber,
    int? establishedYear,
    String? country,
    String? city,
    String? address,
    String? bio,
    String? profileImagePath,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProductionProfileState(
      companyName: companyName ?? this.companyName,
      incorporationNumber: incorporationNumber ?? this.incorporationNumber,
      establishedYear: establishedYear ?? this.establishedYear,
      country: country ?? this.country,
      city: city ?? this.city,
      address: address ?? this.address,
      bio: bio ?? this.bio,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ProductionProfileNotifier extends Notifier<ProductionProfileState> {
  @override
  ProductionProfileState build() => const ProductionProfileState();

  void setCompanyName(String v) =>
      state = state.copyWith(companyName: v, clearError: true);
  void setIncorporationNumber(String v) =>
      state = state.copyWith(incorporationNumber: v, clearError: true);
  void setEstablishedYear(int? v) =>
      state = state.copyWith(establishedYear: v, clearError: true);
  void setCountry(String? v) =>
      state = state.copyWith(country: v, clearError: true);
  void setCity(String? v) => state = state.copyWith(city: v, clearError: true);
  void setAddress(String v) =>
      state = state.copyWith(address: v, clearError: true);
  void setBio(String v) => state = state.copyWith(bio: v, clearError: true);
  void setProfileImage(String url) =>
      state = state.copyWith(profileImagePath: url, clearError: true);

  /// Clear the city — used when country changes.
  void clearCity() {
    state = ProductionProfileState(
      companyName: state.companyName,
      incorporationNumber: state.incorporationNumber,
      establishedYear: state.establishedYear,
      country: state.country,
      city: null,
      address: state.address,
      bio: state.bio,
      profileImagePath: state.profileImagePath,
      isSaving: state.isSaving,
      errorMessage: state.errorMessage,
    );
  }

  Future<bool> save() async {
    if (!state.isValid) {
      state = state.copyWith(errorMessage: 'Please fill all required fields.');
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final uid = ref.read(authProvider.notifier).currentUid;
      if (uid == null) throw StateError('Not signed in');

      final countries = getCountries();
      final match = countries.where((c) => c['code'] == state.country).firstOrNull;
      final countryName = match != null ? match['name'] as String : (state.country ?? '');
      final loc = '${state.city}, $countryName';

      await ref
          .read(userRepositoryProvider)
          .updateProfile(
            uid: uid,
            updates: {
              'first_name': state.companyName.trim(),
              'name': state.companyName.trim(),
              'role': 'production_house',
              'incorporation_number': state.incorporationNumber.trim(),
              'established_year': state.establishedYear,
              'address': state.address.trim(),
              'location': loc,
              'bio': state.bio.trim(),
              if (state.profileImagePath != null)
                'profile_image_path': state.profileImagePath,
            },
          );

      // Immediately propagate created production profile into persistent state
      final currentActor = AppPersistenceService.instance.getActorPersona();
      final updatedProd = currentActor.copyWith(
        id: uid,
        name: state.companyName.trim(),
        role: 'Production House',
        isProductionHouse: true,
        location: loc,
        bio: state.bio.trim(),
        avatarUrl: state.profileImagePath ?? currentActor.avatarUrl,
      );
      AppPersistenceService.instance.savePersona(updatedProd);
      AppPersistenceService.instance.setActivePersonaId(uid);

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await AppPersistenceService.instance.syncWithSupabaseUser(user);
      }

      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('ProductionProfileNotifier.save: $e');
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      return false;
    }
  }
}

final productionProfileProvider =
    NotifierProvider<ProductionProfileNotifier, ProductionProfileState>(
      ProductionProfileNotifier.new,
    );
