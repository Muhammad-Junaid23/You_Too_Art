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

  static const personaActor = UserPersona(
    id: actorDefaultId,
    name: 'Muhammad Wajahat',
    email: 'wajahat@youtooart.test',
    role: 'Actor, Director',
    avatarUrl:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
    isProductionHouse: false,
    bio:
        'Award-winning performing artist and indie filmmaker focusing on dramatic monologues, character studies, and cinematic narratives.',
    website: 'www.be.net/WajahatUIUX',
    experience: '5+ Years',
    location: 'Islamabad, Pakistan',
  );

  static const personaAlexander = UserPersona(
    id: alexanderId,
    name: 'Alexander Cole',
    email: 'alexander.cole@youtooart.test',
    role: 'Actor | Director | Producer',
    avatarUrl:
        'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=400&q=80',
    isProductionHouse: false,
    bio:
        'Award-winning actor and indie film director with extensive experience across feature drama, festival shorts, and modern theatrical storytelling.',
    website: 'www.alexandercole.art',
    experience: '8+ Years',
    location: 'New York, NY',
  );

  static const personaFilmFare = UserPersona(
    id: filmfareId,
    name: 'FilmFare',
    email: 'filmfare.studio@youtooart.test',
    role: 'Production House',
    avatarUrl:
        'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
    isProductionHouse: true,
    bio:
        'FilmFare is a premier entertainment studio producing groundbreaking feature films, digital web series, and high-impact commercial cinema. We connect bold emerging talent with top industry directors.',
    website: 'www.filmfare-studios.com',
    experience: '12+ Years',
    location: 'Hollywood, CA',
  );

  static const personaJeremiah = UserPersona(
    id: jeremiahId,
    name: 'Jeremiah Green',
    email: 'jeremiah.green@youtooart.test',
    role: 'Actor | Model | Director',
    avatarUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
    isProductionHouse: false,
    bio:
        'Passionate actor, runway model, and aspiring film director based in Los Angeles. Experienced in leading roles across independent cinema, international commercials, and theatrical performances.',
    website: 'www.jeremiahgreen.com',
    experience: '6+ Years',
    location: 'Los Angeles, CA',
  );

  static bool isActorId(String id) =>
      AppPersistenceService.instance.isActorId(id);

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
