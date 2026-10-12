import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';
import 'package:you_too_art/features/home/widgets/home_header.dart';
import 'package:you_too_art/features/home/widgets/home_search_bar.dart';
import 'package:you_too_art/features/home/widgets/post_card.dart';
import 'package:you_too_art/features/home/widgets/quick_share_box.dart';

/// Social Feed Home Screen strictly matching Figma Image 1.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(homeFeedProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: const Color(0xFF3899F3),
          onRefresh: () => ref.read(homeFeedProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Top Greeting Header: "Hi Wajahat!" + Blue Bell
              const SliverToBoxAdapter(
                child: HomeHeader(),
              ),

              // Search Bar: Tapping navigates to Recent Searches screen
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: HomeSearchBar(
                    readOnly: true,
                    onTap: () => context.push(AppRoutes.search),
                  ),
                ),
              ),

              // Quick Share Box ("Have something to share?" + Photo & Aa Text)
              SliverToBoxAdapter(
                child: QuickShareBox(
                  onTapShare: () => context.push(AppRoutes.createPost),
                  onTapPhoto: () => context.push(
                    AppRoutes.createPost,
                    extra: {'initialWithPhoto': true},
                  ),
                  onTapText: () => context.push(
                    AppRoutes.createPost,
                    extra: {'initialWithPhoto': false},
                  ),
                ),
              ),

              // Feed Posts List
              feedAsync.when(
                data: (posts) {
                  if (posts.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No posts yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF9B9B9B),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return PostCard(post: posts[index]);
                      },
                      childCount: posts.length,
                    ),
                  );
                },
                loading: () {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF3899F3),
                      ),
                    ),
                  );
                },
                error: (error, _) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Failed to load feed',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () =>
                                  ref.read(homeFeedProvider.notifier).refresh(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3899F3),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Bottom padding so navbar doesn't clip feed content
              const SliverToBoxAdapter(
                child: SizedBox(height: 90),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
