import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/core/widgets/persona_switcher_modal.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';
import 'package:you_too_art/features/talent/providers/talent_provider.dart';
import 'package:you_too_art/features/talent/widgets/talent_card.dart';

class TalentScreen extends ConsumerStatefulWidget {
  const TalentScreen({super.key});

  @override
  ConsumerState<TalentScreen> createState() => _TalentScreenState();
}

class _TalentScreenState extends ConsumerState<TalentScreen> {
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



  @override
  Widget build(BuildContext context) {
    final talentState = ref.watch(talentListProvider);
    final talents = talentState.filteredTalents;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header: Title & Notification Bell
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Talent',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      const PersonaBadge(),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          color: Color(0xFF3899F3),
                          size: 26,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No new notifications'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Search Field with single border
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {});
                      ref.read(talentListProvider.notifier).setSearchQuery(val);
                    },
                    style: const TextStyle(fontSize: 15, color: Colors.black),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      hintText: 'Search',
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
                                ref
                                    .read(talentListProvider.notifier)
                                    .setSearchQuery('');
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
                ],
              ),
            ),

            // Top Header Bottom Divider
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF0F1F3),
            ),

            // Main Grid
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(talentListProvider.notifier).fetchTalents(),
                color: const Color(0xFF3899F3),
                child: talentState.isLoading && talentState.talents.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF3899F3),
                        ),
                      )
                    : talents.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_search_rounded,
                                    size: 56,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No talents found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Try searching with a different name or profession keyword.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (_searchController.text.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    TextButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                        ref
                                            .read(talentListProvider.notifier)
                                            .setSearchQuery('');
                                      },
                                      child: const Text(
                                        'Clear Search',
                                        style: TextStyle(
                                          color: Color(0xFF3899F3),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.74,
                            ),
                            itemCount: talents.length,
                            itemBuilder: (context, index) {
                              final talent = talents[index];
                              return TalentCard(
                                talent: talent,
                                onTapProfile: () {
                                  context.push(
                                    AppRoutes.profileDetail,
                                    extra: talent,
                                  );
                                },
                                onConnect: () {
                                  final isProd = talent.isProductionHouse;
                                  if (isProd) {
                                    ref
                                        .read(talentListProvider.notifier)
                                        .toggleFollow(talent.id);

                                    final msg = talent.isFollowing
                                        ? 'Unfollowed ${talent.name}'
                                        : 'Now following ${talent.name}!';

                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(msg),
                                        duration: const Duration(seconds: 1),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } else {
                                    final currentStatus = talent.connectionStatus;
                                    ref
                                        .read(talentListProvider.notifier)
                                        .toggleConnection(talent.id);

                                    String msg;
                                    if (currentStatus == ConnectionStatus.none) {
                                      msg = 'Connection request sent to ${talent.name}!';
                                    } else if (currentStatus == ConnectionStatus.pending) {
                                      msg = 'Cancelled connection request to ${talent.name}';
                                    } else {
                                      msg = 'Removed connection with ${talent.name}';
                                    }

                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(msg),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: currentStatus == ConnectionStatus.none
                                            ? const Color(0xFF3899F3)
                                            : const Color(0xFF474B51),
                                      ),
                                    );
                                  }
                                },
                                onMessage: () {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Direct messaging will be enabled with the upcoming Chats update!',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Color(0xFF3899F3),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
