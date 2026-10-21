import 'package:flutter/foundation.dart';

enum NotificationType {
  castingCall,
  like,
  connectionRequest,
  connectionAccepted,
  castingApplication,
  comment,
  chatMessage,
}

enum ConnectionRequestNotificationStatus {
  none,
  pending,
  accepted,
  rejected,
}

@immutable
class NotificationItem {
  final String id;
  final NotificationType type;
  final String primarySubject;
  final String actionText;
  final String? targetObject;
  final String timeAgo;
  final DateTime timestamp;
  final String? avatarUrl;
  final bool isFilmfare;
  final bool isCastingIcon;
  final String? senderId;
  final String? recipientId;
  final String? actorId;
  final String? entityType;
  final String? entityId;
  final ConnectionRequestNotificationStatus requestStatus;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.primarySubject,
    required this.actionText,
    this.targetObject,
    required this.timeAgo,
    required this.timestamp,
    this.avatarUrl,
    this.isFilmfare = false,
    this.isCastingIcon = false,
    this.senderId,
    this.recipientId,
    this.actorId,
    this.entityType,
    this.entityId,
    this.requestStatus = ConnectionRequestNotificationStatus.none,
    this.isRead = false,
  });

  static String formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  NotificationItem copyWith({
    String? id,
    NotificationType? type,
    String? primarySubject,
    String? actionText,
    String? targetObject,
    String? timeAgo,
    DateTime? timestamp,
    String? avatarUrl,
    bool? isFilmfare,
    bool? isCastingIcon,
    String? senderId,
    String? recipientId,
    String? actorId,
    String? entityType,
    String? entityId,
    ConnectionRequestNotificationStatus? requestStatus,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      primarySubject: primarySubject ?? this.primarySubject,
      actionText: actionText ?? this.actionText,
      targetObject: targetObject ?? this.targetObject,
      timeAgo: timeAgo ?? this.timeAgo,
      timestamp: timestamp ?? this.timestamp,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isFilmfare: isFilmfare ?? this.isFilmfare,
      isCastingIcon: isCastingIcon ?? this.isCastingIcon,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      actorId: actorId ?? this.actorId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      requestStatus: requestStatus ?? this.requestStatus,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'primarySubject': primarySubject,
      'actionText': actionText,
      'targetObject': targetObject,
      'timeAgo': timeAgo,
      'timestamp': timestamp.toIso8601String(),
      'avatarUrl': avatarUrl,
      'isFilmfare': isFilmfare,
      'isCastingIcon': isCastingIcon,
      'senderId': senderId,
      'recipientId': recipientId,
      'actorId': actorId,
      'entityType': entityType,
      'entityId': entityId,
      'requestStatus': requestStatus.name,
      'isRead': isRead,
    };
  }

  Map<String, dynamic> toRow() {
    String typeStr;
    switch (type) {
      case NotificationType.castingCall:
        typeStr = 'casting_call';
        break;
      case NotificationType.like:
        typeStr = 'post_like';
        break;
      case NotificationType.comment:
        typeStr = 'post_comment';
        break;
      case NotificationType.connectionRequest:
        typeStr = 'connection_request';
        break;
      case NotificationType.connectionAccepted:
        typeStr = 'connection_accepted';
        break;
      case NotificationType.castingApplication:
        typeStr = 'casting_application';
        break;
      case NotificationType.chatMessage:
        typeStr = 'chat_message';
        break;
    }

    return {
      'id': id,
      'recipient_id': recipientId ?? senderId,
      'actor_id': actorId ?? senderId,
      'type': typeStr,
      'primary_subject': primarySubject,
      'action_text': actionText,
      'target_object': targetObject,
      'entity_type': entityType,
      'entity_id': entityId,
      'avatar_url': avatarUrl,
      'is_filmfare': isFilmfare,
      'is_casting_icon': isCastingIcon,
      'request_status': requestStatus.name,
      'is_read': isRead,
      'created_at': timestamp.toIso8601String(),
    };
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.like,
      ),
      primarySubject: json['primarySubject'] as String? ?? '',
      actionText: json['actionText'] as String? ?? '',
      targetObject: json['targetObject'] as String?,
      timeAgo: json['timeAgo'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      avatarUrl: json['avatarUrl'] as String?,
      isFilmfare: json['isFilmfare'] as bool? ?? false,
      isCastingIcon: json['isCastingIcon'] as bool? ?? false,
      senderId: json['senderId'] as String?,
      recipientId: json['recipientId'] as String?,
      actorId: json['actorId'] as String?,
      entityType: json['entityType'] as String?,
      entityId: json['entityId'] as String?,
      requestStatus: ConnectionRequestNotificationStatus.values.firstWhere(
        (e) => e.name == json['requestStatus'],
        orElse: () => ConnectionRequestNotificationStatus.none,
      ),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  factory NotificationItem.fromRow(Map<String, dynamic> row) {
    final typeStr = row['type']?.toString() ?? '';
    NotificationType type;
    switch (typeStr) {
      case 'casting_call':
        type = NotificationType.castingCall;
        break;
      case 'post_like':
        type = NotificationType.like;
        break;
      case 'post_comment':
        type = NotificationType.comment;
        break;
      case 'connection_request':
        type = NotificationType.connectionRequest;
        break;
      case 'connection_accepted':
        type = NotificationType.connectionAccepted;
        break;
      case 'casting_application':
        type = NotificationType.castingApplication;
        break;
      case 'chat_message':
        type = NotificationType.chatMessage;
        break;
      default:
        type = NotificationType.like;
    }

    final createdAtStr = row['created_at']?.toString() ?? '';
    final dt = DateTime.tryParse(createdAtStr) ?? DateTime.now();

    final statusStr = row['request_status']?.toString() ?? 'none';
    final requestStatus = ConnectionRequestNotificationStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => ConnectionRequestNotificationStatus.none,
    );

    final actorId = row['actor_id']?.toString();
    final recipientId = row['recipient_id']?.toString();

    return NotificationItem(
      id: row['id']?.toString() ?? '',
      type: type,
      primarySubject: row['primary_subject']?.toString() ?? '',
      actionText: row['action_text']?.toString() ?? '',
      targetObject: row['target_object']?.toString(),
      timeAgo: formatTimeAgo(dt),
      timestamp: dt,
      avatarUrl: row['avatar_url']?.toString(),
      isFilmfare: row['is_filmfare'] == true,
      isCastingIcon: row['is_casting_icon'] == true,
      senderId: actorId,
      recipientId: recipientId,
      actorId: actorId,
      entityType: row['entity_type']?.toString(),
      entityId: row['entity_id']?.toString(),
      requestStatus: requestStatus,
      isRead: row['is_read'] == true,
    );
  }
}
