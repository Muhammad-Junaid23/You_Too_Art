import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/core/constants/geo_data.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/profile/providers/user_portfolio_provider.dart';

/// State for the Complete Profile (Individual) form.
class CompleteProfileState {
  final String firstName;
  final String lastName;
  final String? country;
  final String? city;
  final String bio;
  final String? profileImagePath; // Cloudinary URL after upload
  final bool isSaving;
  final String? errorMessage;

  const CompleteProfileState({
    this.firstName = '',
    this.lastName = '',
    this.country,
    this.city,
    this.bio = '',
    this.profileImagePath,
    this.isSaving = false,
    this.errorMessage,
  });

  bool get isValid =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      (country ?? '').isNotEmpty &&
      (city ?? '').isNotEmpty &&
      bio.trim().isNotEmpty;

  CompleteProfileState copyWith({
    String? firstName,
    String? lastName,
    String? country,
    String? city,
    String? bio,
    String? profileImagePath,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CompleteProfileState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      country: country ?? this.country,
      city: city ?? this.city,
      bio: bio ?? this.bio,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CompleteProfileNotifier extends Notifier<CompleteProfileState> {
  @override
  CompleteProfileState build() => const CompleteProfileState();

  void setFirstName(String v) =>
      state = state.copyWith(firstName: v, clearError: true);
  void setLastName(String v) =>
      state = state.copyWith(lastName: v, clearError: true);
  void setCountry(String? v) =>
      state = state.copyWith(country: v, clearError: true);
  void setCity(String? v) => state = state.copyWith(city: v, clearError: true);
  void setBio(String v) => state = state.copyWith(bio: v, clearError: true);
  void setProfileImage(String url) =>
      state = state.copyWith(profileImagePath: url, clearError: true);

  void clearCity() {
    state = CompleteProfileState(
      firstName: state.firstName,
      lastName: state.lastName,
      country: state.country,
      city: null, // explicitly null
      bio: state.bio,
      profileImagePath: state.profileImagePath,
      isSaving: state.isSaving,
      errorMessage: state.errorMessage,
    );
  }

  /// Persist the form to the `users` table.
  Future<bool> save() async {
    if (!state.isValid) {
      state = state.copyWith(errorMessage: 'Please fill all required fields.');
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final uid = ref.read(authProvider.notifier).currentUid;
      if (uid == null) throw StateError('Not signed in');

      final fullName =
          '${state.firstName.trim()} ${state.lastName.trim()}'.trim();
      final countries = getCountries();
      final match = countries.where((c) => c['code'] == state.country).firstOrNull;
      final countryName = match != null ? match['name'] as String : (state.country ?? '');
      final locationStr = '${state.city}, $countryName';

      String? existingRole = ref.read(authProvider).role;
      if (existingRole == null || existingRole.isEmpty || existingRole == 'unset') {
        final existingUser = await ref.read(userRepositoryProvider).getById(uid);
        if (existingUser != null && existingUser.role.isNotEmpty && existingUser.role != 'unset') {
          existingRole = existingUser.role;
        }
      }
      final roleStr = (existingRole != null && existingRole.isNotEmpty && existingRole != 'unset')
          ? existingRole
          : 'Director';

      await ref
          .read(userRepositoryProvider)
          .updateProfile(
            uid: uid,
            updates: {
              'first_name': state.firstName.trim(),
              'last_name': state.lastName.trim(),
              'name': fullName,
              'location': locationStr,
              'bio': state.bio.trim(),
              'role': roleStr,
              if (state.profileImagePath != null)
                'profile_image_path': state.profileImagePath,
            },
          );

      // Immediately propagate created profile into persistent state
      final currentActor = AppPersistenceService.instance.getActorPersona();
      final updatedActor = currentActor.copyWith(
        id: uid,
        name: fullName.isNotEmpty ? fullName : currentActor.name,
        role: roleStr,
        location: locationStr,
        bio: state.bio.trim(),
        avatarUrl: state.profileImagePath ?? currentActor.avatarUrl,
      );
      AppPersistenceService.instance.savePersona(updatedActor);
      AppPersistenceService.instance.setActivePersonaId(uid);
      await ref.read(userPersonaProvider.notifier).updateProfile(updatedActor);

      // Ensure local portfolio does not retain dummy Gilgit-Baltistan seed
      final currentPort = AppPersistenceService.instance.getPortfolio(uid);
      final hasLegacyDummy = currentPort.videos.any((v) => v.title.contains('Dramatic Monologue') || v.mediaUrl.contains('cloudinary')) ||
          currentPort.photos.any((p) => p.title.contains('Dramatic Portrait') || p.mediaUrl.contains('cloudinary'));
      if (hasLegacyDummy) {
        const emptyPort = UserPortfolioState(videos: [], photos: []);
        AppPersistenceService.instance.savePortfolio(uid, emptyPort);
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await AppPersistenceService.instance.syncWithSupabaseUser(user);
      }

      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('CompleteProfileNotifier.save: $e');
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      return false;
    }
  }
}

final completeProfileProvider =
    NotifierProvider<CompleteProfileNotifier, CompleteProfileState>(
      CompleteProfileNotifier.new,
    );
