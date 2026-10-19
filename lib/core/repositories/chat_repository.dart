import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';

/// Repository for 1:1 chat conversations and messages.
/// Backed by Supabase Postgres with Realtime, plus resilient local-sync
/// so multi-persona switching works in real-time across all connected talents.
class ChatRepository {
  final SupabaseClient _client;

  ChatRepository(this._client);

  static bool? _isSupabaseTableAvailable;

  static bool isValidUuid(String id) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(id);
  }

  /// Compliant RFC 4122 v4 UUID generator accepted by Postgres UUID columns
  static String generateUuid() {
    final rnd = math.Random();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // RFC 4122 version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static void _recordSupabaseError(Object e) {
    final str = e.toString().toLowerCase();
    if (str.contains('pgrst205') ||
        str.contains('not found') ||
        str.contains('could not find the table') ||
        str.contains('channelerror') ||
        str.contains('relation') ||
        str.contains('404')) {
      _isSupabaseTableAvailable = false;
      if (kDebugMode) {
        debugPrint(
            'ChatRepository: Supabase chat tables not available in schema cache. Operating on resilient local store.');
      }
    } else if (kDebugMode) {
      debugPrint('ChatRepository Supabase error: $e');
    }
  }

  /// Reset table availability so Supabase queries can be retried (e.g. after SQL migration)
  static void resetSupabaseTableAvailability() {
    _isSupabaseTableAvailable = null;
  }

  SupabaseQueryBuilder get _conversations =>
      _client.from(SupabaseTables.conversations);
  SupabaseQueryBuilder get _messages =>
      _client.from(SupabaseTables.messages);

  /// Find existing conversation or create a new one between [userA] and [userB].
  Future<Map<String, dynamic>> getOrCreateConversation({
    required String userA,
    required String userB,
  }) async {
    if (_isSupabaseTableAvailable != false &&
        isValidUuid(userA) &&
        isValidUuid(userB)) {
      try {
        // 1. Try finding in Supabase
        final existing = await _conversations
            .select()
            .or(
              'and(participant_a.eq.$userA,participant_b.eq.$userB),and(participant_a.eq.$userB,participant_b.eq.$userA)',
            )
            .maybeSingle();

        if (existing != null) {
          _isSupabaseTableAvailable = true;
          _LocalChatStore.instance.registerConversation(existing);
          return existing;
        }

        // 2. Insert into Supabase if not found
        final now = DateTime.now().toUtc().toIso8601String();
        final inserted = await _conversations
            .insert({
              'participant_a': userA,
              'participant_b': userB,
              'last_message': '',
              'last_message_at': now,
              'created_at': now,
            })
            .select()
            .single();

        _isSupabaseTableAvailable = true;
        _LocalChatStore.instance.registerConversation(inserted);
        return inserted;
      } catch (e) {
        _recordSupabaseError(e);
      }
    }
    // Resilient local store fallback
    return _LocalChatStore.instance.getOrCreate(userA: userA, userB: userB);
  }

  /// Real-time stream of conversations for [uid].
  Stream<List<Map<String, dynamic>>> watchConversations(String uid) {
    late final StreamController<List<Map<String, dynamic>>> controller;
    final Map<String, Map<String, dynamic>> cacheA = {};
    final Map<String, Map<String, dynamic>> cacheB = {};
    StreamSubscription<List<Map<String, dynamic>>>? subA;
    StreamSubscription<List<Map<String, dynamic>>>? subB;
    StreamSubscription<void>? localSub;

    void emitMerged() {
      if (controller.isClosed) return;
      final mergedMap = <String, Map<String, dynamic>>{
        ..._LocalChatStore.instance.getConversationsForMap(uid),
        ...cacheA,
        ...cacheB,
      };

      final list = mergedMap.values.toList()
        ..sort((a, b) {
          final timeA = a['last_message_at'] as String? ?? '';
          final timeB = b['last_message_at'] as String? ?? '';
          return timeB.compareTo(timeA);
        });

      controller.add(list);
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        // Immediately emit local state
        emitMerged();

        // Listen to local store mutations
        localSub = _LocalChatStore.instance.conversationsStream.listen((_) {
          emitMerged();
        });

        // Listen to Supabase Realtime only if table is available and uid is valid UUID
        if (_isSupabaseTableAvailable != false && isValidUuid(uid)) {
          try {
            subA = _conversations
                .stream(primaryKey: ['id'])
                .eq('participant_a', uid)
                .listen(
                  (rows) {
                    _isSupabaseTableAvailable = true;
                    cacheA.clear();
                    for (final row in rows) {
                      cacheA[row['id'].toString()] = row;
                    }
                    emitMerged();
                  },
                  onError: (e) {
                    _recordSupabaseError(e);
                    subA?.cancel();
                    subA = null;
                  },
                );

            subB = _conversations
                .stream(primaryKey: ['id'])
                .eq('participant_b', uid)
                .listen(
                  (rows) {
                    _isSupabaseTableAvailable = true;
                    cacheB.clear();
                    for (final row in rows) {
                      cacheB[row['id'].toString()] = row;
                    }
                    emitMerged();
                  },
                  onError: (e) {
                    _recordSupabaseError(e);
                    subB?.cancel();
                    subB = null;
                  },
                );
          } catch (e) {
            _recordSupabaseError(e);
          }
        }
      },
      onCancel: () {
        subA?.cancel();
        subB?.cancel();
        localSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Real-time stream of messages in a given [conversationId].
  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) {
    late final StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription<List<Map<String, dynamic>>>? supabaseSub;
    StreamSubscription<void>? localSub;

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        // Emit current local messages immediately
        controller.add(_LocalChatStore.instance.getMessages(conversationId));

        // Listen to local updates
        localSub = _LocalChatStore.instance.messagesStream.listen((_) {
          if (!controller.isClosed) {
            controller.add(_LocalChatStore.instance.getMessages(conversationId));
          }
        });

        // Listen to Supabase realtime only if table is available and ID is valid UUID
        if (_isSupabaseTableAvailable != false && isValidUuid(conversationId)) {
          try {
            supabaseSub = _messages
                .stream(primaryKey: ['id'])
                .eq('conversation_id', conversationId)
                .order('created_at')
                .listen(
                  (rows) {
                    if (!controller.isClosed && rows.isNotEmpty) {
                      _isSupabaseTableAvailable = true;
                      _LocalChatStore.instance.mergeSupabaseMessages(conversationId, rows);
                      controller.add(_LocalChatStore.instance.getMessages(conversationId));
                    }
                  },
                  onError: (e) {
                    _recordSupabaseError(e);
                    supabaseSub?.cancel();
                    supabaseSub = null;
                  },
                );
          } catch (e) {
            _recordSupabaseError(e);
          }
        }
      },
      onCancel: () {
        supabaseSub?.cancel();
        localSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Send a message in a conversation.
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    String? mediaUrl,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final messageId = generateUuid();
    final messageData = {
      'id': messageId,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'text': text,
      'media_url': mediaUrl,
      'created_at': now,
      'read_at': null,
    };

    // Store locally first for instantaneous UI update
    _LocalChatStore.instance.addMessage(messageData);

    if (_isSupabaseTableAvailable != false &&
        isValidUuid(conversationId) &&
        isValidUuid(senderId)) {
      try {
        final remote = await _messages
            .insert({
              'id': messageId,
              'conversation_id': conversationId,
              'sender_id': senderId,
              'text': text,
              'media_url': mediaUrl,
              'created_at': now,
            })
            .select()
            .single();

        await _conversations
            .update({
              'last_message': text,
              'last_message_at': now,
            })
            .eq('id', conversationId);

        _isSupabaseTableAvailable = true;
        _LocalChatStore.instance.addMessage(remote);
        return remote;
      } catch (e) {
        _recordSupabaseError(e);
      }
    }
    return messageData;
  }

  /// Mark all messages in a conversation as read for [userId].
  Future<void> markRead({
    required String conversationId,
    required String userId,
  }) async {
    _LocalChatStore.instance.markRead(conversationId, userId);
    if (_isSupabaseTableAvailable != false &&
        isValidUuid(conversationId) &&
        isValidUuid(userId)) {
      try {
        final now = DateTime.now().toUtc().toIso8601String();
        await _messages
            .update({'read_at': now})
            .eq('conversation_id', conversationId)
            .neq('sender_id', userId)
            .isFilter('read_at', null);
      } catch (e) {
        _recordSupabaseError(e);
      }
    }
  }

  /// Clear all messages in a conversation.
  Future<void> clearConversationMessages(String conversationId) async {
    _LocalChatStore.instance.clearMessages(conversationId);
    if (_isSupabaseTableAvailable != false && isValidUuid(conversationId)) {
      try {
        await _messages.delete().eq('conversation_id', conversationId);
        await _conversations.update({
          'last_message': '',
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', conversationId);
      } catch (e) {
        _recordSupabaseError(e);
      }
    }
  }

  /// Delete a conversation and all its messages permanently.
  Future<void> deleteConversation(String conversationId) async {
    _LocalChatStore.instance.deleteConversation(conversationId);
    if (_isSupabaseTableAvailable != false && isValidUuid(conversationId)) {
      try {
        await _messages.delete().eq('conversation_id', conversationId);
        await _conversations.delete().eq('id', conversationId);
      } catch (e) {
        _recordSupabaseError(e);
      }
    }
  }
}

/// In-memory & reactive resilient store providing instant messaging across personas
class _LocalChatStore {
  _LocalChatStore._() {
    _seedDefaultData();
  }
  static final _LocalChatStore instance = _LocalChatStore._();

  final Map<String, Map<String, dynamic>> _conversations = {};
  final Map<String, List<Map<String, dynamic>>> _messages = {};

  final StreamController<void> _convController =
      StreamController<void>.broadcast();
  final StreamController<void> _msgController =
      StreamController<void>.broadcast();

  Stream<void> get conversationsStream => _convController.stream;
  Stream<void> get messagesStream => _msgController.stream;

  void registerConversation(Map<String, dynamic> row) {
    final id = row['id'].toString();
    _conversations[id] = Map<String, dynamic>.from(row);
    _convController.add(null);
  }

  void clearMessages(String conversationId) {
    _messages[conversationId] = [];
    if (_conversations.containsKey(conversationId)) {
      _conversations[conversationId] = {
        ..._conversations[conversationId]!,
        'last_message': '',
        'last_message_at': DateTime.now().toUtc().toIso8601String(),
      };
    }
    _msgController.add(null);
    _convController.add(null);
  }

  void deleteConversation(String conversationId) {
    _conversations.remove(conversationId);
    _messages.remove(conversationId);
    _convController.add(null);
    _msgController.add(null);
  }

  bool _isActorMatch(String a, String b) {
    if (a == b) return true;
    final actorPersona = UserPersonaNotifier.buildActorPersona();
    final isA = a == UserPersonaNotifier.actorDefaultId || a == actorPersona.id;
    final isB = b == UserPersonaNotifier.actorDefaultId || b == actorPersona.id;
    return isA && isB;
  }

  Map<String, dynamic> getOrCreate({
    required String userA,
    required String userB,
  }) {
    for (final c in _conversations.values) {
      final pa = c['participant_a'] as String? ?? '';
      final pb = c['participant_b'] as String? ?? '';
      final matchA = (pa == userA || _isActorMatch(pa, userA));
      final matchB = (pb == userB || _isActorMatch(pb, userB));
      final matchRevA = (pa == userB || _isActorMatch(pa, userB));
      final matchRevB = (pb == userA || _isActorMatch(pb, userA));
      if ((matchA && matchB) || (matchRevA && matchRevB)) {
        return c;
      }
    }

    final id = ChatRepository.generateUuid();
    final now = DateTime.now().toUtc().toIso8601String();
    final newConv = {
      'id': id,
      'participant_a': userA,
      'participant_b': userB,
      'last_message': '',
      'last_message_at': now,
      'created_at': now,
    };
    _conversations[id] = newConv;
    _convController.add(null);
    return newConv;
  }

  Map<String, Map<String, dynamic>> getConversationsForMap(String uid) {
    final result = <String, Map<String, dynamic>>{};
    for (final entry in _conversations.entries) {
      final c = entry.value;
      final pa = c['participant_a'] as String? ?? '';
      final pb = c['participant_b'] as String? ?? '';
      if (pa == uid || pb == uid || _isActorMatch(pa, uid) || _isActorMatch(pb, uid)) {
        result[entry.key] = c;
      }
    }
    return result;
  }

  List<Map<String, dynamic>> getMessages(String conversationId) {
    return List<Map<String, dynamic>>.from(_messages[conversationId] ?? []);
  }

  void addMessage(Map<String, dynamic> msg) {
    final convId = msg['conversation_id']?.toString() ?? '';
    if (convId.isEmpty) return;

    _messages.putIfAbsent(convId, () => []);
    final list = _messages[convId]!;

    // Replace if id exists, otherwise append
    final id = msg['id']?.toString();
    final idx = list.indexWhere((m) => m['id']?.toString() == id);
    if (idx != -1) {
      list[idx] = msg;
    } else {
      list.add(msg);
    }

    // Update conversation last_message
    if (_conversations.containsKey(convId)) {
      _conversations[convId] = {
        ..._conversations[convId]!,
        'last_message': msg['text'] ?? '',
        'last_message_at': msg['created_at'] ?? '',
      };
    }

    _msgController.add(null);
    _convController.add(null);
  }

  void mergeSupabaseMessages(
      String conversationId, List<Map<String, dynamic>> remote) {
    _messages.putIfAbsent(conversationId, () => []);
    final existing = _messages[conversationId]!;
    for (final r in remote) {
      final rid = r['id']?.toString();
      final idx = existing.indexWhere((m) => m['id']?.toString() == rid);
      if (idx != -1) {
        existing[idx] = r;
      } else {
        existing.add(r);
      }
    }
    existing.sort((a, b) {
      final ta = a['created_at']?.toString() ?? '';
      final tb = b['created_at']?.toString() ?? '';
      return ta.compareTo(tb);
    });
    _msgController.add(null);
  }

  void markRead(String conversationId, String userId) {
    final list = _messages[conversationId];
    if (list != null) {
      final now = DateTime.now().toUtc().toIso8601String();
      for (var i = 0; i < list.length; i++) {
        final sid = list[i]['sender_id'] as String? ?? '';
        final isSender = sid == userId || _isActorMatch(sid, userId);
        if (!isSender && list[i]['read_at'] == null) {
          list[i] = {...list[i], 'read_at': now};
        }
      }
      _msgController.add(null);
      _convController.add(null);
    }
  }

  void _seedDefaultData() {
    // Starts completely clean. Only real connections (Jeremiah Green) create genuine chat sessions.
  }
}
