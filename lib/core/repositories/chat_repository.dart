import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/core/constants/talent_directory.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';

/// Repository for 1:1 chat conversations and messages.
/// Backed by Supabase Postgres with Realtime, plus resilient local-sync
/// so multi-persona switching works in real-time across all connected talents.
class ChatRepository {
  final SupabaseClient _client;

  ChatRepository(this._client);

  SupabaseQueryBuilder get _conversations =>
      _client.from(SupabaseTables.conversations);
  SupabaseQueryBuilder get _messages =>
      _client.from(SupabaseTables.messages);

  /// Find existing conversation or create a new one between [userA] and [userB].
  Future<Map<String, dynamic>> getOrCreateConversation({
    required String userA,
    required String userB,
  }) async {
    try {
      // 1. Try finding in Supabase
      final existing = await _conversations
          .select()
          .or(
            'and(participant_a.eq.$userA,participant_b.eq.$userB),and(participant_a.eq.$userB,participant_b.eq.$userA)',
          )
          .maybeSingle();

      if (existing != null) {
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

      _LocalChatStore.instance.registerConversation(inserted);
      return inserted;
    } catch (e) {
      if (kDebugMode) debugPrint('ChatRepository.getOrCreateConversation fallback: $e');
      // Resilient local store fallback
      return _LocalChatStore.instance.getOrCreate(userA: userA, userB: userB);
    }
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

        // Listen to Supabase Realtime for participant_a
        try {
          subA = _conversations
              .stream(primaryKey: ['id'])
              .eq('participant_a', uid)
              .listen(
                (rows) {
                  cacheA.clear();
                  for (final row in rows) {
                    cacheA[row['id'].toString()] = row;
                  }
                  emitMerged();
                },
                onError: (e) {
                  if (kDebugMode) debugPrint('ChatRepository.watchConversations subA error: $e');
                },
              );

          subB = _conversations
              .stream(primaryKey: ['id'])
              .eq('participant_b', uid)
              .listen(
                (rows) {
                  cacheB.clear();
                  for (final row in rows) {
                    cacheB[row['id'].toString()] = row;
                  }
                  emitMerged();
                },
                onError: (e) {
                  if (kDebugMode) debugPrint('ChatRepository.watchConversations subB error: $e');
                },
              );
        } catch (_) {}
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

        // Listen to Supabase realtime
        try {
          supabaseSub = _messages
              .stream(primaryKey: ['id'])
              .eq('conversation_id', conversationId)
              .order('created_at')
              .listen(
                (rows) {
                  if (!controller.isClosed && rows.isNotEmpty) {
                    _LocalChatStore.instance.mergeSupabaseMessages(conversationId, rows);
                    controller.add(_LocalChatStore.instance.getMessages(conversationId));
                  }
                },
                onError: (e) {
                  if (kDebugMode) debugPrint('ChatRepository.watchMessages error: $e');
                },
              );
        } catch (_) {}
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
    final messageData = {
      'id': 'msg-${DateTime.now().millisecondsSinceEpoch}-${senderId.substring(0, 4)}',
      'conversation_id': conversationId,
      'sender_id': senderId,
      'text': text,
      'media_url': mediaUrl,
      'created_at': now,
      'read_at': null,
    };

    // Store locally first for instantaneous UI update
    _LocalChatStore.instance.addMessage(messageData);

    try {
      final remote = await _messages
          .insert({
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

      _LocalChatStore.instance.addMessage(remote);
      return remote;
    } catch (e) {
      if (kDebugMode) debugPrint('ChatRepository.sendMessage remote write fallback: $e');
      return messageData;
    }
  }

  /// Mark all messages in a conversation as read for [userId].
  Future<void> markRead({
    required String conversationId,
    required String userId,
  }) async {
    _LocalChatStore.instance.markRead(conversationId, userId);
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _messages
          .update({'read_at': now})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .isFilter('read_at', null);
    } catch (_) {}
  }
}

/// In-memory & reactive resilient store providing instant messaging across personas
/// and seeded with conversations matching Figma Image 1 & 2.
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

  Map<String, dynamic> getOrCreate({
    required String userA,
    required String userB,
  }) {
    for (final c in _conversations.values) {
      final pa = c['participant_a'];
      final pb = c['participant_b'];
      if ((pa == userA && pb == userB) || (pa == userB && pb == userA)) {
        return c;
      }
    }

    final id = 'conv-$userA-$userB';
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
      if (c['participant_a'] == uid || c['participant_b'] == uid) {
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
        if (list[i]['sender_id'] != userId && list[i]['read_at'] == null) {
          list[i] = {...list[i], 'read_at': now};
        }
      }
      _msgController.add(null);
      _convController.add(null);
    }
  }

