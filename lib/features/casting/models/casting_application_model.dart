enum ApplicationStatus {
  received,
  accepted,
  rejected,
  wishlisted,
}

/// Model representing a Talent's application to a Casting Call matching Figma designs.
class CastingApplicationModel {
  final String id;
  final String castingCallId;
  final String projectTitle;
  final String applicantId;
  final String applicantName;
  final String? applicantAvatar;
  final String appliedAt; // e.g. "1 Day Ago"
  final DateTime appliedDateTime;
  final String contactNumber;
  final String contactEmail;
  final String age;
  final String height;
  final String gender;
  final String experience;
  final String location;
  final String note;
  final ApplicationStatus status;
  final bool isWishlisted;

  const CastingApplicationModel({
    required this.id,
    required this.castingCallId,
    required this.projectTitle,
    required this.applicantId,
    required this.applicantName,
    this.applicantAvatar,
    required this.appliedAt,
    required this.appliedDateTime,
    required this.contactNumber,
    required this.contactEmail,
    required this.age,
    required this.height,
    required this.gender,
    required this.experience,
    required this.location,
    required this.note,
    this.status = ApplicationStatus.received,
    this.isWishlisted = false,
  });

  bool get isAccepted => status == ApplicationStatus.accepted;
  bool get isRejected => status == ApplicationStatus.rejected;

  CastingApplicationModel copyWith({
    String? id,
    String? castingCallId,
    String? projectTitle,
    String? applicantId,
    String? applicantName,
    String? applicantAvatar,
    String? appliedAt,
    DateTime? appliedDateTime,
    String? contactNumber,
    String? contactEmail,
    String? age,
    String? height,
    String? gender,
    String? experience,
    String? location,
    String? note,
    ApplicationStatus? status,
    bool? isWishlisted,
  }) {
    return CastingApplicationModel(
      id: id ?? this.id,
      castingCallId: castingCallId ?? this.castingCallId,
      projectTitle: projectTitle ?? this.projectTitle,
      applicantId: applicantId ?? this.applicantId,
      applicantName: applicantName ?? this.applicantName,
      applicantAvatar: applicantAvatar ?? this.applicantAvatar,
      appliedAt: appliedAt ?? this.appliedAt,
      appliedDateTime: appliedDateTime ?? this.appliedDateTime,
      contactNumber: contactNumber ?? this.contactNumber,
      contactEmail: contactEmail ?? this.contactEmail,
      age: age ?? this.age,
      height: height ?? this.height,
      gender: gender ?? this.gender,
      experience: experience ?? this.experience,
      location: location ?? this.location,
      note: note ?? this.note,
      status: status ?? this.status,
      isWishlisted: isWishlisted ?? this.isWishlisted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'castingCallId': castingCallId,
        'projectTitle': projectTitle,
        'applicantId': applicantId,
        'applicantName': applicantName,
        'applicantAvatar': applicantAvatar,
        'appliedAt': appliedAt,
        'appliedDateTime': appliedDateTime.toIso8601String(),
        'contactNumber': contactNumber,
        'contactEmail': contactEmail,
        'age': age,
        'height': height,
        'gender': gender,
        'experience': experience,
        'location': location,
        'note': note,
        'status': status.name,
        'isWishlisted': isWishlisted,
      };

  factory CastingApplicationModel.fromJson(Map<String, dynamic> json) {
    return CastingApplicationModel(
      id: json['id'] as String? ?? '',
      castingCallId: json['castingCallId'] as String? ?? '',
      projectTitle: json['projectTitle'] as String? ?? '',
      applicantId: json['applicantId'] as String? ?? '',
      applicantName: json['applicantName'] as String? ?? '',
      applicantAvatar: json['applicantAvatar'] as String?,
      appliedAt: json['appliedAt'] as String? ?? '1 Day Ago',
      appliedDateTime: json['appliedDateTime'] != null
          ? DateTime.tryParse(json['appliedDateTime'] as String) ??
              DateTime.now()
          : DateTime.now(),
      contactNumber: json['contactNumber'] as String? ?? '',
      contactEmail: json['contactEmail'] as String? ?? '',
      age: json['age'] as String? ?? '23',
      height: json['height'] as String? ?? '5.9 Feet',
      gender: json['gender'] as String? ?? 'Male',
      experience: json['experience'] as String? ?? '5 Years',
      location: json['location'] as String? ?? 'Islamabad, Pakistan',
      note: json['note'] as String? ?? '',
      status: ApplicationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ApplicationStatus.received,
      ),
      isWishlisted: json['isWishlisted'] as bool? ?? false,
    );
  }
}
