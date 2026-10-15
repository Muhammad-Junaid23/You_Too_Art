import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/core/constants/talent_directory.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/repositories/connection_repository.dart';
import 'package:you_too_art/features/home/models/post_item.dart';
import 'package:you_too_art/features/network/models/network_item.dart';
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

  @override
  NetworkState build() {
    _connectionRepo = ref.watch(connectionRepositoryProvider);
    _activePersona = ref.watch(userPersonaProvider);

    Future.microtask(() => _loadNetworkData());
    return const NetworkState(isLoading: true);
  }

  void refresh() {
    _loadNetworkData();
  }

  TalentModel _resolveTalent(String id) {
    final direct = TalentDirectory.findById(id);
    if (direct != null) return direct;

    final actorPersona = UserPersonaNotifier.buildActorPersona();
    if (id == actorPersona.id) {
      return TalentModel(
        id: actorPersona.id,
        name: actorPersona.name,
        roles: actorPersona.role,
        avatarUrl: actorPersona.avatarUrl,
        email: actorPersona.email,
        bio: 'Professional performing artist on You Too Art.',
      );
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
    final actorPersona = UserPersonaNotifier.buildActorPersona();
    await _connectionRepo.ensureDefaultMockConnections(actorPersona.id);

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
        connectedTimeAgo: 'Connected, Yesterday',
        talentModel: talent.copyWith(connectionStatus: ConnectionStatus.connected),
      );
    }).toList();

    // 3. Suggestions using canonical talents from TalentDirectory
    final suggestionTemplates = [
      TalentDirectory.jeremiahGreen,
      TalentDirectory.sophiaVance,
      TalentDirectory.marcusChen,
    ].where((t) => t.id != _activePersona.id).toList();

    final suggestions = <NetworkSuggestionItem>[];
    for (final talent in suggestionTemplates) {
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

    // 4. Recommendations using canonical talents from TalentDirectory
    final recommendationTemplates = [
      TalentDirectory.elenaRostova,
      TalentDirectory.davidKalu,
      TalentDirectory.lucasScott,
    ].where((t) => t.id != _activePersona.id).toList();

    final recommendations = <NetworkSuggestionItem>[];
    for (final talent in recommendationTemplates) {
      final rel = await _connectionRepo.getRelationshipStatus(
        currentUserId: _activePersona.id,
        targetUserId: talent.id,
      );
      final isReq = rel == 'pending_outgoing';
      recommendations.add(
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
      recommendations: recommendations,
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
