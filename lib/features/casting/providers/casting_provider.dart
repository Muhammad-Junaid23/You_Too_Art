import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:you_too_art/core/providers/shared_preferences_provider.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/features/casting/models/casting_application_model.dart';
import 'package:you_too_art/features/casting/models/casting_call_model.dart';
import 'package:you_too_art/features/notifications/models/notification_item.dart';

class CastingState {
  final List<CastingCallModel> calls;
  final List<CastingApplicationModel> applications;
  final bool isSyncing;

  const CastingState({
    this.calls = const [],
    this.applications = const [],
    this.isSyncing = false,
  });

  CastingState copyWith({
    List<CastingCallModel>? calls,
    List<CastingApplicationModel>? applications,
    bool? isSyncing,
  }) {
    return CastingState(
      calls: calls ?? this.calls,
      applications: applications ?? this.applications,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

class CastingNotifier extends Notifier<CastingState> {
  static const String _callsKey = 'you_too_art_casting_calls_v2';
  static const String _appsKey = 'you_too_art_casting_apps_v2';

  @override
  CastingState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final initial = _loadInitial(prefs);

    // Asynchronously perform full-stack Supabase sync in background
    Future.microtask(() => syncWithCloud());

    return initial;
  }

  CastingState _loadInitial(SharedPreferences prefs) {
    List<CastingCallModel> calls = [];
    List<CastingApplicationModel> apps = [];

    // 1. Primary: load from AppPersistenceService (multi-engine: cookies, disk, master snapshot)
    try {
      final pCalls = AppPersistenceService.instance.getCastingCalls();
      if (pCalls.isNotEmpty) {
        calls = List<CastingCallModel>.from(pCalls);
      }
      final pApps = AppPersistenceService.instance.getCastingApplications();
      if (pApps.isNotEmpty) {
        apps = List<CastingApplicationModel>.from(pApps);
      }
    } catch (_) {}

    // 2. Secondary fallback: check individual SharedPreferences
    if (calls.isEmpty) {
      final rawCalls = prefs.getString(_callsKey);
      if (rawCalls != null && rawCalls.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawCalls) as List<dynamic>;
          calls = decoded
              .map((e) => CastingCallModel.fromJson(e as Map<String, dynamic>))
              .where((c) => !c.isDeleted)
              .toList();
        } catch (e) {
          if (kDebugMode) debugPrint('Error decoding casting calls: $e');
        }
      }
    }

    if (apps.isEmpty) {
      final rawApps = prefs.getString(_appsKey);
      if (rawApps != null && rawApps.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawApps) as List<dynamic>;
          apps = decoded
              .map((e) =>
                  CastingApplicationModel.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (e) {
          if (kDebugMode) debugPrint('Error decoding casting applications: $e');
        }
      }
    }

    // 3. Purge legacy dummy seed calls & applications
    calls.removeWhere((c) =>
        c.id.startsWith('call_') ||
        c.id == 'call_1' ||
        c.id == 'call_2' ||
        c.id == 'call_3' ||
        c.id == 'my_call_1' ||
        c.projectTitle == 'The Next Short Film' ||
        c.projectTitle == 'Echoes of Rawal' ||
        c.projectTitle == 'Lahore Tales' ||
        c.projectTitle == 'Melody in the Rain' ||
        c.projectTitle == 'Shadows & Dust' ||
        c.projectTitle == 'Midnight Sun' ||
        c.authorId == 'james_geidt' ||
        c.authorId == 'angel_culhane' ||
        c.authorId == 'angel_culhane_2' ||
        c.authorId == 'filmfare' ||
        c.authorId == 'b2222222-2222-2222-2222-222222222222' ||
        c.authorId == 'a1111111-1111-1111-1111-111111111111');

    apps.removeWhere((a) =>
        a.id.startsWith('app_') ||
        a.id == 'app_seed_call1' ||
        a.id == 'app_1' ||
        a.id == 'app_2' ||
        a.id == 'app_3' ||
        a.id == 'app_4' ||
        a.projectTitle == 'The Next Short Film' ||
        a.projectTitle == 'Echoes of Rawal' ||
        a.projectTitle == 'Lahore Tales' ||
        a.projectTitle == 'Melody in the Rain' ||
        a.projectTitle == 'Midnight Sun' ||
        a.castingCallId.startsWith('call_') ||
        a.castingCallId == 'call_1' ||
        a.castingCallId == 'call_2' ||
        a.castingCallId == 'call_3' ||
        a.castingCallId == 'my_call_1');

    // Clean up any globally stamped isApplied flags from stored calls.
    // Application status is user-specific and evaluated dynamically per persona!
    calls = calls
        .map((c) => c.copyWith(isApplied: false, appliedAt: null))
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    _saveCalls(calls, prefs);
    _saveApps(apps, prefs);

    return CastingState(calls: calls, applications: apps);
  }