  void _seedDefaultData() {
    final actorId = UserPersonaNotifier.actorDefaultId;
    final aliId = TalentDirectory.muhammadAliId;
    final ranveerId = TalentDirectory.ranveerSinghId;
    final alexanderId = UserPersonaNotifier.alexanderId;
    final emersonId = TalentDirectory.jamesId; // Emerson Dias / James

    final now = DateTime.now();

    // 1. Conversation with Muhammad Ali (matching Figma Image 1 & 2)
    final convAliId = 'conv-actor-muhammad-ali';
    _conversations[convAliId] = {
      'id': convAliId,
      'participant_a': actorId,
      'participant_b': aliId,
      'last_message':
          'Yes exactly, that’s what I wanted to discuss with you.',
      'last_message_at':
          now.subtract(const Duration(seconds: 40)).toUtc().toIso8601String(),
      'created_at':
          now.subtract(const Duration(hours: 4)).toUtc().toIso8601String(),
    };

    _messages[convAliId] = [
      {
        'id': 'msg-ali-1',
        'conversation_id': convAliId,
        'sender_id': aliId,
        'text': 'Hi Wajahat! Hope you’re doing well.',
        'created_at':
            now.subtract(const Duration(hours: 4)).toUtc().toIso8601String(),
        'read_at': now.subtract(const Duration(hours: 3)).toUtc().toIso8601String(),
      },
      {
        'id': 'msg-ali-2',
        'conversation_id': convAliId,
        'sender_id': actorId,
        'text': 'Hi Ali! I’m fine.',
        'created_at':
            now.subtract(const Duration(minutes: 1)).toUtc().toIso8601String(),
        'read_at': now.subtract(const Duration(seconds: 50)).toUtc().toIso8601String(),
      },
      {
        'id': 'msg-ali-3',
        'conversation_id': convAliId,
        'sender_id': actorId,
        'text': 'What about you?',
        'created_at':
            now.subtract(const Duration(minutes: 1)).toUtc().toIso8601String(),
        'read_at': now.subtract(const Duration(seconds: 50)).toUtc().toIso8601String(),
      },
      {
        'id': 'msg-ali-4',
        'conversation_id': convAliId,
        'sender_id': actorId,
        'text': 'Have you posted a Casting Call for your next project?',
        'created_at':
            now.subtract(const Duration(minutes: 1)).toUtc().toIso8601String(),
        'read_at': now.subtract(const Duration(seconds: 50)).toUtc().toIso8601String(),
      },
      {
        'id': 'msg-ali-5',
        'conversation_id': convAliId,
        'sender_id': aliId,
        'text': 'I’m good.',
        'created_at':
            now.subtract(const Duration(seconds: 45)).toUtc().toIso8601String(),
        'read_at': null,
      },
      {
        'id': 'msg-ali-6',
        'conversation_id': convAliId,
        'sender_id': aliId,
        'text': 'Yes exactly, that’s what I wanted to discuss with you.',
        'created_at':
            now.subtract(const Duration(seconds: 40)).toUtc().toIso8601String(),
        'read_at': null,
      },
    ];

    // 2. Conversation with Ranveer Singh (matching Figma Image 2 with unread badge "2")
    final convRanveerId = 'conv-actor-ranveer-singh';
    _conversations[convRanveerId] = {
      'id': convRanveerId,
      'participant_a': actorId,
      'participant_b': ranveerId,
      'last_message': 'Good Job Wajahat! I’m proud of you.',
      'last_message_at':
          now.subtract(const Duration(minutes: 2)).toUtc().toIso8601String(),
      'created_at':
          now.subtract(const Duration(days: 1)).toUtc().toIso8601String(),
    };
    _messages[convRanveerId] = [
      {
        'id': 'msg-ran-1',
        'conversation_id': convRanveerId,
        'sender_id': ranveerId,
        'text': 'Hey! Loved your recent audition performance.',
        'created_at':
            now.subtract(const Duration(minutes: 5)).toUtc().toIso8601String(),
        'read_at': null,
      },
      {
        'id': 'msg-ran-2',
        'conversation_id': convRanveerId,
        'sender_id': ranveerId,
        'text': 'Good Job Wajahat! I’m proud of you.',
        'created_at':
            now.subtract(const Duration(minutes: 2)).toUtc().toIso8601String(),
        'read_at': null,
      },
    ];

    // 3. Conversation with Emerson Dias
    final convEmersonId = 'conv-actor-emerson-dias';
    _conversations[convEmersonId] = {
      'id': convEmersonId,
      'participant_a': actorId,
      'participant_b': emersonId,
      'last_message': 'Hi Wajahat! Hope you’re doing well. I wanted to catch up.',
      'last_message_at':
          now.subtract(const Duration(hours: 22)).toUtc().toIso8601String(),
      'created_at':
          now.subtract(const Duration(days: 2)).toUtc().toIso8601String(),
    };

    // 4. Conversation between Actor and Alexander Cole (for live multi-persona testing)
    final convAlexId = 'conv-actor-alexander-cole';
    _conversations[convAlexId] = {
      'id': convAlexId,
      'participant_a': actorId,
      'participant_b': alexanderId,
      'last_message':
          'Hey Alexander! Looking forward to collaborating on the upcoming project.',
      'last_message_at':
          now.subtract(const Duration(minutes: 15)).toUtc().toIso8601String(),
      'created_at':
          now.subtract(const Duration(days: 1)).toUtc().toIso8601String(),
    };
    _messages[convAlexId] = [
      {
        'id': 'msg-alex-1',
        'conversation_id': convAlexId,
        'sender_id': actorId,
        'text':
            'Hey Alexander! Looking forward to collaborating on the upcoming project.',
        'created_at':
            now.subtract(const Duration(minutes: 15)).toUtc().toIso8601String(),
        'read_at': now.subtract(const Duration(minutes: 10)).toUtc().toIso8601String(),
      },
    ];
  }
}
