import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/core/constants/talent_directory.dart';
import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/repositories/connection_repository.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/network/models/network_item.dart';
import 'package:you_too_art/features/chats/providers/chat_provider.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';
import 'package:you_too_art/features/talent/providers/talent_provider.dart';

class NetworkState {
  final int activeTab; // 0 for Requests, 1 for Connections
  final List<ConnectionRequestItem> requests;
  final List<ConnectionItem> connections;
  final List<NetworkSuggestionItem> suggestions;
  final List<NetworkSuggestionItem> recommendations;
  final String searchQuery;
  final bool isLoading;

  const NetworkState({
    this.activeTab = 0,
    this.requests = const [],
    this.connections = const [],
    this.suggestions = const [],
    this.recommendations = const [],
    this.searchQuery = '',
    this.isLoading = false,
  });

  NetworkState copyWith({
    int? activeTab,
    List<ConnectionRequestItem>? requests,
    List<ConnectionItem>? connections,
    List<NetworkSuggestionItem>? suggestions,
    List<NetworkSuggestionItem>? recommendations,
    String? searchQuery,
    bool? isLoading,
  }) {
    return NetworkState(
      activeTab: activeTab ?? this.activeTab,
      requests: requests ?? this.requests,
      connections: connections ?? this.connections,
      suggestions: suggestions ?? this.suggestions,
      recommendations: recommendations ?? this.recommendations,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<ConnectionItem> get filteredConnections {
    if (searchQuery.trim().isEmpty) {
      return connections;
    }
    final query = searchQuery.trim().toLowerCase();
    return connections.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.roles.toLowerCase().contains(query);
    }).toList();
  }
}

class NetworkNotifier extends Notifier<NetworkState> {
  late ConnectionRepository _connectionRepo;
  late UserPersona _activePersona;
  StreamSubscription<void>? _connSub;

  @override
  NetworkState build() {
    ref.watch(currentUidProvider);
    _connectionRepo = ref.watch(connectionRepositoryProvider);
    _activePersona = ref.watch(userPersonaProvider);

    _connSub?.cancel();
    _connSub = ConnectionRepository.connectionChanges.listen((_) {
      _loadNetworkData();
    });
    ref.onDispose(() {
      _connSub?.cancel();
    });

    Future.microtask(() => _loadNetworkData());
    return const NetworkState(isLoading: true);
  }

  void refresh() {
    _loadNetworkData();
  }

  TalentModel _resolveTalent(String id) {
    if (UserPersonaNotifier.hasPersona(id)) {
      final persona = UserPersonaNotifier.getPersonaById(id);
      return TalentModel.fromPersona(persona);
    }

    if (UserPersonaNotifier.isActorId(id)) {
      final persona = UserPersonaNotifier.getActorPersona();
      return TalentModel.fromPersona(persona);
    }

    final direct = TalentDirectory.findById(id);
    if (direct != null &&
        direct.name != 'Artist' &&
        direct.name != 'Creative Artist') {
      return direct;
    }

    try {
      final fromTalentList = ref.read(talentListProvider).findById(id);
      if (fromTalentList != null) {
        return fromTalentList;
      }
    } catch (_) {}

    return TalentModel(
      id: id,
      name: 'Artist',
      roles: 'Performing Artist',
      avatarUrl: '',
      bio: 'Artist on You Too Art.',
    );
  }

