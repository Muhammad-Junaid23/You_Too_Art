import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/repositories/connection_repository.dart';
import 'package:you_too_art/features/network/providers/network_provider.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/chats/providers/chat_provider.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';

class TalentState {
  final List<TalentModel> talents;
  final bool isLoading;
  final String searchQuery;
  final String? errorMessage;

  const TalentState({
    this.talents = const [],
    this.isLoading = false,
    this.searchQuery = '',
    this.errorMessage,
  });

  TalentState copyWith({
    List<TalentModel>? talents,
    bool? isLoading,
    String? searchQuery,
    String? errorMessage,
  }) {
    return TalentState(
      talents: talents ?? this.talents,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }

  List<TalentModel> get filteredTalents {
    if (searchQuery.trim().isEmpty) {
      return talents;
    }
    final query = searchQuery.trim().toLowerCase();
    return talents.where((talent) {
      final nameMatches = talent.name.toLowerCase().contains(query);
      final roleMatches = talent.roles.toLowerCase().contains(query);
      return nameMatches || roleMatches;
    }).toList();
  }

  TalentModel? findById(String id) {
    try {
      return talents.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

class TalentNotifier extends Notifier<TalentState> {
  late ConnectionRepository _connectionRepo;
  late UserPersona _activePersona;
  StreamSubscription<void>? _connSub;

  @override
  TalentState build() {
    ref.watch(currentUidProvider);
    _connectionRepo = ref.watch(connectionRepositoryProvider);
    _activePersona = ref.watch(userPersonaProvider);

    _connSub?.cancel();
    _connSub = ConnectionRepository.connectionChanges.listen((_) {
      fetchTalents();
    });
    ref.onDispose(() {
      _connSub?.cancel();
    });

    Future.microtask(() => fetchTalents());
    return const TalentState(isLoading: true);
  }

  Future<void> fetchTalents() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final actorPersona = UserPersonaNotifier.buildActorPersona();
      final followingIds =
          await _connectionRepo.getFollowingIds(_activePersona.id);

      // Fetch users from Supabase if table exists
      List<TalentModel> fetchedList = [];
      try {
        final client = ref.read(supabaseClientProvider);
        final response =
            await client.from(SupabaseTables.users).select().limit(50);
        final list = response as List;
        if (list.isNotEmpty) {
          fetchedList = list.map((data) {
            final user = UserModel.fromJson(data as Map<String, dynamic>);
            return TalentModel.fromUser(user);
          }).where((t) {
            final n = t.name.toLowerCase().trim();
            final isFake = n.contains('sara ahmed') ||
                n.contains('bilal tariq') ||
                n.contains('jeremiah') ||
                t.id == 'c3333333-3333-3333-3333-333333333333' ||
                t.id == 'd4444444-4444-4444-4444-444444444444';
            return !isFake;
          }).toList();
        }
      } catch (_) {}

      // Pure real talents directory from registered users and platform personas
      final combined = <TalentModel>[];
      for (final fetched in fetchedList) {
        final n = fetched.name.toLowerCase().trim();
        if (n.contains('sara ahmed') ||
            n.contains('bilal tariq') ||
            fetched.id == 'c3333333-3333-3333-3333-333333333333' ||
            fetched.id == 'd4444444-4444-4444-4444-444444444444') {
          continue;
        }
        if (UserPersonaNotifier.hasPersona(fetched.id)) {
          final p = UserPersonaNotifier.getPersonaById(fetched.id);
          combined.add(TalentModel.fromPersona(p));
        } else {
          combined.add(fetched);
        }
      }

      // Filter out active persona (cannot discover yourself)
      final filteredForSelf = combined
          .where((t) =>
              !UserPersonaNotifier.isSamePersona(t.id, _activePersona.id))
          .toList();

      // Resolve relationship status for all talents with active persona in one batch
      final relMap =
          await _connectionRepo.getAllRelationshipStatuses(_activePersona.id);

      final resolvedTalents = <TalentModel>[];
      for (final talent in filteredForSelf) {
        String rel = relMap[talent.id] ?? 'none';
        if (rel == 'none' &&
            (talent.id == UserPersonaNotifier.actorDefaultId ||
                talent.id == actorPersona.id)) {
          rel = relMap[UserPersonaNotifier.actorDefaultId] ??
              relMap[actorPersona.id] ??
              'none';
        }

        ConnectionStatus status = ConnectionStatus.none;
        if (rel == 'accepted') {
          status = ConnectionStatus.connected;
        } else if (rel == 'pending_outgoing') {
          status = ConnectionStatus.pendingOutgoing;
        } else if (rel == 'pending_incoming') {
          status = ConnectionStatus.pendingIncoming;
        }

        final isFol = followingIds.contains(talent.id);
        final folCount = await _connectionRepo.getFollowersCount(talent.id);
        resolvedTalents.add(
          talent.copyWith(
            connectionStatus: status,
            isFollowing: isFol,
            followersCount: folCount > 0 ? folCount.toString() : (isFol ? '1' : '0'),
          ),
        );
      }

      state = state.copyWith(
        talents: resolvedTalents,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        talents: [],
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Send a connection request from active persona to target talent
  Future<void> sendConnectionRequest(String talentId) async {
    _updateStatus(talentId, ConnectionStatus.pendingOutgoing);
    await _connectionRepo.sendConnectionRequest(
      userId: _activePersona.id,
      targetUserId: talentId,
    );
    ref.read(networkProvider.notifier).refresh();
  }

  /// Accept a connection request (only when received from that person)
  Future<void> acceptConnection(String talentId) async {
    _updateStatus(talentId, ConnectionStatus.connected);
    await _connectionRepo.acceptConnection(
      userId: _activePersona.id,
      senderUserId: talentId,
    );
    ref.read(networkProvider.notifier).refresh();
    ref.read(chatListProvider.notifier).refreshConnections();
  }

  /// Cancel/withdraw request or remove existing connection (returns to none)
  Future<void> removeConnection(String talentId) async {
    _updateStatus(talentId, ConnectionStatus.none);
    await _connectionRepo.removeConnection(
      userId: _activePersona.id,
      connectedUserId: talentId,
    );
    ref.read(networkProvider.notifier).refresh();
    ref.read(chatListProvider.notifier).refreshConnections();
  }

  /// Toggle connection status cleanly:
  /// - none -> send request (status becomes pendingOutgoing "Request Sent")
  /// - pendingIncoming -> accept request (status becomes connected "Connected")
  /// - pendingOutgoing -> cancel request (status returns to none "Connect")
  /// - connected -> remove connection (status returns to none "Connect")
  Future<void> toggleConnection(String talentId) async {
    final talent = state.findById(talentId);
    if (talent == null) return;

    if (talent.connectionStatus == ConnectionStatus.none) {
      await sendConnectionRequest(talentId);
    } else if (talent.connectionStatus == ConnectionStatus.pendingIncoming) {
      // Accepting incoming request
      await acceptConnection(talentId);
    } else if (talent.connectionStatus == ConnectionStatus.pendingOutgoing) {
      // Withdrawing / cancelling our pending request
      await removeConnection(talentId);
    } else {
      // Removing mutual connection
      await removeConnection(talentId);
    }
  }

  /// Toggle Follow / Unfollow for production houses
  Future<void> toggleFollow(String productionId) async {
    final updatedTalents = state.talents.map((talent) {
      if (talent.id == productionId) {
        final nextFollowing = !talent.isFollowing;
        final currentCount = int.tryParse(talent.followersCount) ?? 0;
        final nextCount = nextFollowing
            ? currentCount + 1
            : (currentCount - 1).clamp(0, 999999);
        return talent.copyWith(
          isFollowing: nextFollowing,
          followersCount: nextCount.toString(),
        );
      }
      return talent;
    }).toList();

    state = state.copyWith(talents: updatedTalents);
    await _connectionRepo.toggleFollowing(_activePersona.id, productionId);
    ref.read(networkProvider.notifier).refresh();
    ConnectionRepository.notifyChanges();
  }

  void _updateStatus(String talentId, ConnectionStatus status) {
    final updatedTalents = state.talents.map((talent) {
      if (talent.id == talentId) {
        return talent.copyWith(connectionStatus: status);
      }
      return talent;
    }).toList();

    state = state.copyWith(talents: updatedTalents);
  }
}

final talentListProvider = NotifierProvider<TalentNotifier, TalentState>(() {
  return TalentNotifier();
});
