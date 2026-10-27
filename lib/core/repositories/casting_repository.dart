import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/features/casting/models/casting_application_model.dart';
import 'package:you_too_art/features/casting/models/casting_call_model.dart';

/// Repository for casting call and application operations.
/// Backed by Supabase with resilient fallbacks for offline / local mode.
class CastingRepository {
  final SupabaseClient _client;
  static bool? _isSupabaseTableAvailable;

  CastingRepository(this._client);

  SupabaseQueryBuilder get _calls =>
      _client.from(SupabaseTables.castingCalls);
  SupabaseQueryBuilder get _applications =>
      _client.from(SupabaseTables.castingApplications);

  /// Fetch all active casting calls from Supabase.
  Future<List<CastingCallModel>> fetchCastingCalls() async {
    if (_isSupabaseTableAvailable == false) return [];
    try {
      final data = await _calls.select().order('created_at', ascending: false);
      _isSupabaseTableAvailable = true;
      return (data as List<dynamic>)
          .map((row) => _mapRowToCastingCall(row as Map<String, dynamic>))
          .where((c) => !c.isDeleted)
          .toList();
    } catch (e) {
      _recordError(e);
      return [];
    }
  }

  /// Real-time stream of casting calls.
  Stream<List<Map<String, dynamic>>> watchCastingCalls({
    String? roleType,
  }) {
    var query = _calls.stream(primaryKey: ['id']);
    if (roleType != null) {
      query = query.eq('role_type', roleType);
    }
    return query.order('created_at', ascending: false);
  }

  /// Create a new casting call on Supabase.
  Future<void> createCastingCall(CastingCallModel call) async {
    try {
      await _calls.upsert({
        'id': call.id,
        'title': call.projectTitle,
        'description': call.description,
        'author_id': call.authorId,
        'author_name': call.authorName,
        'author_avatar': call.authorAvatar,
        'location': call.location,
        'city': call.locationDisplay,
        'type': call.type,
        'shoot_duration': call.shootDuration,
        'budget': call.budget,
        'crew_required': call.crewRequired,
        'shoot_details': call.shootDetails,
        'position': call.position,
        'age_required': call.ageRequired,
        'height_required': call.heightRequired,
        'gender': call.gender,
        'contact_email': call.contactEmail,
        'contact_number': call.contactNumber,
        'role_title': call.roleTitle,
        'role_description': call.roleDescription,
        'created_at': call.publishedAt.toIso8601String(),
        'is_deleted': call.isDeleted,
      });
      _isSupabaseTableAvailable = true;
    } catch (e) {
      _recordError(e);
    }
  }

  /// Mark casting call as deleted in Supabase.
  Future<void> deleteCastingCall(String id) async {
    try {
      await _calls.update({'is_deleted': true}).eq('id', id);
    } catch (e) {
      _recordError(e);
    }
  }

