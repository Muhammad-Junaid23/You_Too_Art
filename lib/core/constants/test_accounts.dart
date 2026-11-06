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

  static const String masterTestOtp = '';

  static const String productionId = '';
  static const String actorId = '';
  static const String directorId = '';
  static const String cinematographerId = '';
  static const String singerId = '';

  static const List<TestAccount> all = [];

  static bool isTestEmail(String email) => false;

  static bool isTestId(String? id) => false;

  static TestAccount? findByEmail(String email) => null;

  static TestAccount? findById(String id) => null;
}
