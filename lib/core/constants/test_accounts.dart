import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';

/// Pre-configured test accounts representing all core platform roles.
/// Supports 1-tap instant login and master OTP (123456) for multi-role testing.
class TestAccount {
  final String email;
  final String name;
  final String firstName;
  final String lastName;
  final String role;
  final String roleDisplay;
  final String avatarUrl;
  final String location;
  final String bio;
  final String experience;
  final String website;
  final bool isProductionHouse;
  final String id;

  const TestAccount({
    required this.id,
    required this.email,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.roleDisplay,
    required this.avatarUrl,
    required this.location,
    required this.bio,
    this.experience = '5+ Years',
    this.website = '',
    this.isProductionHouse = false,
  });

  UserPersona toPersona() {
    return UserPersona(
      id: id,
      name: name,
      email: email,
      role: roleDisplay,
      avatarUrl: avatarUrl,
      isProductionHouse: isProductionHouse,
      bio: bio,
      website: website,
      experience: experience,
      location: location,
    );
  }

  UserModel toUserModel() {
    return UserModel(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      role: role,
      profileImagePath: avatarUrl,
      bio: bio,
      location: location,
      incorporationNumber: isProductionHouse ? 'PK-REG-84920' : null,
      establishedYear: isProductionHouse ? 2019 : null,
      address: isProductionHouse ? 'Blue Area, Islamabad' : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class TestAccounts {
  TestAccounts._();

  static const String masterTestOtp = '123456';

  static const String productionId = 'b2222222-2222-2222-2222-222222222222';
  static const String actorId = '00000000-0000-0000-0000-000000000001';
  static const String directorId = 'a1111111-1111-1111-1111-111111111111';
  static const String cinematographerId = 'c3333333-3333-3333-3333-333333333333';
  static const String singerId = 'd4444444-4444-4444-4444-444444444444';

  static const productionHouse = TestAccount(
    id: productionId,
    email: 'production@youtooart.com',
    name: 'SkyPulse Studios',
    firstName: 'SkyPulse',
    lastName: 'Studios',
    role: 'production_house',
    roleDisplay: 'Production House',
    avatarUrl:
        'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
    location: 'Islamabad, Pakistan',
    bio:
        'Leading digital film studio producing groundbreaking feature films, digital web series, and high-impact commercial cinema. We connect bold emerging talent with top industry directors.',
    website: 'www.skypulsestudios.com',
    experience: '8+ Years',
    isProductionHouse: true,
  );

  static const actor = TestAccount(
    id: actorId,
    email: 'actor@youtooart.com',
    name: 'Hamza Ali',
    firstName: 'Hamza',
    lastName: 'Ali',
    role: 'actor',
    roleDisplay: 'Actor | Performing Artist',
    avatarUrl:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
    location: 'Islamabad, Pakistan',
    bio:
        'Trained theater and screen actor specializing in dramatic monologues, character studies, and cinematic narratives.',
    website: 'www.hamzaali.art',
    experience: '5+ Years',
    isProductionHouse: false,
  );

  static const director = TestAccount(
    id: directorId,
    email: 'director@youtooart.com',
    name: 'Zaid Khan',
    firstName: 'Zaid',
    lastName: 'Khan',
    role: 'director',
    roleDisplay: 'Director | Filmmaker',
    avatarUrl:
        'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=400&q=80',
    location: 'Lahore, Pakistan',
    bio:
        'Award-winning independent filmmaker and commercial director with a passion for authentic storytelling, festival cinema, and discovering new talent.',
    website: 'www.zaidkhanfilms.com',
    experience: '7+ Years',
    isProductionHouse: false,
  );

  static const cinematographer = TestAccount(
    id: cinematographerId,
    email: 'crew@youtooart.com',
    name: 'Sara Ahmed',
    firstName: 'Sara',
    lastName: 'Ahmed',
    role: 'cinematographer',
    roleDisplay: 'Cinematographer | DoP',
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    location: 'Karachi, Pakistan',
    bio:
        'Cinematographer and camera operator specializing in Arri & RED camera workflows, anamorphic lighting design, and cinematic commercial aesthetics.',
    website: 'www.sara-cinematography.com',
    experience: '6+ Years',
    isProductionHouse: false,
  );

  static const singer = TestAccount(
    id: singerId,
    email: 'singer@youtooart.com',
    name: 'Bilal Tariq',
    firstName: 'Bilal',
    lastName: 'Tariq',
    role: 'singer',
    roleDisplay: 'Singer | Composer',
    avatarUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
    location: 'Islamabad, Pakistan',
    bio:
        'Vocalist, playback singer, and music composer for independent films and drama soundtracks. Open for film scores and original collaborations.',
    website: 'www.bilaltariqmusic.com',
    experience: '4+ Years',
    isProductionHouse: false,
  );

  static const List<TestAccount> all = [
    productionHouse,
    actor,
    director,
    cinematographer,
    singer,
  ];

  static bool isTestEmail(String email) {
    final clean = email.trim().toLowerCase();
    return all.any((a) => a.email.toLowerCase() == clean);
  }

  static bool isTestId(String? id) {
    if (id == null || id.isEmpty) return false;
    return all.any((a) => a.id == id);
  }

  static TestAccount? findByEmail(String email) {
    final clean = email.trim().toLowerCase();
    try {
      return all.firstWhere((a) => a.email.toLowerCase() == clean);
    } catch (_) {
      return null;
    }
  }

  static TestAccount? findById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
