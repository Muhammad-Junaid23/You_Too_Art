import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:you_too_art/core/widgets/app_avatar.dart';
import 'package:you_too_art/features/chats/models/conversation_model.dart';

class ChatTile extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 2) {
      return 'Just Now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} mins ago';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      return '${diff.inHours} ${diff.inHours == 1 ? "hour" : "hours"} ago';
    } else if (diff.inDays == 1 || (diff.inHours < 48 && dt.day == now.day - 1)) {
      return 'Yesterday, at ${DateFormat('h:mm a').format(dt)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ─── Avatar with online green status dot ────────────────
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppAvatar(
                      imageUrl: conversation.peerAvatarUrl,
                      name: conversation.peerName,
                      radius: 26,
                    ),
                    if (conversation.isOnline)
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF12B76A),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // ─── Name & Message Preview ─────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Peer Name
                      Text(
                        conversation.peerName,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),

                      // Message Preview with Read Checkmarks (if sent by user)
                      Row(
                        children: [
                          if (conversation.isLastMessageMine) ...[
                            Icon(
                              conversation.isLastMessageRead
                                  ? Icons.done_all
                                  : Icons.check,
                              size: 15,
                              color: conversation.isLastMessageRead
                                  ? const Color(0xFF3899F3)
                                  : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              conversation.lastMessage.isNotEmpty
                                  ? conversation.lastMessage
                                  : 'Started a conversation',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: hasUnread
                                    ? Colors.black
                                    : const Color(0xFF6B7280),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Timestamp
                      Text(
                        _formatTimestamp(conversation.lastMessageAt),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Trailing Unread Badge (matching Figma) ─────────────
                if (hasUnread) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD8EDFE),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      conversation.unreadCount > 9
                          ? '9+'
                          : '${conversation.unreadCount}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 0.5,
            indent: 72,
            endIndent: 16,
            color: Color(0xFFF0F1F3),
          ),
        ],
      ),
    );
  }
}
