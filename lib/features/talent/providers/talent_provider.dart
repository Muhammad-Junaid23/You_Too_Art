import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/core/constants/talent_directory.dart';
import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/repositories/connection_repository.dart';
import 'package:you_too_art/features/network/providers/network_provider.dart';
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

  @override
  TalentState build() {
    _connectionRepo = ref.watch(connectionRepositoryProvider);
    _activePersona = ref.watch(userPersonaProvider);

    Future.microtask(() => fetchTalents());
    return const TalentState(isLoading: true);
  }

  Future<void> fetchTalents() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final actorPersona = UserPersonaNotifier.buildActorPersona();
      await _connectionRepo.ensureDefaultMockConnections(actorPersona.id);

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
          }).toList();
        }
      } catch (_) {}

      // Combine with curated sample talents from TalentDirectory
      final combined = <TalentModel>[...fetchedList];
      for (final sample in TalentDirectory.allCuratedTalents) {
        if (!combined.any((t) => t.id == sample.id)) {
          combined.add(sample);
        }
      }

      // Add Actor persona so if another persona is active, Actor is visible to connect with
      if (!combined.any((t) => t.id == actorPersona.id)) {
        combined.add(
          TalentModel(
            id: actorPersona.id,
            name: actorPersona.name,
            roles: actorPersona.role,
            avatarUrl: actorPersona.avatarUrl,
            email: actorPersona.email,
            bio: 'Professional actor and performing artist on You Too Art.',
            isProductionHouse: false,
          ),
        );
      }

      // Filter out active persona (cannot discover yourself)
      final filteredForSelf =
          combined.where((t) => t.id != _activePersona.id).toList();

      // Resolve relationship status for each talent with active persona
      final resolvedTalents = <TalentModel>[];
      for (final talent in filteredForSelf) {
        final rel = await _connectionRepo.getRelationshipStatus(
          currentUserId: _activePersona.id,
          targetUserId: talent.id,
        );

        ConnectionStatus status = ConnectionStatus.none;
        if (rel == 'accepted') {
          status = ConnectionStatus.connected;
        } else if (rel == 'pending_outgoing' || rel == 'pending_incoming') {
          status = ConnectionStatus.pending;
        }

        resolvedTalents.add(
          talent.copyWith(
            connectionStatus: status,
            isFollowing: followingIds.contains(talent.id),
          ),
        );
      }

      state = state.copyWith(
        talents: resolvedTalents,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        talents: TalentDirectory.allCuratedTalents
            .where((t) => t.id != _activePersona.id)
            .toList(),
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
    _updateStatus(talentId, ConnectionStatus.pending);
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
  }

  /// Cancel/withdraw request or remove existing connection (returns to none)
  Future<void> removeConnection(String talentId) async {
    _updateStatus(talentId, ConnectionStatus.none);
    await _connectionRepo.removeConnection(
      userId: _activePersona.id,
      connectedUserId: talentId,
    );
    ref.read(networkProvider.notifier).refresh();
  }

  /// Toggle connection status cleanly:
  /// - none -> send request (status becomes pending "Request Sent")
  /// - pending -> cancel request (status returns to none "Connect")
  /// - connected -> remove connection (status returns to none "Connect")
  Future<void> toggleConnection(String talentId) async {
    final talent = state.findById(talentId);
    if (talent == null) return;

    if (talent.connectionStatus == ConnectionStatus.none) {
      await sendConnectionRequest(talentId);
    } else if (talent.connectionStatus == ConnectionStatus.pending) {
      // Withdrawing / cancelling the pending request
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
        return talent.copyWith(isFollowing: !talent.isFollowing);
      }
      return talent;
    }).toList();

    state = state.copyWith(talents: updatedTalents);
    await _connectionRepo.toggleFollowing(_activePersona.id, productionId);
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
