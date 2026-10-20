import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/core/widgets/persona_switcher_modal.dart';
import 'package:you_too_art/features/chats/providers/chat_provider.dart';
import 'package:you_too_art/features/chats/widgets/chat_tile.dart';
import 'package:you_too_art/features/chats/widgets/new_chat_modal.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';

/// Main Chats Screen matching Figma Image 2 (node 118:7675).
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openNewChatModal() async {
    final selectedTalent = await showModalBottomSheet<TalentModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewChatModal(),
    );

    if (selectedTalent != null && mounted) {
      final convId = await ref
          .read(chatListProvider.notifier)
          .startConversationWith(selectedTalent);
      if (mounted) {
        context.push(
          AppRoutes.chatRoom,
          extra: ChatRoomArgs(
            conversationId: convId,
            peerTalent: selectedTalent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatListProvider);
    final conversations = chatState.filteredConversations;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header: "Chat" Title + PersonaBadge + 3-dots ───
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  const Text(
                    'Chat',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  const PersonaBadge(),
                  const SizedBox(width: 8),
                  Container(
                    width: 38,
                    height: 38,
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
                      onSelected: (val) async {
                        if (val == 'new_chat') {
                          _openNewChatModal();
                        } else if (val == 'mark_read') {
                          await ref.read(chatListProvider.notifier).markAllAsRead();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('All conversations marked as read'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'new_chat',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18, color: Colors.black),
                              SizedBox(width: 10),
                              Text('New Message', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'mark_read',
                          child: Row(
                            children: [
                              Icon(Icons.done_all, size: 18, color: Colors.black),
                              SizedBox(width: 10),
                              Text('Mark all as read', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Search Bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1.2,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (query) {
                    ref.read(chatListProvider.notifier).setSearchQuery(query);
                  },
                  cursorColor: Colors.black,
                  decoration: InputDecoration(
                    hintText: 'Search Messages',
                    hintStyle: const TextStyle(
                      fontSize: 14.5,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF9CA3AF),
                      size: 22,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Color(0xFF9CA3AF),
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(chatListProvider.notifier)
                                  .setSearchQuery('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ─── Conversations List ──────────────────────────────────────
            Expanded(
              child: chatState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : conversations.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount: conversations.length,
                          itemBuilder: (context, index) {
                            final conv = conversations[index];
                            return Dismissible(
                              key: Key(conv.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: const Color(0xFFEF4444),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_outline, color: Colors.white, size: 22),
                                    SizedBox(width: 6),
                                    Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              confirmDismiss: (_) async {
                                return await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Text('Delete Conversation?'),
                                    content: Text(
                                      'Delete conversation with ${conv.peerName}? All messages will be permanently removed.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(color: Color(0xFF6B7280)),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ) ?? false;
                              },
                              onDismissed: (_) {
                                ref.read(chatListProvider.notifier).deleteConversation(conv.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Conversation with ${conv.peerName} deleted'),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: ChatTile(
                                conversation: conv,
                                onTap: () {
                                  ref
                                      .read(chatListProvider.notifier)
                                      .markConversationAsRead(conv.id);
                                  final peer = conv.peerTalent ??
                                      TalentModel(
                                        id: conv.peerId,
                                        name: conv.peerName,
                                        roles: conv.peerRole,
                                        avatarUrl: conv.peerAvatarUrl,
                                      );
                                  context.push(
                                    AppRoutes.chatRoom,
                                    extra: ChatRoomArgs(
                                      conversationId: conv.id,
                                      peerTalent: peer,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),

      // ─── Floating Action Button: Black circle with white edit icon ───
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewChatModal,
        backgroundColor: Colors.black,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.edit_outlined,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 12),
              Text(
                'No messages found for "$query"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Conversations Yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Message your connected artists to collaborate on exciting projects!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openNewChatModal,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Start Chatting'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
