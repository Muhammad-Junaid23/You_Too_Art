/// Model representing a Casting Call in You2Art matching Figma designs.
class CastingCallModel {
  final String id;
  final String projectTitle;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String publishedDateStr; // e.g. "24th April, 2023" or "2 Days Ago"
  final DateTime publishedAt;
  final String description;
  final String location;
  final String locationDisplay;
  final String type; // e.g. "Short Film", "Feature Film", "Commercial"
  final String shootDuration; // e.g. "25 Days"
  final String budget; // e.g. "$20K"
  final String budgetFull; // e.g. "$20,000"
  final String crewRequired; // e.g. "1"
  final String shootDetails;
  final String position;
  final String ageRequired;
  final String heightRequired;
  final String gender; // e.g. "Male Only", "Female Only", "Any"
  final String? contactEmail;
  final String? contactNumber;
  final String? roleTitle;
  final String? roleDescription;
  final int applicantsCount;
  final bool isApplied;
  final String? appliedAt; // e.g. "2 Days Ago"
  final bool isDeleted;

  const CastingCallModel({
    required this.id,
    required this.projectTitle,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.publishedDateStr,
    required this.publishedAt,
    required this.description,
    required this.location,
    required this.locationDisplay,
    required this.type,
    required this.shootDuration,
    required this.budget,
    this.budgetFull = '\$20,000',
    this.crewRequired = '1',
    required this.shootDetails,
    required this.position,
    required this.ageRequired,
    required this.heightRequired,
    required this.gender,
    this.contactEmail,
    this.contactNumber,
    this.roleTitle,
    this.roleDescription,
    this.applicantsCount = 0,
    this.isApplied = false,
    this.appliedAt,
    this.isDeleted = false,
  });

  CastingCallModel copyWith({
    String? id,
    String? projectTitle,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? publishedDateStr,
    DateTime? publishedAt,
    String? description,
    String? location,
    String? locationDisplay,
    String? type,
    String? shootDuration,
    String? budget,
    String? budgetFull,
    String? crewRequired,
    String? shootDetails,
    String? position,
    String? ageRequired,
    String? heightRequired,
    String? gender,
    String? contactEmail,
    String? contactNumber,
    String? roleTitle,
    String? roleDescription,
    int? applicantsCount,
    bool? isApplied,
    String? appliedAt,
    bool? isDeleted,
  }) {
    return CastingCallModel(
      id: id ?? this.id,
      projectTitle: projectTitle ?? this.projectTitle,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      publishedDateStr: publishedDateStr ?? this.publishedDateStr,
      publishedAt: publishedAt ?? this.publishedAt,
      description: description ?? this.description,
      location: location ?? this.location,
      locationDisplay: locationDisplay ?? this.locationDisplay,
      type: type ?? this.type,
      shootDuration: shootDuration ?? this.shootDuration,
      budget: budget ?? this.budget,
      budgetFull: budgetFull ?? this.budgetFull,
      crewRequired: crewRequired ?? this.crewRequired,
      shootDetails: shootDetails ?? this.shootDetails,
      position: position ?? this.position,
      ageRequired: ageRequired ?? this.ageRequired,
      heightRequired: heightRequired ?? this.heightRequired,
      gender: gender ?? this.gender,
      contactEmail: contactEmail ?? this.contactEmail,
      contactNumber: contactNumber ?? this.contactNumber,
      roleTitle: roleTitle ?? this.roleTitle,
      roleDescription: roleDescription ?? this.roleDescription,
      applicantsCount: applicantsCount ?? this.applicantsCount,
      isApplied: isApplied ?? this.isApplied,
      appliedAt: appliedAt ?? this.appliedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectTitle': projectTitle,
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'publishedDateStr': publishedDateStr,
        'publishedAt': publishedAt.toIso8601String(),
        'description': description,
        'location': location,
        'locationDisplay': locationDisplay,
        'type': type,
        'shootDuration': shootDuration,
        'budget': budget,
        'budgetFull': budgetFull,
        'crewRequired': crewRequired,
        'shootDetails': shootDetails,
        'position': position,
        'ageRequired': ageRequired,
        'heightRequired': heightRequired,
        'gender': gender,
        'contactEmail': contactEmail,
        'contactNumber': contactNumber,
        'roleTitle': roleTitle,
        'roleDescription': roleDescription,
        'applicantsCount': applicantsCount,
        'isApplied': isApplied,
        'appliedAt': appliedAt,
        'isDeleted': isDeleted,
      };

  factory CastingCallModel.fromJson(Map<String, dynamic> json) {
    final int rawApplicants = (json['applicantsCount'] is num)
        ? (json['applicantsCount'] as num).toInt()
        : (json['applicants_count'] is num
            ? (json['applicants_count'] as num).toInt()
            : int.tryParse(json['applicantsCount']?.toString() ??
                    json['applicants_count']?.toString() ??
                    '') ??
                0);

    return CastingCallModel(
      id: json['id'] as String? ?? '',
      projectTitle: json['projectTitle'] as String? ??
          json['title'] as String? ??
          '',
      authorId: json['authorId'] as String? ??
          json['author_id'] as String? ??
          '',
      authorName: json['authorName'] as String? ??
          json['author_name'] as String? ??
          '',
      authorAvatar: json['authorAvatar'] as String? ??
          json['author_avatar'] as String?,
      publishedDateStr: json['publishedDateStr'] as String? ??
          json['published_date_str'] as String? ??
          'Recently',
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ??
                  DateTime.now()
              : DateTime.now()),
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      locationDisplay: json['locationDisplay'] as String? ??
          json['city'] as String? ??
          '',
      type: json['type'] as String? ?? 'Short Film',
      shootDuration: json['shootDuration'] as String? ??
          json['shoot_duration'] as String? ??
          '',
      budget: json['budget'] as String? ?? 'Negotiable',
      budgetFull: json['budgetFull'] as String? ??
          json['budget_full'] as String? ??
          'Negotiable',
      crewRequired: json['crewRequired']?.toString() ??
          json['crew_required']?.toString() ??
          '1',
      shootDetails: json['shootDetails'] as String? ??
          json['shoot_details'] as String? ??
          '',
      position: json['position'] as String? ?? '',
      ageRequired: json['ageRequired'] as String? ??
          json['age_required'] as String? ??
          '',
      heightRequired: json['heightRequired'] as String? ??
          json['height_required'] as String? ??
          '',
      gender: json['gender'] as String? ?? 'Any',
      contactEmail: json['contactEmail'] as String? ??
          json['contact_email'] as String?,
      contactNumber: json['contactNumber'] as String? ??
          json['contact_number'] as String?,
      roleTitle: json['roleTitle'] as String? ??
          json['role_title'] as String?,
      roleDescription: json['roleDescription'] as String? ??
          json['role_description'] as String?,
      applicantsCount: rawApplicants,
      isApplied: json['isApplied'] == true || json['is_applied'] == true,
      appliedAt: json['appliedAt'] as String? ??
          json['applied_at'] as String?,
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true,
    );
  }
}
