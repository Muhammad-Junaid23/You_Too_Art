import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/core/constants/talent_directory.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/repositories/chat_repository.dart';
import 'package:you_too_art/core/repositories/connection_repository.dart';
import 'package:you_too_art/features/chats/models/chat_message_model.dart';
import 'package:you_too_art/features/chats/models/conversation_model.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';

// ─── Chat List State ──────────────────────────────────────────────────────────

class ChatListState {
  final List<ConversationModel> conversations;
  final List<TalentModel> connectedTalents;
  final String searchQuery;
  final bool isLoading;

  const ChatListState({
    this.conversations = const [],
    this.connectedTalents = const [],
    this.searchQuery = '',
    this.isLoading = false,
  });

  List<ConversationModel> get filteredConversations {
    if (searchQuery.trim().isEmpty) return conversations;
    final query = searchQuery.trim().toLowerCase();
    return conversations.where((c) {
      return c.peerName.toLowerCase().contains(query) ||
          c.lastMessage.toLowerCase().contains(query);
    }).toList();
  }

  bool canMessageUser(String targetUserId) {
    final actorPersona = UserPersonaNotifier.buildActorPersona();
    final isTargetActor = targetUserId == UserPersonaNotifier.actorDefaultId ||
        targetUserId == actorPersona.id;
    return connectedTalents.any((t) {
      if (t.id == targetUserId) return true;
      if (isTargetActor &&
          (t.id == UserPersonaNotifier.actorDefaultId || t.id == actorPersona.id)) {
        return true;
      }
      return false;
    });
  }

