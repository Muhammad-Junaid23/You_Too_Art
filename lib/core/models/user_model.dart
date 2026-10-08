import 'package:you_too_art/core/utils/json_utils.dart';

/// Represents a user in the You Too Art platform.
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    required this.email,
    this.profileImagePath,
    this.bio,
    this.role = 'actor',
    this.location,
    this.isAdmin = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Computed full name. Kept as a getter so existing code that reads
  /// `.name` keeps working. Also persisted to the `name` column on write.
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
      role: parseString(json['role'], defaultValue: 'actor'),
      location: json['location'] as String?,
      isAdmin: parseBool(json['is_admin'] ?? json['isAdmin']),
      createdAt: parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'name': name, // mirrored for backward compatibility
      'email': email,
      'profile_image_path': profileImagePath,
      'bio': bio,
      'role': role,
      'location': location,
      'is_admin': isAdmin,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'UserModel(id: $id, name: $name, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}