  void _saveCalls(List<CastingCallModel> calls, [SharedPreferences? prefs]) {
    final SharedPreferences p = prefs ?? ref.read(sharedPreferencesProvider);
    final encoded = jsonEncode(calls.map((e) => e.toJson()).toList());
    p.setString(_callsKey, encoded);
    try {
      AppPersistenceService.instance.saveCastingCalls(calls);
    } catch (_) {}
  }

  void _saveApps(List<CastingApplicationModel> apps, [SharedPreferences? prefs]) {
    final SharedPreferences p = prefs ?? ref.read(sharedPreferencesProvider);
    final encoded = jsonEncode(apps.map((e) => e.toJson()).toList());
    p.setString(_appsKey, encoded);
    try {
      AppPersistenceService.instance.saveCastingApplications(apps);
    } catch (_) {}
  }

  /// Full-Stack Cloud Sync with Supabase (merges remote records gracefully)
  Future<void> syncWithCloud() async {
    state = state.copyWith(isSyncing: true);
    try {
      final repo = ref.read(castingRepositoryProvider);

      // Fetch calls & applications from Supabase
      final remoteCalls = await repo.fetchCastingCalls();
      final remoteApps = await repo.fetchApplications();

      if (remoteCalls.isNotEmpty || remoteApps.isNotEmpty) {
        final Map<String, CastingCallModel> callMap = {
          for (final c in state.calls) c.id: c,
        };
        for (final rc in remoteCalls) {
          final existing = callMap[rc.id];
          if (existing != null) {
            callMap[rc.id] = rc.copyWith(
              isApplied: false,
              appliedAt: null,
              applicantsCount: existing.applicantsCount > rc.applicantsCount
                  ? existing.applicantsCount
                  : rc.applicantsCount,
            );
          } else {
            callMap[rc.id] = rc;
          }
        }

        final Map<String, CastingApplicationModel> appMap = {
          for (final a in state.applications) a.id: a,
        };
        for (final ra in remoteApps) {
          final existing = appMap[ra.id];
          if (existing != null) {
            // Keep existing status if user modified locally
            appMap[ra.id] = existing;
          } else {
            appMap[ra.id] = ra;
          }
        }

        final mergedCalls = callMap.values
            .where((c) => !c.isDeleted)
            .map((c) => c.copyWith(isApplied: false, appliedAt: null))
            .toList()
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

        final mergedApps = appMap.values.toList();

        state = state.copyWith(
          calls: mergedCalls,
          applications: mergedApps,
          isSyncing: false,
        );

        _saveCalls(mergedCalls);
        _saveApps(mergedApps);
      } else {
        state = state.copyWith(isSyncing: false);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('CastingNotifier.syncWithCloud note: $e');
      state = state.copyWith(isSyncing: false);
    }
  }

  /// Apply to a casting call
  Future<void> applyToCall(
    String callId, {
    required String contactNumber,
    required String contactEmail,
    required String note,
  }) async {
    final activePersona = ref.read(userPersonaProvider);
    final now = DateTime.now();

    // 1. Update casting call applicant count (application status is stored per applicant in applications)
    final updatedCalls = state.calls.map((call) {
      if (call.id == callId) {
        return call.copyWith(
          isApplied: false,
          applicantsCount: call.applicantsCount + 1,
        );
      }
      return call;
    }).toList();

    // 2. Create new application
    final call = state.calls.firstWhere((c) => c.id == callId);
    final newApp = CastingApplicationModel(
      id: 'app_${now.millisecondsSinceEpoch}',
      castingCallId: callId,
      projectTitle: call.projectTitle,
      applicantId: activePersona.id,
      applicantName: activePersona.name.isNotEmpty
          ? activePersona.name
          : 'Applicant',
      applicantAvatar: activePersona.avatarUrl,
      appliedAt: 'Just Now',
      appliedDateTime: now,
      contactNumber: contactNumber,
      contactEmail: contactEmail,
      age: '23',
      height: '5.9 Feet',
      gender: 'Male',
      experience: activePersona.experience.isNotEmpty
          ? activePersona.experience
          : '5 Years',
      location: activePersona.location.isNotEmpty
          ? activePersona.location
          : 'Islamabad, Pakistan',
      note: note,
      status: ApplicationStatus.received,
    );

    final updatedApps = [newApp, ...state.applications];

    state = state.copyWith(calls: updatedCalls, applications: updatedApps);
    _saveCalls(updatedCalls);
    _saveApps(updatedApps);

    // Full-stack sync: attempt to save application on Supabase
    try {
      final repo = ref.read(castingRepositoryProvider);
      await repo.submitApplication(newApp);
    } catch (_) {}
  }

  /// Create a new casting call
  Future<void> createCastingCall(CastingCallModel newCall) async {
    final updatedCalls = [newCall, ...state.calls];
    state = state.copyWith(calls: updatedCalls);
    _saveCalls(updatedCalls);

    // Full-stack sync: attempt to persist on Supabase
    try {
      final repo = ref.read(castingRepositoryProvider);
      await repo.createCastingCall(newCall);
    } catch (_) {}
  }

  /// Delete a casting call
  Future<void> deleteCastingCall(String callId) async {
    final updatedCalls = state.calls.where((c) => c.id != callId).toList();
    final updatedApps =
        state.applications.where((a) => a.castingCallId != callId).toList();

    state = state.copyWith(calls: updatedCalls, applications: updatedApps);
    _saveCalls(updatedCalls);
    _saveApps(updatedApps);

    // Full-stack sync: mark deleted on Supabase
    try {
      final repo = ref.read(castingRepositoryProvider);
      await repo.deleteCastingCall(callId);
    } catch (_) {}
  }

  /// Update application status (Accept / Reject) with in-app notification trigger!
  Future<void> updateApplicationStatus(
    String applicationId,
    ApplicationStatus newStatus,
  ) async {
    CastingApplicationModel? targetApp;

    final updatedApps = state.applications.map((app) {
      if (app.id == applicationId) {
        targetApp = app.copyWith(status: newStatus);
        return targetApp!;
      }
      return app;
    }).toList();

    state = state.copyWith(applications: updatedApps);
    _saveApps(updatedApps);

    // Full-stack sync to Supabase
    try {
      final repo = ref.read(castingRepositoryProvider);
      await repo.updateApplicationStatus(applicationId, newStatus.name);
    } catch (_) {}

    // Trigger in-app notification when an application is accepted
    if (newStatus == ApplicationStatus.accepted && targetApp != null) {
      try {
        final creator = ref.read(userPersonaProvider);
        final notifRepo = ref.read(notificationRepositoryProvider);

        await notifRepo.sendNotification(
          recipientId: targetApp!.applicantId,
          actorId: creator.id,
          type: NotificationType.castingApplication,
          primarySubject: creator.name.isNotEmpty ? creator.name : 'Creator',
          actionText: 'accepted your application for',
          targetObject: targetApp!.projectTitle,
          avatarUrl: creator.avatarUrl,
          isCastingIcon: true,
          entityType: 'casting_call',
          entityId: targetApp!.castingCallId,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Notice triggering notification: $e');
      }
    }
  }

  /// Toggle bookmark / wishlist status for an applicant
  Future<void> toggleWishlist(String applicationId) async {
    bool nextWish = false;
    final updatedApps = state.applications.map((app) {
      if (app.id == applicationId) {
        nextWish = !app.isWishlisted;
        return app.copyWith(
          isWishlisted: nextWish,
          status: nextWish ? ApplicationStatus.wishlisted : ApplicationStatus.received,
        );
      }
      return app;
    }).toList();

    state = state.copyWith(applications: updatedApps);
    _saveApps(updatedApps);

    try {
      final repo = ref.read(castingRepositoryProvider);
      await repo.updateApplicationStatus(
        applicationId,
        nextWish ? ApplicationStatus.wishlisted.name : ApplicationStatus.received.name,
        isWishlisted: nextWish,
      );
    } catch (_) {}
  }

  /// Check whether a call was applied by a specific user persona
  bool isCallAppliedBy(String callId, String userId) {
    return state.applications.any(
      (a) =>
          a.castingCallId == callId &&
          (a.applicantId == userId ||
              AppPersistenceService.instance.isSamePersona(a.applicantId, userId)),
    );
  }

  /// Get the applied date string for a specific user persona
  String? getAppliedAt(String callId, String userId) {
    try {
      final app = state.applications.firstWhere(
        (a) =>
            a.castingCallId == callId &&
            (a.applicantId == userId ||
                AppPersistenceService.instance.isSamePersona(a.applicantId, userId)),
      );
      return app.appliedAt;
    } catch (_) {
      return null;
    }
  }

  List<CastingCallModel> get allCalls =>
      state.calls.where((c) => !c.isDeleted).toList();

  /// Retrieve calls applied by a specific user persona
  List<CastingCallModel> getAppliedCalls(String userId) {
    final userAppliedMap = <String, String>{};
    for (final a in state.applications) {
      if (a.applicantId == userId ||
          AppPersistenceService.instance.isSamePersona(a.applicantId, userId)) {
        userAppliedMap[a.castingCallId] = a.appliedAt;
      }
    }

    return state.calls
        .where((c) => !c.isDeleted && userAppliedMap.containsKey(c.id))
        .map((c) => c.copyWith(
              isApplied: true,
              appliedAt: userAppliedMap[c.id],
            ))
        .toList();
  }

  /// Active persona applied calls
  List<CastingCallModel> get appliedCalls {
    final activePersona = ref.read(userPersonaProvider);
    return getAppliedCalls(activePersona.id);
  }

  /// Retrieve calls created by current user
  List<CastingCallModel> getMyCalls(String currentUserId) {
    final activePersona = ref.read(userPersonaProvider);
    return state.calls
        .where((c) =>
            !c.isDeleted &&
            (c.authorId == currentUserId ||
                c.authorId == activePersona.id ||
                c.authorName == activePersona.name ||
                AppPersistenceService.instance.isSamePersona(c.authorId, currentUserId) ||
                AppPersistenceService.instance.isSamePersona(c.authorId, activePersona.id)))
        .toList();
  }

  /// Retrieve applications for a specific call with optional status filter
  List<CastingApplicationModel> getApplicationsForCall(
    String callId, [
    ApplicationStatus? statusFilter,
  ]) {
    return state.applications.where((a) {
      final matchesCall = a.castingCallId == callId ||
          (callId.startsWith('call_') && a.castingCallId == 'my_call_1');
      if (!matchesCall) return false;
      if (statusFilter != null) {
        return a.status == statusFilter;
      }
      return true;
    }).toList();
  }

  /// Search and filter casting calls feed
  List<CastingCallModel> searchAndFilterCalls({
    String query = '',
    String selectedCity = 'All',
    String selectedType = 'All',
  }) {
    return state.calls.where((c) {
      if (c.isDeleted) return false;

      // Query check (title, position, description, author)
      if (query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchesQuery = c.projectTitle.toLowerCase().contains(q) ||
            c.authorName.toLowerCase().contains(q) ||
            c.position.toLowerCase().contains(q) ||
            c.location.toLowerCase().contains(q) ||
            c.description.toLowerCase().contains(q);
        if (!matchesQuery) return false;
      }

      // City filter
      if (selectedCity != 'All') {
        if (!c.location.toLowerCase().contains(selectedCity.toLowerCase()) &&
            !c.locationDisplay.toLowerCase().contains(selectedCity.toLowerCase())) {
          return false;
        }
      }

      // Role type filter
      if (selectedType != 'All') {
        if (!c.type.toLowerCase().contains(selectedType.toLowerCase()) &&
            !c.position.toLowerCase().contains(selectedType.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();
  }

}

final castingProvider =
    NotifierProvider<CastingNotifier, CastingState>(CastingNotifier.new);