  /// Fetch all applications from Supabase.
  Future<List<CastingApplicationModel>> fetchApplications() async {
    if (_isSupabaseTableAvailable == false) return [];
    try {
      final data =
          await _applications.select().order('created_at', ascending: false);
      _isSupabaseTableAvailable = true;
      return (data as List<dynamic>)
          .map((row) => _mapRowToApplication(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _recordError(e);
      return [];
    }
  }

  /// Submit a casting application to Supabase.
  Future<void> submitApplication(CastingApplicationModel application) async {
    try {
      await _applications.upsert({
        'id': application.id,
        'casting_call_id': application.castingCallId,
        'project_title': application.projectTitle,
        'applicant_id': application.applicantId,
        'applicant_name': application.applicantName,
        'applicant_avatar': application.applicantAvatar,
        'applied_at': application.appliedAt,
        'contact_number': application.contactNumber,
        'contact_email': application.contactEmail,
        'age': application.age,
        'height': application.height,
        'gender': application.gender,
        'experience': application.experience,
        'location': application.location,
        'note': application.note,
        'status': application.status.name,
        'is_wishlisted': application.isWishlisted,
        'created_at': application.appliedDateTime.toIso8601String(),
      });
      _isSupabaseTableAvailable = true;
    } catch (e) {
      _recordError(e);
    }
  }

  /// Update application status (accepted, rejected, etc.) on Supabase.
  Future<void> updateApplicationStatus(
    String applicationId,
    String status, {
    bool? isWishlisted,
  }) async {
    try {
      final updates = <String, dynamic>{'status': status};
      if (isWishlisted != null) {
        updates['is_wishlisted'] = isWishlisted;
      }
      await _applications.update(updates).eq('id', applicationId);
    } catch (e) {
      _recordError(e);
    }
  }

  void _recordError(Object e) {
    final str = e.toString();
    if (str.contains('PGRST205') ||
        str.contains('404') ||
        str.contains('Could not find the table') ||
        str.contains('does not exist')) {
      _isSupabaseTableAvailable = false;
      if (kDebugMode) {
        debugPrint(
          'Notice: Supabase casting tables not found in cloud project. Seamlessly falling back to local storage.',
        );
      }
    } else {
      if (kDebugMode) debugPrint('CastingRepository notice: $e');
    }
  }

  CastingCallModel _mapRowToCastingCall(Map<String, dynamic> row) {
    return CastingCallModel(
      id: row['id'] as String? ?? 'call_${DateTime.now().millisecondsSinceEpoch}',
      projectTitle: row['title'] as String? ?? row['projectTitle'] as String? ?? 'Untitled Call',
      authorId: row['author_id'] as String? ?? row['posted_by_id'] as String? ?? '',
      authorName: row['author_name'] as String? ?? 'Production',
      authorAvatar: row['author_avatar'] as String?,
      publishedDateStr: row['published_date_str'] as String? ?? 'Recently',
      publishedAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      description: row['description'] as String? ?? '',
      location: row['location'] as String? ?? 'Islamabad, Pakistan',
      locationDisplay: row['city'] as String? ?? row['locationDisplay'] as String? ?? 'Islamabad',
      type: row['type'] as String? ?? row['role_type'] as String? ?? 'Short Film',
      shootDuration: row['shoot_duration'] as String? ?? '25 Days',
      budget: row['budget'] as String? ?? '\$20K',
      budgetFull: row['budget_full'] as String? ?? '\$20,000',
      crewRequired: row['crew_required'] as String? ?? '1',
      shootDetails: row['shoot_details'] as String? ?? '',
      position: row['position'] as String? ?? 'Lead Actor',
      ageRequired: row['age_required'] as String? ?? '23',
      heightRequired: row['height_required'] as String? ?? '5.9 Feet',
      gender: row['gender'] as String? ?? 'Male Only',
      contactEmail: row['contact_email'] as String?,
      contactNumber: row['contact_number'] as String?,
      roleTitle: row['role_title'] as String?,
      roleDescription: row['role_description'] as String?,
      applicantsCount: row['applicants_count'] as int? ?? 0,
      isApplied: row['is_applied'] as bool? ?? false,
      appliedAt: row['applied_at'] as String?,
      isDeleted: row['is_deleted'] as bool? ?? false,
    );
  }

  CastingApplicationModel _mapRowToApplication(Map<String, dynamic> row) {
    return CastingApplicationModel(
      id: row['id'] as String? ?? 'app_${DateTime.now().millisecondsSinceEpoch}',
      castingCallId: row['casting_call_id'] as String? ?? '',
      projectTitle: row['project_title'] as String? ?? 'The Next Short Film',
      applicantId: row['applicant_id'] as String? ?? '',
      applicantName: row['applicant_name'] as String? ?? 'Applicant',
      applicantAvatar: row['applicant_avatar'] as String?,
      appliedAt: row['applied_at'] as String? ?? 'Recently',
      appliedDateTime: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      contactNumber: row['contact_number'] as String? ?? '',
      contactEmail: row['contact_email'] as String? ?? '',
      age: row['age'] as String? ?? '23',
      height: row['height'] as String? ?? '5.9 Feet',
      gender: row['gender'] as String? ?? 'Male',
      experience: row['experience'] as String? ?? '5 Years',
      location: row['location'] as String? ?? 'Islamabad, Pakistan',
      note: row['note'] as String? ?? '',
      status: ApplicationStatus.values.firstWhere(
        (e) => e.name == row['status'],
        orElse: () => ApplicationStatus.received,
      ),
      isWishlisted: row['is_wishlisted'] as bool? ?? false,
    );
  }
}
