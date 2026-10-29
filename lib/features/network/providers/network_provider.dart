import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/core/constants/talent_directory.dart';
import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/repositories/connection_repository.dart';
import 'package:you_too_art/features/home/models/post_item.dart';
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
    final direct = TalentDirectory.findById(id);
    if (direct != null) return direct;

    if (UserPersonaNotifier.isActorId(id)) {
      final persona = UserPersonaNotifier.getActorPersona();
      return TalentModel.fromPersona(persona);
    }

    if (UserPersonaNotifier.hasPersona(id)) {
      final persona = UserPersonaNotifier.getPersonaById(id);
      return TalentModel.fromPersona(persona);
    }

    return TalentModel(
      id: id,
      name: 'Creative Artist',
      roles: 'Actor | Creator',
      avatarUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
      bio: 'Artist on You Too Art.',
      posts: [
        PostItem(
          id: 'post-$id',
          authorId: id,
          authorName: 'Creative Artist',
          authorAvatar:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
          caption: 'Exciting work on upcoming projects!',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
    );
  }

  Future<void> _loadNetworkData() async {
    // 1. Fetch incoming requests
    final incomingRaw =
        await _connectionRepo.fetchIncomingRequests(_activePersona.id);
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

    // 2. Fetch accepted connections
    final acceptedRaw =
        await _connectionRepo.fetchAcceptedConnections(_activePersona.id);
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
      final response = await client
          .from(SupabaseTables.users)
          .select()
          .neq('id', _activePersona.id)
          .limit(20);
      final list = response as List;
      for (final data in list) {
        final u = UserModel.fromJson(data as Map<String, dynamic>);
        if (!UserPersonaNotifier.isSamePersona(u.id, _activePersona.id) &&
            !connectedIds.contains(u.id) &&
            !requestedIds.contains(u.id)) {
          final t = TalentModel.fromUser(u);
          candidateMap[t.id] = t;
        }
      }
    } catch (_) {}
    final candidateTalents = candidateMap.values.toList();

    final suggestions = <NetworkSuggestionItem>[];
    for (final talent in candidateTalents) {
      final rel = await _connectionRepo.getRelationshipStatus(
        currentUserId: _activePersona.id,
        targetUserId: talent.id,
      );
      final isReq = rel == 'pending_outgoing';
      suggestions.add(
        NetworkSuggestionItem(
          id: talent.id,
          name: talent.name,
          roles: talent.roles,
          avatarUrl: talent.avatarUrl,
          isRequested: isReq,
          talentModel: talent.copyWith(
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

  /// Toggle sending a connection request to a suggested user
  Future<void> toggleSendSuggestionRequest(String targetUserId) async {
    final existing = [...state.suggestions, ...state.recommendations]
        .firstWhere((s) => s.id == targetUserId);

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
