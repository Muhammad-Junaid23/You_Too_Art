import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/core/constants/supabase_tables.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';

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

  /// Find existing conversation or create a draft between [userA] and [userB].
  /// Does NOT materialize an empty conversation in the database or chat list
  /// until the user actually sends their first message.
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
          return existing;
        }
      } catch (e) {
        _recordSupabaseError(e);
      }
    }

    // 2. Try finding existing in local store
    final localExisting = _LocalChatStore.instance.findExisting(userA: userA, userB: userB);
    if (localExisting != null) {
      return localExisting;
    }

    // 3. Return an in-memory draft conversation without inserting until first message is sent
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

      // Filter out conversations that have been deleted for THIS user
      mergedMap.removeWhere(
          (id, _) => _LocalChatStore.instance.isDeletedForUser(id, uid));

      final list = mergedMap.values.map((conv) {
        final convId = conv['id'].toString();
        final visibleMsgs =
            _LocalChatStore.instance.getMessages(convId, userId: uid);
        final copy = Map<String, dynamic>.from(conv);
        if (visibleMsgs.isEmpty) {
          copy['last_message'] = (conv['last_message'] as String? ?? '');
        } else {
          copy['last_message'] = visibleMsgs.last['text'] ?? '';
          copy['last_message_at'] =
              visibleMsgs.last['created_at'] ?? conv['last_message_at'];
        }
        return copy;
      }).where((conv) {
        // Strictly exclude empty conversations that have no messages
        final convId = conv['id'].toString();
        final visibleMsgs =
            _LocalChatStore.instance.getMessages(convId, userId: uid);
        final lastMsg = (conv['last_message'] as String?)?.trim() ?? '';
        return visibleMsgs.isNotEmpty || lastMsg.isNotEmpty;
      }).toList()
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
          // Perform an immediate initial REST fetch so chats display instantly on startup
          Future.microtask(() async {
            try {
              final rows = await _conversations
                  .select()
                  .or('participant_a.eq.$uid,participant_b.eq.$uid')
                  .order('last_message_at', ascending: false);
              final idsToPreload = <String>[];
              for (final row in rows) {
                final id = row['id'].toString();
                if (row['participant_a'] == uid) {
                  cacheA[id] = row;
                } else {
                  cacheB[id] = row;
                }
                _LocalChatStore.instance.registerConversation(row);
                idsToPreload.add(id);
              }
              emitMerged();
              if (idsToPreload.isNotEmpty) {
                await _preloadMessagesFor(idsToPreload);
                emitMerged();
              }
            } catch (e) {
              _recordSupabaseError(e);
            }
          });

          try {
            subA = _conversations
                .stream(primaryKey: ['id'])
                .eq('participant_a', uid)
                .listen(
                  (rows) {
                    _isSupabaseTableAvailable = true;
                    cacheA.clear();
                    for (final row in rows) {
                      final id = row['id'].toString();
                      cacheA[id] = row;
                      _LocalChatStore.instance.registerConversation(row);
                    }
                    _preloadMessagesFor(
                        rows.map((r) => r['id'].toString()).toList());
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
                      final id = row['id'].toString();
                      cacheB[id] = row;
                      _LocalChatStore.instance.registerConversation(row);
                    }
                    _preloadMessagesFor(
                        rows.map((r) => r['id'].toString()).toList());
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

  Future<void> _preloadMessagesFor(List<String> convIds) async {
    final validIds = convIds.where(isValidUuid).toList();
    if (validIds.isEmpty || _isSupabaseTableAvailable == false) return;
    try {
      final rows = await _messages
          .select()
          .inFilter('conversation_id', validIds)
          .order('created_at');
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final r in rows) {
        final cid = r['conversation_id']?.toString() ?? '';
        if (cid.isNotEmpty) {
          grouped.putIfAbsent(cid, () => []).add(r);
        }
      }
      for (final entry in grouped.entries) {
        _LocalChatStore.instance.setSupabaseMessages(entry.key, entry.value);
      }
    } catch (e) {
      _recordSupabaseError(e);
    }
  }

  /// Real-time stream of messages in a given [conversationId] for [userId].
  Stream<List<Map<String, dynamic>>> watchMessages(
    String conversationId, {
    required String userId,
  }) {
    late final StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription<List<Map<String, dynamic>>>? supabaseSub;
    StreamSubscription<void>? localSub;

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        // Emit current local messages for this user immediately
        controller.add(
            _LocalChatStore.instance.getMessages(conversationId, userId: userId));

        // Listen to local updates
        localSub = _LocalChatStore.instance.messagesStream.listen((_) {
          if (!controller.isClosed) {
            controller.add(
                _LocalChatStore.instance.getMessages(conversationId, userId: userId));
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
                    if (!controller.isClosed) {
                      _isSupabaseTableAvailable = true;
                      _LocalChatStore.instance
                          .setSupabaseMessages(conversationId, rows);
                      controller.add(_LocalChatStore.instance
                          .getMessages(conversationId, userId: userId));
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
        final convCheck = await _conversations
            .select('id')
            .eq('id', conversationId)
            .maybeSingle();

        if (convCheck == null) {
          final localConv = _LocalChatStore.instance.getConversation(conversationId);
          final userA = localConv?['participant_a']?.toString() ?? senderId;
          final userB = localConv?['participant_b']?.toString() ?? '';
          if (isValidUuid(userA) && isValidUuid(userB)) {
            await _conversations.insert({
              'id': conversationId,
              'participant_a': userA,
              'participant_b': userB,
              'last_message': text,
              'last_message_at': now,
              'created_at': now,
            });
          }
        } else {
          await _conversations
              .update({
                'last_message': text,
                'last_message_at': now,
              })
              .eq('id', conversationId);
        }

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
    _LocalChatStore.instance
        .markRead(conversationId: conversationId, userId: userId);
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

  /// Mark all messages across all conversations as read for [userId].
  Future<void> markAllAsRead({required String userId}) async {
    _LocalChatStore.instance.markAllRead(userId: userId);
    if (_isSupabaseTableAvailable != false && isValidUuid(userId)) {
      try {
        final now = DateTime.now().toUtc().toIso8601String();
        await _messages
            .update({'read_at': now})
            .neq('sender_id', userId)
            .isFilter('read_at', null);
      } catch (e) {
        _recordSupabaseError(e);
      }
    }
  }

  /// Clear messages in a conversation for [userId] (Clear for me).
  Future<void> clearConversationMessages({
    required String conversationId,
    required String userId,
  }) async {
    _LocalChatStore.instance.clearMessages(
      conversationId: conversationId,
      userId: userId,
    );
    // Note: Do NOT delete messages in Supabase because "Clear Chat" is a per-user
    // ("Clear for me") action and must never delete messages for the other participant.
  }

  /// Delete a conversation for [userId] (soft delete for this user).
  /// Only hard-deletes from cloud database if BOTH participants have deleted it.
  Future<void> deleteConversation({
    required String conversationId,
    required String userId,
  }) async {
    _LocalChatStore.instance.deleteConversation(
      conversationId: conversationId,
      userId: userId,
    );

    if (_isSupabaseTableAvailable != false && isValidUuid(conversationId)) {
      try {
        final conv = _LocalChatStore.instance.getConversation(conversationId);
        if (conv != null) {
          final pa = conv['participant_a']?.toString() ?? '';
          final pb = conv['participant_b']?.toString() ?? '';
          if (pa.isNotEmpty && pb.isNotEmpty) {
            final paDeleted =
                _LocalChatStore.instance.isDeletedForUser(conversationId, pa);
            final pbDeleted =
                _LocalChatStore.instance.isDeletedForUser(conversationId, pb);
            // Only remove from cloud database if BOTH users have deleted it
            if (paDeleted && pbDeleted) {
              await _messages.delete().eq('conversation_id', conversationId);
              await _conversations.delete().eq('id', conversationId);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('ChatRepository.deleteConversation Supabase error: $e');
      }
    }
  }

  /// Get the unread message count in a conversation for [userId].
  int getUnreadCount({
    required String conversationId,
    required String userId,
  }) {
    return _LocalChatStore.instance.getUnreadCount(
      conversationId: conversationId,
      userId: userId,
    );
  }

  /// Get visible messages in a conversation for [userId].
  List<Map<String, dynamic>> getMessages(
    String conversationId, {
    String? userId,
  }) {
    return _LocalChatStore.instance.getMessages(conversationId, userId: userId);
  }
}

/// In-memory & reactive resilient store providing instant messaging across personas
/// with per-user persistent local cache for deleted conversations and cleared timestamps.
class _LocalChatStore {
  _LocalChatStore._() {
    _loadFromPrefs();
  }
  static final _LocalChatStore instance = _LocalChatStore._();

  static const String _deletedConvsByUserKey = 'yt_user_deleted_convs_clean_v3';
  static const String _clearedTimestampsByUserKey =
      'yt_user_cleared_timestamps_clean_v3';
  static const String _localConvsKey = 'yt_local_conversations_clean_v3';
  static const String _localMsgsKey = 'yt_local_messages_clean_v3';

  final Map<String, Set<String>> _deletedConvsByUser = {};
  final Map<String, Map<String, DateTime>> _clearedTimestampsByUser = {};
  final Map<String, Map<String, dynamic>> _conversations = {};
  final Map<String, Map<String, dynamic>> _draftConversations = {};
  final Map<String, List<Map<String, dynamic>>> _messages = {};

  final StreamController<void> _convController =
      StreamController<void>.broadcast();
  final StreamController<void> _msgController =
      StreamController<void>.broadcast();

  Stream<void> get conversationsStream => _convController.stream;
  Stream<void> get messagesStream => _msgController.stream;

  String _normalizeUserId(String uid) {
    return uid.trim();
  }

  bool _isActorMatch(String a, String b) {
    if (a == b) return true;
    return UserPersonaNotifier.isSamePersona(a, b);
  }

  List<String> _allUserKeys(String uid) {
    final cleanUid = uid.trim();
    final keys = <String>{cleanUid};
    if (UserPersonaNotifier.isActorId(cleanUid)) {
      keys.add('actor');
      keys.add(AppPersistenceService.actorDefaultId);
      keys.add(AppPersistenceService.realActorId);
      keys.add('00000000-0000-0000-0000-000000000001');
    } else if (UserPersonaNotifier.isDirectorId(cleanUid)) {
      keys.add(AppPersistenceService.alexanderId);
      keys.add(AppPersistenceService.realDirectorId);
      keys.add('a1111111-1111-1111-1111-111111111111');
    } else if (UserPersonaNotifier.isProductionId(cleanUid)) {
      keys.add(AppPersistenceService.filmfareId);
      keys.add('filmfare');
      keys.add(AppPersistenceService.realProductionId);
      keys.add('b2222222-2222-2222-2222-222222222222');
    }
    return keys.toList();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clean up legacy v1 and v2 keys from device storage if present
      await prefs.remove('yt_local_conversations_clean_v1');
      await prefs.remove('yt_local_messages_clean_v1');
      await prefs.remove('yt_user_deleted_convs_clean_v1');
      await prefs.remove('yt_user_cleared_timestamps_clean_v1');
      await prefs.remove('yt_local_conversations_clean_v2');
      await prefs.remove('yt_local_messages_clean_v2');
      await prefs.remove('yt_user_deleted_convs_clean_v2');
      await prefs.remove('yt_user_cleared_timestamps_clean_v2');

      // Load deleted convs by user
      final deletedRaw = prefs.getString(_deletedConvsByUserKey);
      if (deletedRaw != null && deletedRaw.isNotEmpty) {
        final decoded = jsonDecode(deletedRaw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          _deletedConvsByUser[entry.key] = Set<String>.from(entry.value as List);
        }
      }

      // Load cleared timestamps by user
      final clearedRaw = prefs.getString(_clearedTimestampsByUserKey);
      if (clearedRaw != null && clearedRaw.isNotEmpty) {
        final decoded = jsonDecode(clearedRaw) as Map<String, dynamic>;
        for (final userEntry in decoded.entries) {
          final userMap = <String, DateTime>{};
          for (final convEntry in (userEntry.value as Map).entries) {
            final dt = DateTime.tryParse(convEntry.value.toString());
            if (dt != null) {
              userMap[convEntry.key.toString()] = dt;
            }
          }
          _clearedTimestampsByUser[userEntry.key] = userMap;
        }
      }

      // Load conversations
      final convsRaw = prefs.getString(_localConvsKey);
      if (convsRaw != null && convsRaw.isNotEmpty) {
        final decoded = jsonDecode(convsRaw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          _conversations[entry.key] =
              Map<String, dynamic>.from(entry.value as Map);
        }
      }

      // Load messages
      final msgsRaw = prefs.getString(_localMsgsKey);
      if (msgsRaw != null && msgsRaw.isNotEmpty) {
        final decoded = jsonDecode(msgsRaw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final list = (entry.value as List)
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList();
          _messages[entry.key] = list;
        }
      }

      // Strictly purge any draft conversations that have zero messages and no last_message
      _conversations.removeWhere((id, conv) {
        final msgs = _messages[id];
        final lastMsg = (conv['last_message'] as String?)?.trim() ?? '';
        return (msgs == null || msgs.isEmpty) && lastMsg.isEmpty;
      });
      await prefs.setString(_localConvsKey, jsonEncode(_conversations));

      _convController.add(null);
      _msgController.add(null);
    } catch (_) {
      _convController.add(null);
      _msgController.add(null);
    }
  }

  Future<void> _saveUserDeletedToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _deletedConvsByUser.map((k, v) => MapEntry(k, v.toList()));
      await prefs.setString(_deletedConvsByUserKey, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> _saveUserClearedToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _clearedTimestampsByUser.map((user, convMap) {
        return MapEntry(
          user,
          convMap.map((convId, dt) => MapEntry(convId, dt.toIso8601String())),
        );
      });
      await prefs.setString(_clearedTimestampsByUserKey, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> _saveConvsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localConvsKey, jsonEncode(_conversations));
    } catch (_) {}
  }

  Future<void> _saveMsgsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localMsgsKey, jsonEncode(_messages));
    } catch (_) {}
  }

  bool isDeletedForUser(String conversationId, String userId) {
    for (final k in _allUserKeys(userId)) {
      if (_deletedConvsByUser[k]?.contains(conversationId) == true) {
        return true;
      }
      try {
        if (AppPersistenceService.instance.isConvDeletedForUser(conversationId, k)) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  void undeleteForUser(String conversationId, String userId) {
    bool changed = false;
    for (final k in _allUserKeys(userId)) {
      if (_deletedConvsByUser[k]?.remove(conversationId) == true) {
        changed = true;
      }
      try {
        AppPersistenceService.instance.unmarkConvDeletedForUser(conversationId, k);
      } catch (_) {}
    }
    if (changed) {
      _saveUserDeletedToPrefs();
      _convController.add(null);
    }
  }

  DateTime? getClearedTimestamp({
    required String conversationId,
    required String userId,
  }) {
    DateTime? latest;
    for (final k in _allUserKeys(userId)) {
      final dt = _clearedTimestampsByUser[k]?[conversationId];
      if (dt != null) {
        if (latest == null || dt.isAfter(latest)) {
          latest = dt;
        }
      }
    }
    return latest;
  }

  void registerConversation(Map<String, dynamic> row) {
    final id = row['id'].toString();
    _conversations[id] = Map<String, dynamic>.from(row);
    _saveConvsToPrefs();
    _convController.add(null);
  }

  void clearMessages({
    required String conversationId,
    required String userId,
  }) {
    final now = DateTime.now().toUtc();
    for (final k in _allUserKeys(userId)) {
      _clearedTimestampsByUser
          .putIfAbsent(k, () => <String, DateTime>{})[conversationId] = now;
    }

    _saveUserClearedToPrefs();
    _msgController.add(null);
    _convController.add(null);
  }

  Map<String, dynamic>? getConversation(String convId) {
    return _conversations[convId] ?? _draftConversations[convId];
  }

  void registerDraft(Map<String, dynamic> draft) {
    final id = draft['id']?.toString() ?? '';
    if (id.isNotEmpty) {
      _draftConversations[id] = Map<String, dynamic>.from(draft);
    }
  }

  Map<String, dynamic>? findExisting({
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
    return null;
  }

  void deleteConversation({
    required String conversationId,
    required String userId,
  }) {
    final now = DateTime.now().toUtc();
    for (final k in _allUserKeys(userId)) {
      _deletedConvsByUser
          .putIfAbsent(k, () => <String>{})
          .add(conversationId);
      _clearedTimestampsByUser
          .putIfAbsent(k, () => <String, DateTime>{})[conversationId] = now;
      try {
        AppPersistenceService.instance.markConvDeletedForUser(conversationId, k);
      } catch (_) {}
    }

    // Only remove completely from local store if both participants have deleted it
    final conv = _conversations[conversationId] ?? _draftConversations[conversationId];
    bool bothDeleted = false;
    if (conv != null) {
      final pa = conv['participant_a']?.toString() ?? '';
      final pb = conv['participant_b']?.toString() ?? '';
      if (pa.isNotEmpty && pb.isNotEmpty) {
        final paDeleted = isDeletedForUser(conversationId, pa);
        final pbDeleted = isDeletedForUser(conversationId, pb);
        if (paDeleted && pbDeleted) {
          bothDeleted = true;
        }
      }
    }

    if (bothDeleted) {
      _conversations.remove(conversationId);
      _draftConversations.remove(conversationId);
      _messages.remove(conversationId);
      _saveConvsToPrefs();
      _saveMsgsToPrefs();
    }
    _saveUserDeletedToPrefs();
    _saveUserClearedToPrefs();
    _convController.add(null);
    _msgController.add(null);
  }

  Map<String, dynamic> getOrCreate({
    required String userA,
    required String userB,
  }) {
    final existing = findExisting(userA: userA, userB: userB);
    if (existing != null) {
      return existing;
    }

    final id = ChatRepository.generateUuid();
    final now = DateTime.now().toUtc().toIso8601String();
    final draftConv = {
      'id': id,
      'participant_a': userA,
      'participant_b': userB,
      'last_message': '',
      'last_message_at': now,
      'created_at': now,
      'is_draft': true,
    };
    _draftConversations[id] = draftConv;
    return draftConv;
  }

  Map<String, Map<String, dynamic>> getConversationsForMap(String uid) {
    final result = <String, Map<String, dynamic>>{};
    for (final entry in _conversations.entries) {
      if (isDeletedForUser(entry.key, uid)) continue;
      final c = entry.value;
      final msgs = getMessages(entry.key, userId: uid);
      final lastMsg = (c['last_message'] as String?)?.trim() ?? '';
      // Only list active conversations with messages
      if (msgs.isEmpty && lastMsg.isEmpty) continue;

      final pa = c['participant_a'] as String? ?? '';
      final pb = c['participant_b'] as String? ?? '';
      if (pa == uid ||
          pb == uid ||
          _isActorMatch(pa, uid) ||
          _isActorMatch(pb, uid)) {
        result[entry.key] = c;
      }
    }
    return result;
  }

  List<Map<String, dynamic>> getMessages(
    String conversationId, {
    String? userId,
  }) {
    final list = _messages[conversationId] ?? [];
    if (userId == null) return List<Map<String, dynamic>>.from(list);

    final clearedAt =
        getClearedTimestamp(conversationId: conversationId, userId: userId);
    if (clearedAt == null) return List<Map<String, dynamic>>.from(list);

    return list.where((m) {
      final createdAtStr = m['created_at']?.toString();
      if (createdAtStr == null) return false;
      final dt = DateTime.tryParse(createdAtStr)?.toUtc();
      if (dt == null) return false;
      return dt.isAfter(clearedAt.toUtc());
    }).toList();
  }

  int getUnreadCount({
    required String conversationId,
    required String userId,
  }) {
    final normUser = _normalizeUserId(userId);
    final visibleMsgs = getMessages(conversationId, userId: userId);
    return visibleMsgs.where((m) {
      final sender = m['sender_id']?.toString() ?? '';
      final isFromUser =
          _isActorMatch(sender, userId) || _normalizeUserId(sender) == normUser;
      final readAt = m['read_at'];
      return !isFromUser && (readAt == null || readAt.toString().isEmpty);
    }).length;
  }

  void addMessage(Map<String, dynamic> msg) {
    final convId = msg['conversation_id']?.toString() ?? '';
    if (convId.isEmpty) return;

    // Un-delete this conversation for conversation participants so incoming messages appear
    final conv = _conversations[convId];
    if (conv != null) {
      final pa = conv['participant_a']?.toString() ?? '';
      final pb = conv['participant_b']?.toString() ?? '';
      undeleteForUser(convId, pa);
      undeleteForUser(convId, pb);
    } else {
      final sender = msg['sender_id']?.toString() ?? '';
      if (sender.isNotEmpty) {
        undeleteForUser(convId, sender);
      }
    }

    _messages.putIfAbsent(convId, () => []);
    final list = _messages[convId]!;

    final id = msg['id']?.toString();
    final idx = list.indexWhere((m) => m['id']?.toString() == id);
    if (idx != -1) {
      list[idx] = msg;
    } else {
      list.add(msg);
    }

    if (_draftConversations.containsKey(convId)) {
      final draft = _draftConversations.remove(convId)!;
      draft['last_message'] = msg['text'] ?? '';
      draft['last_message_at'] = msg['created_at'] ?? DateTime.now().toUtc().toIso8601String();
      _conversations[convId] = draft;
      _saveConvsToPrefs();
    } else if (_conversations.containsKey(convId)) {
      _conversations[convId] = {
        ..._conversations[convId]!,
        'last_message': msg['text'] ?? '',
        'last_message_at': msg['created_at'] ?? '',
      };
      _saveConvsToPrefs();
    }
    _saveMsgsToPrefs();

    _msgController.add(null);
    _convController.add(null);
  }

  void setSupabaseMessages(
      String conversationId, List<Map<String, dynamic>> remote) {
    final sorted = List<Map<String, dynamic>>.from(remote)
      ..sort((a, b) {
        final ta = a['created_at']?.toString() ?? '';
        final tb = b['created_at']?.toString() ?? '';
        return ta.compareTo(tb);
      });

    _messages[conversationId] = sorted;
    _saveMsgsToPrefs();
    _msgController.add(null);
  }

  void markRead({
    required String conversationId,
    required String userId,
  }) {
    final list = _messages[conversationId];
    if (list != null) {
      final normUser = _normalizeUserId(userId);
      final now = DateTime.now().toUtc().toIso8601String();
      bool changed = false;
      for (var i = 0; i < list.length; i++) {
        final sid = list[i]['sender_id']?.toString() ?? '';
        final isFromUser =
            _isActorMatch(sid, userId) || _normalizeUserId(sid) == normUser;
        if (!isFromUser &&
            (list[i]['read_at'] == null ||
                list[i]['read_at'].toString().isEmpty)) {
          list[i] = {...list[i], 'read_at': now};
          changed = true;
        }
      }
      if (changed) {
        _saveMsgsToPrefs();
        _msgController.add(null);
        _convController.add(null);
      }
    }
  }

  void markAllRead({required String userId}) {
    final normUser = _normalizeUserId(userId);
    final now = DateTime.now().toUtc().toIso8601String();
    bool changed = false;
    for (final entry in _messages.entries) {
      final list = entry.value;
      for (var i = 0; i < list.length; i++) {
        final sid = list[i]['sender_id']?.toString() ?? '';
        final isFromUser =
            _isActorMatch(sid, userId) || _normalizeUserId(sid) == normUser;
        if (!isFromUser &&
            (list[i]['read_at'] == null ||
                list[i]['read_at'].toString().isEmpty)) {
          list[i] = {...list[i], 'read_at': now};
          changed = true;
        }
      }
    }
    if (changed) {
      _saveMsgsToPrefs();
      _msgController.add(null);
      _convController.add(null);
    }
  }
}
