import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';

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

      await ref
          .read(userRepositoryProvider)
          .updateProfile(
            uid: uid,
            updates: {
              'first_name': state.firstName.trim(),
              'last_name': state.lastName.trim(),
              'name': '${state.firstName.trim()} ${state.lastName.trim()}'
                  .trim(),
              'location': '${state.city}, ${state.country}',
              'bio': state.bio.trim(),
              if (state.profileImagePath != null)
                'profile_image_path': state.profileImagePath,
            },
          );

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
