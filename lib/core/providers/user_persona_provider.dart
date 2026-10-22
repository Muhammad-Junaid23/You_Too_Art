import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    this.bio =
        'Netus vel neque vulputate nam nam sit amet a pulvinar. Vitae consequat sed sit interdum nulla. Libero viverra facilisis.',
    this.website = 'www.be.net/WajahatUIUX',
    this.experience = '5+ Years',
    this.location = 'Islamabad, Pakistan',
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
}

class UserPersonaNotifier extends Notifier<UserPersona> {
  static const String _personaPrefKey = 'active_user_persona_id';

  static const String actorDefaultId = '00000000-0000-0000-0000-000000000001';
  static const String alexanderId = 'a1111111-1111-1111-1111-111111111111';
  static const String filmfareId = 'b2222222-2222-2222-2222-222222222222';
  static const String jeremiahId = 'c3333333-3333-3333-3333-333333333333';

  static const personaAlexander = UserPersona(
    id: alexanderId,
    name: 'Alexander Cole',
    email: 'alexander.cole@youtooart.test',
    role: 'Actor | Director | Producer',
    avatarUrl:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
    isProductionHouse: false,
  );

  static const personaFilmFare = UserPersona(
    id: filmfareId,
    name: 'FilmFare',
    email: 'filmfare.studio@youtooart.test',
    role: 'Production House',
    avatarUrl:
        'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
    isProductionHouse: true,
  );

  static const personaJeremiah = UserPersona(
    id: jeremiahId,
    name: 'Jeremiah Green',
    email: 'jeremiah.green@youtooart.test',
    role: 'Actor | Model | Director',
    avatarUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
    isProductionHouse: false,
  );

  static UserPersona buildActorPersona() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final metaName = user.userMetadata?['name'] as String?;
        return UserPersona(
          id: user.id,
          name: (metaName != null && metaName.trim().isNotEmpty)
              ? metaName
              : 'You (Actor)',
          email: user.email ?? 'actor@youtooart.test',
          role: (user.userMetadata?['role'] as String?) ?? 'Actor | Performing Artist',
          avatarUrl:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
          isProductionHouse: false,
        );
      }
    } catch (_) {}

    return const UserPersona(
      id: actorDefaultId,
      name: 'You (Actor)',
      email: 'actor@youtooart.test',
      role: 'Actor | Performing Artist',
      avatarUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
      isProductionHouse: false,
    );
  }

  static List<UserPersona> get allPersonas => [
        buildActorPersona(),
        personaAlexander,
        personaFilmFare,
        personaJeremiah,
      ];

  @override
  UserPersona build() {
    _loadSavedPersona();
    return buildActorPersona();
  }

  Future<void> _loadSavedPersona() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_personaPrefKey);
      if (savedId != null) {
        final found = allPersonas.firstWhere(
          (p) => p.id == savedId,
          orElse: () => buildActorPersona(),
        );
        state = found;
      }
    } catch (_) {}
  }

  Future<void> switchPersona(UserPersona newPersona) async {
    state = newPersona;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_personaPrefKey, newPersona.id);
    } catch (_) {}
  }

  Future<void> switchById(String id) async {
    final match = allPersonas.firstWhere(
      (p) => p.id == id,
      orElse: () => buildActorPersona(),
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