  Future<void> _loadNetworkData() async {
    if (_activePersona.id.trim().isEmpty) {
      state = const NetworkState(isLoading: false);
      return;
    }

    // 1. Fetch incoming requests
    final incomingRaw =
        await _connectionRepo.fetchIncomingRequests(_activePersona.id);

    // 2. Fetch accepted connections
    final acceptedRaw =
        await _connectionRepo.fetchAcceptedConnections(_activePersona.id);

    // Asynchronously resolve real profiles from Supabase for any unknown UUIDs
    final allPeerIds = <String>{
      for (final r in incomingRaw) r['user_id'] as String,
      for (final a in acceptedRaw)
        (a['user_id'] == _activePersona.id
            ? a['connected_user_id']
            : a['user_id']) as String,
    };

    for (final pid in allPeerIds) {
      if (ConnectionRepository.isValidUuid(pid) &&
          !UserPersonaNotifier.hasPersona(pid)) {
        try {
          final client = ref.read(supabaseClientProvider);
          final row =
              await client.from('users').select().eq('id', pid).maybeSingle();
          if (row != null) {
            final u = UserModel.fromJson(row);
            final persona = UserPersona(
              id: u.id,
              name: u.name.isNotEmpty
                  ? u.name
                  : (u.firstName.isNotEmpty
                      ? '${u.firstName} ${u.lastName}'.trim()
                      : 'Artist'),
              email: u.email,
              role: u.role != 'unset' ? u.role : 'Artist',
              avatarUrl: u.profileImagePath ?? '',
              bio: u.bio ?? '',
              location: u.location ?? '',
            );
            AppPersistenceService.instance.savePersona(persona);
          }
        } catch (_) {}
      }
    }

    final requestItems = incomingRaw.map((row) {
      final senderId = row['user_id'] as String;
      final talent = _resolveTalent(senderId);
      return ConnectionRequestItem(
        id: senderId,
        name: talent.name,
        roles: talent.roles,
        avatarUrl: talent.avatarUrl,
        talentModel:
            talent.copyWith(connectionStatus: ConnectionStatus.pendingIncoming),
      );
    }).toList();

    final connectionItems = acceptedRaw.map((row) {
      final senderId = row['user_id'] as String;
      final targetId = row['connected_user_id'] as String;
      final peerId = senderId == _activePersona.id ? targetId : senderId;
      final talent = _resolveTalent(peerId);

      return ConnectionItem(
        id: peerId,
        name: talent.name,
        roles: talent.roles,
        avatarUrl: talent.avatarUrl,
        connectedTimeAgo: 'Connected',
        talentModel:
            talent.copyWith(connectionStatus: ConnectionStatus.connected),
      );
    }).toList();

    // 3. Suggestions from real registered users in Supabase
    final connectedIds = connectionItems.map((c) => c.id).toSet();
    final requestedIds = requestItems.map((r) => r.id).toSet();

    final candidateMap = <String, TalentModel>{};
    try {
      final client = ref.read(supabaseClientProvider);
      var query = client.from(SupabaseTables.users).select();
      if (_activePersona.id.isNotEmpty &&
          ConnectionRepository.isValidUuid(_activePersona.id)) {
        query = query.neq('id', _activePersona.id);
      }
      final response = await query.limit(20);
      final list = response as List;
      for (final data in list) {
        final u = UserModel.fromJson(data as Map<String, dynamic>);
        final name = '${u.firstName} ${u.lastName} ${u.name}'.toLowerCase().trim();
        if (name.contains('sara ahmed') ||
            name.contains('bilal tariq') ||
            u.id == 'c3333333-3333-3333-3333-333333333333' ||
            u.id == 'd4444444-4444-4444-4444-444444444444') {
          continue;
        }
        if (!UserPersonaNotifier.isSamePersona(u.id, _activePersona.id) &&
            !connectedIds.contains(u.id) &&
            !requestedIds.contains(u.id)) {
          final t = TalentModel.fromUser(u);
          candidateMap[t.id] = t;
        }
      }
    } catch (_) {}

    final candidateTalents = candidateMap.values.toList();

    final followingIds =
        await _connectionRepo.getFollowingIds(_activePersona.id);

    final suggestions = <NetworkSuggestionItem>[];
    for (final talent in candidateTalents) {
      final rel = await _connectionRepo.getRelationshipStatus(
        currentUserId: _activePersona.id,
        targetUserId: talent.id,
      );
      final isReq = rel == 'pending_outgoing';
      final isFol = followingIds.contains(talent.id);
      suggestions.add(
        NetworkSuggestionItem(
          id: talent.id,
          name: talent.name,
          roles: talent.roles,
          avatarUrl: talent.avatarUrl,
          isRequested: isReq,
          isFollowing: isFol,
          talentModel: talent.copyWith(
            isFollowing: isFol,
            connectionStatus: isReq
                ? ConnectionStatus.pendingOutgoing
                : (rel == 'accepted'
                    ? ConnectionStatus.connected
                    : ConnectionStatus.none),
          ),
        ),
      );
    }

    state = state.copyWith(
      activeTab: state.activeTab,
      requests: requestItems,
      connections: connectionItems,
      suggestions: suggestions,
      recommendations: const [],
      isLoading: false,
    );
  }

