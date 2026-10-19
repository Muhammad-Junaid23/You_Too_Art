import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/widgets/app_avatar.dart';
import 'package:you_too_art/features/chats/models/chat_message_model.dart';
import 'package:you_too_art/features/chats/providers/chat_provider.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';
import 'package:you_too_art/features/talent/providers/talent_provider.dart';

/// 1-on-1 Chat Room screen strictly matching Figma Image 1.
class ChatRoomScreen extends ConsumerStatefulWidget {
  final ChatRoomArgs args;

  const ChatRoomScreen({
    super.key,
    required this.args,
  });

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isComposing = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    _textCtrl.clear();
    setState(() => _isComposing = false);

    await ref.read(chatRoomProvider(widget.args).notifier).sendMessage(text);
    _scrollToBottom();
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just Now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? "min" : "mins"} ago';
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
    final activePersona = ref.watch(userPersonaProvider);
    final roomState = ref.watch(chatRoomProvider(widget.args));
    final chatListState = ref.watch(chatListProvider);
    final peer = widget.args.peerTalent;

    // Business rule: Only connected users can message each other
    final isConnected = chatListState.canMessageUser(peer.id) ||
        peer.connectionStatus == ConnectionStatus.connected;

    // Auto scroll down when messages change
    ref.listen(chatRoomProvider(widget.args), (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            context.push(AppRoutes.profileDetail, extra: peer);
          },
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              AppAvatar(
                imageUrl: peer.avatarUrl,
                name: peer.name,
                radius: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      peer.name,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Last online, 2 mins ago',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1.2,
              ),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: Colors.black,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (val) {
                if (val == 'view_profile') {
                  context.push(AppRoutes.profileDetail, extra: peer);
                } else if (val == 'clear_chat') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat cleared'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view_profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 18, color: Colors.black),
                      SizedBox(width: 10),
                      Text('View Profile', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_chat',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.black),
                      SizedBox(width: 10),
                      Text('Clear Chat', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 0.8,
            color: Color(0xFFF3F4F6),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Messages List Area ──────────────────────────────────────
            Expanded(
              child: roomState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : roomState.messages.isEmpty
                      ? _buildEmptyRoom(peer)
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount: roomState.messages.length,
                          itemBuilder: (context, index) {
                            final msg = roomState.messages[index];
                            final isMe = msg.isMe(activePersona.id);

                            // Determine if this is the last message in a cluster from the same sender
                            final isLastFromSender =
                                index == roomState.messages.length - 1 ||
                                    roomState.messages[index + 1].senderId !=
                                        msg.senderId;

                            return _buildMessageBubble(
                              msg: msg,
                              isMe: isMe,
                              showTimestamp: isLastFromSender,
                            );
                          },
                        ),
            ),

            // ─── Bottom Bar: Input Bar or Connection Notice ──────────────
            if (isConnected)
              _buildInputBar()
            else
              _buildNotConnectedBanner(context, peer),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required ChatMessageModel msg,
    required bool isMe,
    required bool showTimestamp,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: showTimestamp ? 12.0 : 4.0),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFF3899F3) // Exact Figma outgoing blue
                  : const Color(0xFFF3F4F6), // Exact Figma incoming off-white/grey
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w400,
                color: isMe ? Colors.white : const Color(0xFF111827),
                height: 1.35,
              ),
            ),
          ),

          // Timestamp shown below the bubble matching Figma Image 1
          if (showTimestamp) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _formatTimestamp(msg.createdAt),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          // Rounded Pill Text Field
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1.2,
                ),
              ),
              child: TextField(
                controller: _textCtrl,
                onChanged: (val) {
                  final composing = val.trim().isNotEmpty;
                  if (composing != _isComposing) {
                    setState(() => _isComposing = composing);
                  }
                },
                onSubmitted: (_) => _sendMessage(),
                cursorColor: Colors.black,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: Colors.black,
                ),
                decoration: const InputDecoration(
                  hintText: 'Enter your message',
                  hintStyle: TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Black Circular Send Button with Forward Arrow
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnectedBanner(BuildContext context, TalentModel peer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: Color(0xFF6B7280),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Only connected artists can message each other.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              ref.read(talentListProvider.notifier).toggleConnection(peer.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Connection request sent to ${peer.name}!'),
                  backgroundColor: const Color(0xFF3899F3),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Connect', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRoom(TalentModel peer) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppAvatar(
              imageUrl: peer.avatarUrl,
              name: peer.name,
              radius: 36,
            ),
            const SizedBox(height: 14),
            Text(
              peer.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              peer.roles,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You are connected! Say hello and start collaborating.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
