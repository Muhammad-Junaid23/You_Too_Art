import 'package:you_too_art/core/utils/json_utils.dart';

class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? profileImagePath;
  final String? bio;
  final String role;
  final String? location;
  final bool isAdmin;
  final bool isVerified;
  final String? incorporationNumber;
  final int? establishedYear;
  final String? address;
  final String? website;
  final String? experience;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    required this.email,
    this.profileImagePath,
    this.bio,
    this.role = 'unset',
    this.location,
    this.isAdmin = false,
    this.isVerified = false,
    this.incorporationNumber,
    this.establishedYear,
    this.address,
    this.website,
    this.experience,
    this.createdAt,
    this.updatedAt,
  });

  String get name => '$firstName $lastName'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: parseString(json['id']),
      firstName: parseString(json['first_name']),
      lastName: parseString(json['last_name']),
      email: parseString(json['email']),
      profileImagePath:
          (json['profile_image_path'] ?? json['profileImagePath']) as String?,
      bio: json['bio'] as String?,
      role: parseString(json['role'], defaultValue: 'unset'),
      location: json['location'] as String?,
      isAdmin: parseBool(json['is_admin'] ?? json['isAdmin']),
      isVerified: parseBool(json['is_verified'] ?? json['isVerified'] ?? json['raw_user_meta_data']?['is_verified']),
      incorporationNumber: json['incorporation_number'] as String?,
      establishedYear: json['established_year'] as int?,
      address: json['address'] as String?,
      website: (json['website'] ?? json['raw_user_meta_data']?['website']) as String?,
      experience: (json['experience'] ?? json['raw_user_meta_data']?['experience']) as String?,
      createdAt: parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'name': name,
      'email': email,
      'profile_image_path': profileImagePath,
      'bio': bio,
      'role': role,
      'location': location,
      'is_admin': isAdmin,
      'is_verified': isVerified,
      'incorporation_number': incorporationNumber,
      'established_year': establishedYear,
      'address': address,
      'website': website,
      'experience': experience,
      'created_at': serializeDateTime(createdAt),
      'updated_at': serializeDateTime(updatedAt),
    };
  }

  UserModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? profileImagePath,
    String? bio,
    String? role,
    String? location,
    bool? isAdmin,
    bool? isVerified,
    String? incorporationNumber,
    int? establishedYear,
    String? address,
    String? website,
    String? experience,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      location: location ?? this.location,
      isAdmin: isAdmin ?? this.isAdmin,
      isVerified: isVerified ?? this.isVerified,
      incorporationNumber: incorporationNumber ?? this.incorporationNumber,
      establishedYear: establishedYear ?? this.establishedYear,
      address: address ?? this.address,
      website: website ?? this.website,
      experience: experience ?? this.experience,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'UserModel(id: $id, name: $name, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
