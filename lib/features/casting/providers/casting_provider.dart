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

    // 3. Fallback: Seed defaults only if genuinely empty
    if (calls.isEmpty) {
      calls = _buildDefaultCalls();
    }

    if (apps.isEmpty) {
      apps = _buildDefaultApplications();
    }

    // Link application states so isApplied is always accurate
    final appliedCallIds = apps.map((a) => a.castingCallId).toSet();
    calls = calls.map((c) {
      if (c.isApplied) return c;
      if (appliedCallIds.contains(c.id)) {
        return c.copyWith(isApplied: true);
      }
      return c;
    }).toList();

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
            // Intelligent merge: NEVER lose locally applied status or higher local applicant count!
            callMap[rc.id] = rc.copyWith(
              isApplied: existing.isApplied || rc.isApplied,
              appliedAt: existing.appliedAt ?? rc.appliedAt,
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

        // Cross-verify application existence with call's isApplied flag
        final appliedCallIds = appMap.values.map((a) => a.castingCallId).toSet();
        final mergedCalls = callMap.values.where((c) => !c.isDeleted).map((c) {
          if (c.isApplied) return c;
          if (appliedCallIds.contains(c.id)) {
            return c.copyWith(isApplied: true);
          }
          return c;
        }).toList();

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

    // 1. Update casting call
    final updatedCalls = state.calls.map((call) {
      if (call.id == callId) {
        return call.copyWith(
          isApplied: true,
          appliedAt: 'Just Now',
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
          : 'Muhammad Ali Nizami',
      applicantAvatar: activePersona.avatarUrl.isNotEmpty
          ? activePersona.avatarUrl
          : 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
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
      (a) => a.castingCallId == callId && a.applicantId == userId,
    );
  }

  List<CastingCallModel> get allCalls =>
      state.calls.where((c) => !c.isDeleted).toList();

  List<CastingCallModel> get appliedCalls =>
      state.calls.where((c) => !c.isDeleted && c.isApplied).toList();

  /// Retrieve calls created by current user or defaults
  List<CastingCallModel> getMyCalls(String currentUserId) {
    final activePersona = ref.read(userPersonaProvider);
    final authored = state.calls
        .where((c) =>
            !c.isDeleted &&
            (c.authorId == currentUserId ||
                c.authorId == activePersona.id ||
                c.authorName == activePersona.name ||
                AppPersistenceService.instance.isSamePersona(c.authorId, currentUserId) ||
                AppPersistenceService.instance.isSamePersona(c.authorId, activePersona.id) ||
                c.authorName == 'FilmFare' ||
                c.authorId == 'my_call_1' ||
                c.id.startsWith('my_call_') ||
                c.authorId == 'current_user'))
        .toList();
    return authored.isNotEmpty
        ? authored
        : state.calls.where((c) => !c.isDeleted).take(2).toList();
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

  // ─── Figma Seed Data ──────────────────────────────────────────

  static List<CastingCallModel> _buildDefaultCalls() {
    return [
      CastingCallModel(
        id: 'call_1',
        projectTitle: 'The Next Short Film',
        authorId: 'james_geidt',
        authorName: 'James Geidt',
        authorAvatar:
            'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
        publishedDateStr: '24th April, 2023',
        publishedAt: DateTime(2023, 4, 24),
        description: 'A story of 6 young software engineers at Islamabad.',
        location: 'Islamabad, Pakistan',
        locationDisplay: 'Islamabad',
        type: 'Short Film',
        shootDuration: '25 Days',
        budget: '\$20K',
        budgetFull: '\$20,000',
        crewRequired: '1',
        shootDetails:
            'Shoot will be of 30 days at the Centaurus Mall Islamabad.',
        position: 'A Software Engineer in Islamabad',
        ageRequired: '23 Years',
        heightRequired: '5.9 Feet',
        gender: 'Male Only',
        contactEmail: 'james.geidt@production.test',
        contactNumber: '+92 332 02522110',
        applicantsCount: 520,
        isApplied: true,
        appliedAt: '2 Days Ago',
      ),
      CastingCallModel(
        id: 'call_2',
        projectTitle: 'The Next Short Film',
        authorId: 'angel_culhane',
        authorName: 'Angel Culhane',
        authorAvatar:
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
        publishedDateStr: '20th April, 2023',
        publishedAt: DateTime(2023, 4, 20),
        description:
            'Exciting indie drama looking for dynamic character actors.',
        location: 'Islamabad, Pakistan',
        locationDisplay: 'Islamabad',
        type: 'Short Film',
        shootDuration: '25 Days',
        budget: '\$20K',
        budgetFull: '\$20,000',
        crewRequired: '2',
        shootDetails:
            'Filming in natural lighting across Islamabad outdoor locations.',
        position: 'Supporting Actor',
        ageRequired: '24 Years',
        heightRequired: '5.10 Feet',
        gender: 'Male Only',
        contactEmail: 'angel.culhane@production.test',
        contactNumber: '+92 300 1234567',
        applicantsCount: 310,
        isApplied: false,
      ),
      CastingCallModel(
        id: 'call_3',
        projectTitle: 'The Next Short Film',
        authorId: 'angel_culhane_2',
        authorName: 'Angel Culhane',
        authorAvatar:
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
        publishedDateStr: '18th April, 2023',
        publishedAt: DateTime(2023, 4, 18),
        description:
            'Contemporary web series pilot seeking expressive new faces.',
        location: 'Islamabad, Pakistan',
        locationDisplay: 'Islamabad',
        type: 'Short Film',
        shootDuration: '25 Days',
        budget: '\$20K',
        budgetFull: '\$20,000',
        crewRequired: '1',
        shootDetails: 'Studio lot soundstage filming in Islamabad.',
        position: 'Secondary Actor',
        ageRequired: '22 Years',
        heightRequired: '5.9 Feet',
        gender: 'Any',
        contactEmail: 'angel.culhane@production.test',
        contactNumber: '+92 300 9876543',
        applicantsCount: 184,
        isApplied: false,
      ),
      CastingCallModel(
        id: 'my_call_1',
        projectTitle: 'The Next Short Film',
        authorId: 'filmfare',
        authorName: 'FilmFare',
        authorAvatar:
            'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
        publishedDateStr: '2 Days Ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
        description: 'A story of 6 young software engineers at Islamabad.',
        location: 'Islamabad, Pakistan',
        locationDisplay: 'Islamabad',
        type: 'Short Film',
        shootDuration: '25 Days',
        budget: '\$20K',
        budgetFull: '\$20,000',
        crewRequired: '1',
        shootDetails:
            'Shoot will be of 30 days at the Centaurus Mall Islamabad.',
        position: 'A Software Engineer in Islamabad',
        ageRequired: '23 Years',
        heightRequired: '5.9 Feet',
        gender: 'Male Only',
        contactEmail: 'filmfare.studio@youtooart.test',
        contactNumber: '+92 332 02522110',
        roleTitle: 'Software Engineer Lead',
        roleDescription: 'Protagonist working on disruptive AI startup.',
        applicantsCount: 520,
        isApplied: false,
      ),
    ];
  }

  static List<CastingApplicationModel> _buildDefaultApplications() {
    return [
      CastingApplicationModel(
        id: 'app_1',
        castingCallId: 'my_call_1',
        projectTitle: 'The Next Short Film',
        applicantId: 'muhammad_ali',
        applicantName: 'Muhammad Ali Nizami',
        applicantAvatar:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
        appliedAt: '1 Day Ago',
        appliedDateTime: DateTime.now().subtract(const Duration(days: 1)),
        contactNumber: '+92 332 02522110',
        contactEmail: 'muhammadali@gmail.com',
        age: '23',
        height: '5.9 Feet',
        gender: 'Male',
        experience: '5 Years',
        location: 'Islamabad, Pakistan',
        note: 'Shoot will be of 30 days at the Centaurus Mall Islamabad.',
        status: ApplicationStatus.received,
        isWishlisted: false,
      ),
      CastingApplicationModel(
        id: 'app_2',
        castingCallId: 'my_call_1',
        projectTitle: 'The Next Short Film',
        applicantId: 'hamza_tariq',
        applicantName: 'Hamza Tariq',
        applicantAvatar:
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
        appliedAt: '2 Days Ago',
        appliedDateTime: DateTime.now().subtract(const Duration(days: 2)),
        contactNumber: '+92 300 1234567',
        contactEmail: 'hamza.tariq@gmail.com',
        age: '24',
        height: '5.10 Feet',
        gender: 'Male',
        experience: '3 Years',
        location: 'Lahore, Pakistan',
        note: 'Ready for audition reel submission anytime.',
        status: ApplicationStatus.received,
        isWishlisted: false,
      ),
      CastingApplicationModel(
        id: 'app_3',
        castingCallId: 'my_call_1',
        projectTitle: 'The Next Short Film',
        applicantId: 'zainab_khan',
        applicantName: 'Zainab Khan',
        applicantAvatar:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
        appliedAt: '3 Days Ago',
        appliedDateTime: DateTime.now().subtract(const Duration(days: 3)),
        contactNumber: '+92 312 9876543',
        contactEmail: 'zainab.k@gmail.com',
        age: '22',
        height: '5.6 Feet',
        gender: 'Female',
        experience: '2 Years',
        location: 'Islamabad, Pakistan',
        note: 'Passionate theater artist interested in lead role.',
        status: ApplicationStatus.rejected,
        isWishlisted: false,
      ),
      CastingApplicationModel(
        id: 'app_4',
        castingCallId: 'my_call_1',
        projectTitle: 'The Next Short Film',
        applicantId: 'daniyal_raza',
        applicantName: 'Daniyal Raza',
        applicantAvatar:
            'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=400&q=80',
        appliedAt: '4 Days Ago',
        appliedDateTime: DateTime.now().subtract(const Duration(days: 4)),
        contactNumber: '+92 333 4567890',
        contactEmail: 'daniyal.raza@gmail.com',
        age: '25',
        height: '6.0 Feet',
        gender: 'Male',
        experience: '4 Years',
        location: 'Islamabad, Pakistan',
        note: 'Strong character actor with commercial and drama experience.',
        status: ApplicationStatus.wishlisted,
        isWishlisted: true,
      ),
    ];
  }
}

final castingProvider =
    NotifierProvider<CastingNotifier, CastingState>(CastingNotifier.new);
