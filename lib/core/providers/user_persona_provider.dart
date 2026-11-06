import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:you_too_art/core/providers/shared_preferences_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';

class UserPersona {
  final String id;
  final String name;
  final String email;
  final String role;
  final String avatarUrl;
  final bool isProductionHouse;
  final String bio;
  final String website;
  final String experience;
  final String location;

  const UserPersona({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.avatarUrl,
    this.isProductionHouse = false,
    this.bio = '',
    this.website = '',
    this.experience = '',
    this.location = '',
  });

  UserPersona copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? avatarUrl,
    bool? isProductionHouse,
    String? bio,
    String? website,
    String? experience,
    String? location,
  }) {
    return UserPersona(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isProductionHouse: isProductionHouse ?? this.isProductionHouse,
      bio: bio ?? this.bio,
      website: website ?? this.website,
      experience: experience ?? this.experience,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'avatarUrl': avatarUrl,
        'isProductionHouse': isProductionHouse,
        'bio': bio,
        'website': website,
        'experience': experience,
        'location': location,
      };

  factory UserPersona.fromJson(Map<String, dynamic> json) {
    return UserPersona(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      isProductionHouse: json['isProductionHouse'] as bool? ?? false,
      bio: json['bio'] as String? ?? '',
      website: json['website'] as String? ?? '',
      experience: json['experience'] as String? ?? '',
      location: json['location'] as String? ?? '',
    );
  }
}

class UserPersonaNotifier extends Notifier<UserPersona> {
  static SharedPreferences? globalPrefs;

  static const String actorDefaultId = AppPersistenceService.actorDefaultId;
  static const String alexanderId = AppPersistenceService.alexanderId;
  static const String filmfareId = AppPersistenceService.filmfareId;
  static const String jeremiahId = AppPersistenceService.jeremiahId;
  static const String singerId = AppPersistenceService.singerId;

  static const personaEmpty = UserPersona(
    id: '',
    name: '',
    email: '',
    role: '',
    avatarUrl: '',
    isProductionHouse: false,
    bio: '',
    website: '',
    experience: '',
    location: '',
  );

  static const personaActor = personaEmpty;
  static const personaAlexander = personaEmpty;
  static const personaFilmFare = personaEmpty;

  static bool isActorId(String id) =>
      AppPersistenceService.instance.isActorId(id);

  static bool isDirectorId(String id) =>
      AppPersistenceService.instance.isDirectorId(id);

  static bool isProductionId(String id) =>
      AppPersistenceService.instance.isProductionId(id);

  static bool isSamePersona(String id1, String id2) =>
      AppPersistenceService.instance.isSamePersona(id1, id2);

  static UserPersona getActorPersona([SharedPreferences? prefs]) =>
      AppPersistenceService.instance.getActorPersona();

  static UserPersona buildActorPersona() =>
      AppPersistenceService.instance.getActorPersona();

  static bool hasPersona(String id) =>
      AppPersistenceService.instance.hasPersona(id);

  static UserPersona getPersonaById(String id, [SharedPreferences? prefs]) =>
      AppPersistenceService.instance.getPersona(id);

  static List<UserPersona> get allPersonas =>
      AppPersistenceService.instance.allPersonas;

  @override
  UserPersona build() {
    ref.watch(sharedPreferencesProvider);
    void listener() {
      state = AppPersistenceService.instance.getActivePersona();
    }
    AppPersistenceService.instance.addListener(listener);
    ref.onDispose(() => AppPersistenceService.instance.removeListener(listener));
    return AppPersistenceService.instance.getActivePersona();
  }

  Future<void> updateProfile(UserPersona updated) async {
    AppPersistenceService.instance.savePersona(updated);
    state = updated;
  }

  Future<void> switchPersona(UserPersona newPersona) async {
    AppPersistenceService.instance.setActivePersonaId(newPersona.id);
    state = AppPersistenceService.instance.getActivePersona();
  }

  Future<void> switchById(String id) async {
    final match = allPersonas.firstWhere(
      (p) => isSamePersona(p.id, id),
      orElse: () => getActorPersona(),
    );
    await switchPersona(match);
  }
}

final userPersonaProvider =
    NotifierProvider<UserPersonaNotifier, UserPersona>(() {
  return UserPersonaNotifier();
});

final activePersonaUidProvider = Provider<String>((ref) {
  return ref.watch(userPersonaProvider).id;
});
