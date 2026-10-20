import 'package:flutter/foundation.dart';

enum NotificationType {
  castingCall,
  like,
  connectionRequest,
  castingApplication,
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
    this.requestStatus = ConnectionRequestNotificationStatus.none,
    this.isRead = false,
  });

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
      'requestStatus': requestStatus.name,
      'isRead': isRead,
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
      requestStatus: ConnectionRequestNotificationStatus.values.firstWhere(
        (e) => e.name == json['requestStatus'],
        orElse: () => ConnectionRequestNotificationStatus.none,
      ),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}