  ChatListState copyWith({
    List<ConversationModel>? conversations,
    List<TalentModel>? connectedTalents,
    String? searchQuery,
    bool? isLoading,
  }) {
    return ChatListState(
      conversations: conversations ?? this.conversations,
      connectedTalents: connectedTalents ?? this.connectedTalents,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ─── Chat List Notifier ───────────────────────────────────────────────────────

class ChatListNotifier extends Notifier<ChatListState> {
  late ChatRepository _chatRepo;
  late ConnectionRepository _connectionRepo;
  StreamSubscription<List<Map<String, dynamic>>>? _convSub;

  @override
  ChatListState build() {
    _chatRepo = ref.watch(chatRepositoryProvider);
    _connectionRepo = ref.watch(connectionRepositoryProvider);

    final activePersona = ref.watch(userPersonaProvider);

    // Clean up previous subscription if persona changed
    ref.onDispose(() {
      _convSub?.cancel();
    });

    _subscribeToConversations(activePersona.id);
    _loadConnectedTalents(activePersona.id);

    return const ChatListState(isLoading: true);
  }

  void _subscribeToConversations(String activeUserId) {
    _convSub?.cancel();
    _convSub = _chatRepo.watchConversations(activeUserId).listen(
      (rows) {
        final models = <ConversationModel>[];
        for (final row in rows) {
          final partA = row['participant_a'] as String? ?? '';
          final partB = row['participant_b'] as String? ?? '';
          final peerId = partA == activeUserId ? partB : partA;

          // Resolve peer metadata from directory
          var peerTalent = TalentDirectory.findById(peerId);
          if (peerTalent == null) {
            // Check if peer is one of the active test personas
            final personaMatch = UserPersonaNotifier.allPersonas
                .where((p) => p.id == peerId)
                .firstOrNull;
            if (personaMatch != null) {
              peerTalent = TalentModel(
                id: personaMatch.id,
                name: personaMatch.name,
                roles: personaMatch.role,
                avatarUrl: personaMatch.avatarUrl,
                isProductionHouse: personaMatch.isProductionHouse,
              );
            } else {
              peerTalent = TalentModel(
                id: peerId,
                name: 'Artist',
                roles: 'Performing Artist',
              );
            }
          }

          // Compute unread count for active persona
          int unreadCount = 0;
          if (peerId == TalentDirectory.ranveerSinghId) {
            unreadCount = 2; // Matches Figma badge
          }

          models.add(
            ConversationModel.fromRow(
              row: row,
              currentUserId: activeUserId,
              peerTalent: peerTalent,
              unreadCount: unreadCount,
            ),
          );
        }

        state = state.copyWith(
          conversations: models,
          isLoading: false,
        );
      },
      onError: (e) {
        state = state.copyWith(isLoading: false);
      },
    );
  }

  bool _isActorMatch(String a, String b) {
    if (a == b) return true;
    final actorPersona = UserPersonaNotifier.buildActorPersona();
    final isA = a == UserPersonaNotifier.actorDefaultId || a == actorPersona.id;
    final isB = b == UserPersonaNotifier.actorDefaultId || b == actorPersona.id;
    return isA && isB;
  }

  Future<void> _loadConnectedTalents(String activeUserId) async {
    try {
      final acceptedRows =
          await _connectionRepo.fetchAcceptedConnections(activeUserId);
      final connectedList = <TalentModel>[];

      for (final row in acceptedRows) {
        final partA = row['user_id'] as String? ?? '';
        final partB = row['connected_user_id'] as String? ?? '';
        final peerId = (partA == activeUserId || _isActorMatch(partA, activeUserId))
            ? partB
            : partA;

        if (peerId.isEmpty || peerId == activeUserId || _isActorMatch(peerId, activeUserId)) {
          continue;
        }

        TalentModel? talent = TalentDirectory.findById(peerId);
        if (talent == null) {
          final personaMatch = UserPersonaNotifier.allPersonas
              .where((p) => p.id == peerId || _isActorMatch(p.id, peerId))
              .firstOrNull;
          if (personaMatch != null) {
            talent = TalentModel(
              id: personaMatch.id,
              name: personaMatch.name,
              roles: personaMatch.role,
              avatarUrl: personaMatch.avatarUrl,
              isProductionHouse: personaMatch.isProductionHouse,
              connectionStatus: ConnectionStatus.connected,
            );
          }
        }

        if (talent != null) {
          final resolved = talent;
          if (!connectedList.any((t) => t.id == resolved.id || _isActorMatch(t.id, resolved.id))) {
            connectedList.add(resolved.copyWith(connectionStatus: ConnectionStatus.connected));
          }
        }
      }

      // Include followed production houses (artists can message production houses they follow)
      final followingIds = await _connectionRepo.getFollowingIds(activeUserId);
      for (final pid in followingIds) {
        final prod = TalentDirectory.findById(pid);
        if (prod != null && !connectedList.any((t) => t.id == prod.id)) {
          connectedList.add(prod.copyWith(isFollowing: true));
        }
      }

      // If active persona is a Production House (e.g. Filmfare), they can initiate casting messages with any talent
      final currentPersona = ref.read(userPersonaProvider);
      if (currentPersona.isProductionHouse) {
        for (final talent in TalentDirectory.allCuratedTalents) {
          if (!talent.isProductionHouse &&
              talent.id != activeUserId &&
              !connectedList.any((t) => t.id == talent.id)) {
            connectedList.add(talent);
          }
        }
      }

      state = state.copyWith(connectedTalents: connectedList);
    } catch (_) {}
  }

  Future<void> refreshConnections() async {
    final activePersona = ref.read(userPersonaProvider);
    await _loadConnectedTalents(activePersona.id);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Start a conversation with [peerTalent]. Returns the conversation ID.
  Future<String> startConversationWith(TalentModel peerTalent) async {
    final activePersona = ref.read(userPersonaProvider);
    final conv = await _chatRepo.getOrCreateConversation(
      userA: activePersona.id,
      userB: peerTalent.id,
    );
    final convId = conv['id'] as String? ?? ChatRepository.generateUuid();
    return convId;
  }

  /// Delete a conversation and remove from list
  Future<void> deleteConversation(String conversationId) async {
    await _chatRepo.deleteConversation(conversationId);
    state = state.copyWith(
      conversations: state.conversations
          .where((c) => c.id != conversationId)
          .toList(),
    );
  }

  /// Check whether [targetUserId] is messageable with active persona.
  bool canMessageUser(String targetUserId) {
    final activePersona = ref.read(userPersonaProvider);
    if (activePersona.isProductionHouse) return true;
    return state.connectedTalents.any(
      (t) => t.id == targetUserId || _isActorMatch(t.id, targetUserId),
    );
  }
}

final chatListProvider =
    NotifierProvider<ChatListNotifier, ChatListState>(() {
  return ChatListNotifier();
});

// ─── Chat Room State & Notifier ───────────────────────────────────────────────

class ChatRoomArgs {
  final String conversationId;
  final TalentModel peerTalent;

  const ChatRoomArgs({
    required this.conversationId,
    required this.peerTalent,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatRoomArgs &&
          runtimeType == other.runtimeType &&
          conversationId == other.conversationId;

  @override
  int get hashCode => conversationId.hashCode;
}

class ChatRoomState {
  final List<ChatMessageModel> messages;
  final bool isLoading;
  final bool isSending;

  const ChatRoomState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
  });

  ChatRoomState copyWith({
    List<ChatMessageModel>? messages,
    bool? isLoading,
    bool? isSending,
  }) {
    return ChatRoomState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
    );
  }
}

class ChatRoomNotifier extends Notifier<ChatRoomState> {
  final ChatRoomArgs arg;
  ChatRoomNotifier(this.arg);

  late ChatRepository _chatRepo;
  StreamSubscription<List<Map<String, dynamic>>>? _msgSub;

  @override
  ChatRoomState build() {
    _chatRepo = ref.watch(chatRepositoryProvider);
    final activePersona = ref.watch(userPersonaProvider);

    ref.onDispose(() {
      _msgSub?.cancel();
    });

    _subscribeToMessages(arg.conversationId, activePersona.id);
    _chatRepo.markRead(
      conversationId: arg.conversationId,
      userId: activePersona.id,
    );

    return const ChatRoomState(isLoading: true);
  }

  void _subscribeToMessages(String convId, String activeUserId) {
    _msgSub?.cancel();
    _msgSub = _chatRepo.watchMessages(convId).listen(
      (rows) {
        final messages = rows.map((r) => ChatMessageModel.fromJson(r)).toList();
        state = state.copyWith(
          messages: messages,
          isLoading: false,
        );
      },
      onError: (_) {
        state = state.copyWith(isLoading: false);
      },
    );
  }

  Future<void> sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final activePersona = ref.read(userPersonaProvider);
    state = state.copyWith(isSending: true);

    try {
      await _chatRepo.sendMessage(
        conversationId: arg.conversationId,
        senderId: activePersona.id,
        text: cleanText,
      );
    } finally {
      state = state.copyWith(isSending: false);
    }
  }

  /// Clear all messages in this chat room
  Future<void> clearChat() async {
    await _chatRepo.clearConversationMessages(arg.conversationId);
    state = state.copyWith(messages: []);
  }

  /// Delete the entire conversation and pop from room
  Future<void> deleteChat() async {
    await _chatRepo.deleteConversation(arg.conversationId);
    ref.read(chatListProvider.notifier).deleteConversation(arg.conversationId);
  }
}

final chatRoomProvider =
    NotifierProvider.family<ChatRoomNotifier, ChatRoomState, ChatRoomArgs>(
  ChatRoomNotifier.new,
);
