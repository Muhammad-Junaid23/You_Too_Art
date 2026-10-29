import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/features/network/models/network_item.dart';
import 'package:you_too_art/features/notifications/providers/notification_provider.dart';
import 'package:you_too_art/features/network/providers/network_provider.dart';
import 'package:you_too_art/features/network/widgets/network_tiles.dart';

class NetworkScreen extends ConsumerStatefulWidget {
  const NetworkScreen({super.key});

  @override
  ConsumerState<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends ConsumerState<NetworkScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showConnectionOptions(BuildContext context, ConnectionItem connection) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, color: Colors.black87),
                title: const Text('View Profile'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(
                    AppRoutes.profileDetail,
                    extra: connection.talentModel,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF3899F3)),
                title: const Text('Message'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Direct messaging will be enabled with the upcoming Chats update!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Color(0xFF3899F3),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_outlined, color: Colors.red),
                title: const Text('Remove Connection', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(networkProvider.notifier).removeConnection(connection.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Removed ${connection.name} from your connections'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuggestionOptions(BuildContext context, NetworkSuggestionItem suggestion) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, color: Colors.black87),
                title: const Text('View Profile'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(
                    AppRoutes.profileDetail,
                    extra: suggestion.talentModel,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.hide_source_rounded, color: Colors.black87),
                title: const Text('Not interested'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Suggestion dismissed'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final netState = ref.watch(networkProvider);
    final activeTab = netState.activeTab;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar: Title, Persona Badge & Blue Notification Bell
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'My Network',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          color: Color(0xFF3899F3),
                          size: 26,
                        ),
                        onPressed: () =>
                            context.push(AppRoutes.notifications),
                      ),
                      if (ref.watch(notificationProvider).unreadCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              ref
                                          .watch(notificationProvider)
                                          .unreadCount >
                                      9
                                  ? '9+'
                                  : '${ref.watch(notificationProvider).unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Sub-Tabs Header: Requests (N) vs Connections (N)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Row(
                children: [
                  // Requests Tab
                  GestureDetector(
                    onTap: () {
                      ref.read(networkProvider.notifier).setActiveTab(0);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      'Requests (${netState.requests.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            activeTab == 0 ? FontWeight.bold : FontWeight.w500,
                        color: activeTab == 0
                            ? Colors.black
                            : const Color(0xFF8E95A0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Connections Tab
                  GestureDetector(
                    onTap: () {
                      ref.read(networkProvider.notifier).setActiveTab(1);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      'Connections (${netState.connections.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            activeTab == 1 ? FontWeight.bold : FontWeight.w500,
                        color: activeTab == 1
                            ? Colors.black
                            : const Color(0xFF8E95A0),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab View Body
            Expanded(
              child: activeTab == 1
                  ? _buildConnectionsTab(netState)
                  : _buildRequestsTab(netState),
            ),
          ],
        ),
      ),
    );
  }

  /// Connections Tab matching Figma Image 1
  Widget _buildConnectionsTab(NetworkState netState) {
    final connections = netState.filteredConnections;

    return Column(
      children: [
        // Search bar with single outline border
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {});
              ref.read(networkProvider.notifier).setSearchQuery(val);
            },
            style: const TextStyle(fontSize: 15, color: Colors.black),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              hoverColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              hintText: 'Search People',
              hintStyle: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF9E9E9E),
                size: 22,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        size: 18,
                        color: Color(0xFF9E9E9E),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        ref.read(networkProvider.notifier).setSearchQuery('');
                      },
                    )
                  : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFE6E7E8),
                  width: 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF3899F3),
                  width: 1.0,
                ),
              ),
            ),
          ),
        ),

        // Hairline Divider
        const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFF0F1F3),
        ),

        // Connections List
        Expanded(
          child: connections.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 56,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No connections found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'Try searching with a different name.'
                              : 'Your network connections will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  itemCount: connections.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFFF0F1F3),
                  ),
                  itemBuilder: (context, index) {
                    final item = connections[index];
                    return ConnectionTile(
                      connection: item,
                      onTapProfile: () {
                        context.push(
                          AppRoutes.profileDetail,
                          extra: item.talentModel,
                        );
                      },
                      onMoreOptions: () {
                        _showConnectionOptions(context, item);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Requests Tab matching Figma Image 2
  Widget _buildRequestsTab(NetworkState netState) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Pending Requests List
        if (netState.requests.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Center(
              child: Text(
                'No pending connection requests',
                style: TextStyle(
                  color: Color(0xFF8E95A0),
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...netState.requests.map((request) {
            return Column(
              children: [
                RequestTile(
                  request: request,
                  onTapProfile: () {
                    context.push(
                      AppRoutes.profileDetail,
                      extra: request.talentModel,
                    );
                  },
                  onAccept: () {
                    ref
                        .read(networkProvider.notifier)
                        .acceptRequest(request.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Connected with ${request.name}!'),
                        backgroundColor: const Color(0xFF12B76A),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  onDecline: () {
                    ref
                        .read(networkProvider.notifier)
                        .declineRequest(request.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Declined request from ${request.name}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Color(0xFFF0F1F3),
                ),
              ],
            );
          }),

        const SizedBox(height: 14),

        // Section 1: Suggestions
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Suggestions',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8E95A0),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          height: 215,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: netState.suggestions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final suggestion = netState.suggestions[index];
              return NetworkSuggestionCard(
                suggestion: suggestion,
                onTapProfile: () {
                  context.push(
                    AppRoutes.profileDetail,
                    extra: suggestion.talentModel,
                  );
                },
                onToggleRequest: () {
                  ref
                      .read(networkProvider.notifier)
                      .toggleSendSuggestionRequest(suggestion.id);

                  final msg = suggestion.isRequested
                      ? 'Cancelled connection request to ${suggestion.name}'
                      : 'Connection request sent to ${suggestion.name}!';

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: suggestion.isRequested
                          ? const Color(0xFF474B51)
                          : const Color(0xFF3899F3),
                    ),
                  );
                },
                onMoreOptions: () {
                  _showSuggestionOptions(context, suggestion);
                },
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // Hairline Divider
        const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFF0F1F3),
        ),

        const SizedBox(height: 14),

        // Section 2: Recommendations
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Recommendations',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8E95A0),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          height: 215,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: netState.recommendations.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = netState.recommendations[index];
              return NetworkSuggestionCard(
                suggestion: item,
                onTapProfile: () {
                  context.push(
                    AppRoutes.profileDetail,
                    extra: item.talentModel,
                  );
                },
                onToggleRequest: () {
                  ref
                      .read(networkProvider.notifier)
                      .toggleSendSuggestionRequest(item.id);

                  final msg = item.isRequested
                      ? 'Cancelled connection request to ${item.name}'
                      : 'Connection request sent to ${item.name}!';

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: item.isRequested
                          ? const Color(0xFF474B51)
                          : const Color(0xFF3899F3),
                    ),
                  );
                },
                onMoreOptions: () {
                  _showSuggestionOptions(context, item);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