  void setActiveTab(int index) {
    state = state.copyWith(activeTab: index);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Accept an incoming connection request
  Future<void> acceptRequest(String senderUserId) async {
    final talent = _resolveTalent(senderUserId);

    final updatedRequests =
        state.requests.where((r) => r.id != senderUserId).toList();

    final newConnection = ConnectionItem(
      id: senderUserId,
      name: talent.name,
      avatarUrl: talent.avatarUrl,
      roles: talent.roles,
      connectedTimeAgo: 'Connected, Just now',
      talentModel: talent.copyWith(connectionStatus: ConnectionStatus.connected),
    );

    final updatedConnections = [newConnection, ...state.connections];

    state = state.copyWith(
      requests: updatedRequests,
      connections: updatedConnections,
    );

    await _connectionRepo.acceptConnection(
      userId: _activePersona.id,
      senderUserId: senderUserId,
    );

    ref.read(talentListProvider.notifier).fetchTalents();
    ref.read(chatListProvider.notifier).refreshConnections();
  }

  /// Decline an incoming connection request
  Future<void> declineRequest(String senderUserId) async {
    final updatedRequests =
        state.requests.where((r) => r.id != senderUserId).toList();
    state = state.copyWith(requests: updatedRequests);

    await _connectionRepo.declineConnection(
      userId: _activePersona.id,
      senderUserId: senderUserId,
    );

    ref.read(talentListProvider.notifier).fetchTalents();
    ref.read(chatListProvider.notifier).refreshConnections();
  }

  /// Remove an existing connection
  Future<void> removeConnection(String connectionId) async {
    final updatedConnections =
        state.connections.where((c) => c.id != connectionId).toList();
    state = state.copyWith(connections: updatedConnections);

    await _connectionRepo.removeConnection(
      userId: _activePersona.id,
      connectedUserId: connectionId,
    );

    ref.read(talentListProvider.notifier).fetchTalents();
    ref.read(chatListProvider.notifier).refreshConnections();
  }

  /// Toggle sending a connection request or following a suggested user
  Future<void> toggleSendSuggestionRequest(String targetUserId) async {
    final existing = [...state.suggestions, ...state.recommendations]
        .firstWhere((s) => s.id == targetUserId);

    if (existing.isProductionHouse) {
      final newFollowing = !existing.isFollowing;
      final updatedSuggestions = state.suggestions.map((s) {
        if (s.id == targetUserId) {
          final currentCount = int.tryParse(s.talentModel.followersCount) ?? 0;
          final nextCount = newFollowing
              ? currentCount + 1
              : (currentCount - 1).clamp(0, 999999);
          return s.copyWith(
            isFollowing: newFollowing,
            talentModel: s.talentModel.copyWith(
              isFollowing: newFollowing,
              followersCount: nextCount.toString(),
            ),
          );
        }
        return s;
      }).toList();

      state = state.copyWith(suggestions: updatedSuggestions);
      await _connectionRepo.toggleFollowing(_activePersona.id, targetUserId);
      ref.read(talentListProvider.notifier).fetchTalents();
      return;
    }

    final newStatus = !existing.isRequested;

    final updatedSuggestions = state.suggestions.map((s) {
      if (s.id == targetUserId) {
        return s.copyWith(
          isRequested: newStatus,
          talentModel: s.talentModel.copyWith(
            connectionStatus: newStatus
                ? ConnectionStatus.pendingOutgoing
                : ConnectionStatus.none,
          ),
        );
      }
      return s;
    }).toList();

    final updatedRecommendations = state.recommendations.map((r) {
      if (r.id == targetUserId) {
        return r.copyWith(
          isRequested: newStatus,
          talentModel: r.talentModel.copyWith(
            connectionStatus: newStatus
                ? ConnectionStatus.pendingOutgoing
                : ConnectionStatus.none,
          ),
        );
      }
      return r;
    }).toList();

    state = state.copyWith(
      suggestions: updatedSuggestions,
      recommendations: updatedRecommendations,
    );

    if (newStatus) {
      await _connectionRepo.sendConnectionRequest(
        userId: _activePersona.id,
        targetUserId: targetUserId,
      );
    } else {
      await _connectionRepo.removeConnection(
        userId: _activePersona.id,
        connectedUserId: targetUserId,
      );
    }

    ref.read(talentListProvider.notifier).fetchTalents();
  }
}

final networkProvider = NotifierProvider<NetworkNotifier, NetworkState>(() {
  return NetworkNotifier();
});
