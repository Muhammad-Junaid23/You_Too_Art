import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:you_too_art/core/constants/supabase_tables.dart';

/// Repository for 1:1 chat conversations and messages.
class ChatRepository {
  final SupabaseClient _client;

  ChatRepository(this._client);

  SupabaseQueryBuilder get _conversations =>
      _client.from(SupabaseTables.conversations);
  SupabaseQueryBuilder get _messages =>
      _client.from(SupabaseTables.messages);

  /// Real-time bi-directional stream of conversations for a given [uid].
  ///
  /// Combines conversations where [uid] is either `participant_a` or `participant_b`,
  /// de-duplicates them by conversation id, and orders by `last_message_at` descending.
  Stream<List<Map<String, dynamic>>> watchConversations(String uid) {
    late final StreamController<List<Map<String, dynamic>>> controller;
    final Map<String, Map<String, dynamic>> cacheA = {};
    final Map<String, Map<String, dynamic>> cacheB = {};
    StreamSubscription<List<Map<String, dynamic>>>? subA;
    StreamSubscription<List<Map<String, dynamic>>>? subB;

    void emitMerged() {
      if (controller.isClosed) return;
      final mergedMap = <String, Map<String, dynamic>>{
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
              onError: (error, stack) {
                if (!controller.isClosed) controller.addError(error, stack);
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
              onError: (error, stack) {
                if (!controller.isClosed) controller.addError(error, stack);
              },
            );
      },
      onCancel: () {
        subA?.cancel();
        subB?.cancel();
      },
    );

    return controller.stream;
  }

  /// Real-time stream of messages in a given [conversationId].
  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) {
    return _messages
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at');
  }

  /// Send a message in a conversation.
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    String? mediaUrl,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      final data = await _messages
          .insert({
            'conversation_id': conversationId,
            'sender_id': senderId,
            'text': text,
            'media_url': mediaUrl,
            'created_at': now,
          })
          .select()
          .single();

      // Update the conversation's last message timestamp and preview.
      await _conversations
          .update({
            'last_message': text,
            'last_message_at': now,
          })
          .eq('id', conversationId);

      return data;
    } catch (e) {
      if (kDebugMode) debugPrint('ChatRepository.sendMessage: $e');
      rethrow;
    }
  }

  /// Mark all messages in a conversation as read for [userId].
  Future<void> markRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _messages
          .update({'read_at': now})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .isFilter('read_at', null);
    } catch (e) {
      if (kDebugMode) debugPrint('ChatRepository.markRead: $e');
      rethrow;
    }
  }
}
