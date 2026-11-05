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
      bio: bio.isNotEmpty ? bio : null,
      location: location.isNotEmpty ? location : null,
      incorporationNumber: null,
      establishedYear: null,
      address: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class TestAccounts {
  TestAccounts._();

  static const String masterTestOtp = '123456';

  static const String productionId = '4f668c94-c9df-4db2-b844-b7ad0a981fde';
  static const String actorId = '68f958bd-015f-4d74-ab42-98c224240537';
  static const String directorId = '363152eb-78b7-4625-9f6e-e13dc8da45d2';
  static const String cinematographerId = 'c3333333-3333-3333-3333-333333333333';
  static const String singerId = 'd4444444-4444-4444-4444-444444444444';

  static const productionHouse = TestAccount(
    id: productionId,
    email: 'production@youtooart.com',
    name: 'skypulse studio',
    firstName: 'skypulse',
    lastName: 'studio',
    role: 'production_house',
    roleDisplay: 'Production House',
    avatarUrl:
        'https://res.cloudinary.com/dsxhrelpu/image/upload/v1793356951/posts/4f668c94-c9df-4db2-b844-b7ad0a981fde/zdfmhy6cauwtc0msvz7u.png',
    location: '',
    bio: '',
    website: '',
    experience: '',
    isProductionHouse: true,
  );

  static const actor = TestAccount(
    id: actorId,
    email: 'actor@youtooart.com',
    name: 'Ahmed Ali',
    firstName: 'Ahmed',
    lastName: 'Ali',
    role: 'actor',
    roleDisplay: 'actor',
    avatarUrl:
        'https://res.cloudinary.com/dsxhrelpu/image/upload/v1793547618/avatars/68f958bd-015f-4d74-ab42-98c224240537/wvudfqw8ke0vsgvo9qjr.png',
    location: '',
    bio: '',
    website: '',
    experience: '',
    isProductionHouse: false,
  );

  static const director = TestAccount(
    id: directorId,
    email: 'director@youtooart.com',
    name: 'Tommy Don',
    firstName: 'Tommy',
    lastName: 'Don',
    role: 'director',
    roleDisplay: 'Director',
    avatarUrl:
        'https://res.cloudinary.com/dsxhrelpu/image/upload/v1793470261/posts/363152eb-78b7-4625-9f6e-e13dc8da45d2/oqlc9tc0nfbcirkrd5bm.jpg',
    location: '',
    bio: '',
    website: '',
    experience: '',
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
