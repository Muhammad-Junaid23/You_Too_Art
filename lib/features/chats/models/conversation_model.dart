import 'package:you_too_art/features/talent/models/talent_model.dart';

class ConversationModel {
  final String id;
  final String participantA;
  final String participantB;
  final String peerId;
  final String peerName;
  final String? peerAvatarUrl;
  final String peerRole;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isOnline;
  final TalentModel? peerTalent;
  final bool isLastMessageMine;
  final bool isLastMessageRead;

  const ConversationModel({
    required this.id,
    required this.participantA,
    required this.participantB,
    required this.peerId,
    required this.peerName,
    this.peerAvatarUrl,
    required this.peerRole,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isOnline = true,
    this.peerTalent,
    this.isLastMessageMine = false,
    this.isLastMessageRead = false,
  });

  factory ConversationModel.fromRow({
    required Map<String, dynamic> row,
    required String currentUserId,
    required TalentModel peerTalent,
    int unreadCount = 0,
    bool isLastMessageMine = false,
    bool isLastMessageRead = false,
  }) {
    final partA = row['participant_a'] as String? ?? '';
    final partB = row['participant_b'] as String? ?? '';
    final peerId = partA == currentUserId ? partB : partA;

    return ConversationModel(
      id: row['id'] as String? ?? '',
      participantA: partA,
      participantB: partB,
      peerId: peerId,
      peerName: peerTalent.name,
      peerAvatarUrl: peerTalent.avatarUrl,
      peerRole: peerTalent.roles,
      lastMessage: row['last_message'] as String? ?? '',
      lastMessageAt: row['last_message_at'] != null
          ? DateTime.tryParse(row['last_message_at'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
      unreadCount: unreadCount,
      peerTalent: peerTalent,
      isLastMessageMine: isLastMessageMine,
      isLastMessageRead: isLastMessageRead,
    );
  }

  ConversationModel copyWith({
    String? id,
    String? participantA,
    String? participantB,
    String? peerId,
    String? peerName,
    String? peerAvatarUrl,
    String? peerRole,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isOnline,
    TalentModel? peerTalent,
    bool? isLastMessageMine,
    bool? isLastMessageRead,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      participantA: participantA ?? this.participantA,
      participantB: participantB ?? this.participantB,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      peerAvatarUrl: peerAvatarUrl ?? this.peerAvatarUrl,
      peerRole: peerRole ?? this.peerRole,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      peerTalent: peerTalent ?? this.peerTalent,
      isLastMessageMine: isLastMessageMine ?? this.isLastMessageMine,
      isLastMessageRead: isLastMessageRead ?? this.isLastMessageRead,
    );
  }
}
