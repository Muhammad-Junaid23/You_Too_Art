import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:you_too_art/features/home/models/post_item.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';
import 'package:you_too_art/features/home/widgets/post_card.dart';

/// Screen supporting Recent Searches and Search Results matching Figma Image 5.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _recentKeywords = [
    'Don 3 Auditions',
    'Ranveer Singh',
  ];

  final List<Map<String, String>> _recentPeople = [
    {
      'name': 'Muhammad Ali Nizami',
      'subtitle': 'Connection',
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
    },
    {
      'name': 'Yasir Hafeez',
      'subtitle': 'Connection',
      'avatar': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onKeywordSelected(String keyword) {
    _searchController.text = keyword;
    setState(() {
      _searchQuery = keyword.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(homeFeedProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF000000)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 20),
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF000000),
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF9B9B9B),
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Color(0xFF9B9B9B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                hintText: 'Search',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9B9B9B),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFE6E7E8),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFE6E7E8),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFE6E7E8),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _searchQuery.isEmpty
          ? _buildRecentSearches()
          : _buildSearchResults(feedAsync.value ?? []),
    );
  }

  Widget _buildRecentSearches() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Searches',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9B9B9B),
              ),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  _recentKeywords.clear();
                  _recentPeople.clear();
                });
              },
              child: const Text(
                'See All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3899F3),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Recent Keywords
        ..._recentKeywords.map((keyword) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE7F3FE),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Color(0xFF3899F3),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    onTap: () => _onKeywordSelected(keyword),
                    child: Text(
                      keyword,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _recentKeywords.remove(keyword);
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF2F4F7),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Color(0xFF9B9B9B),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        // Recent People
        ..._recentPeople.map((person) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE7F3FE),
                  backgroundImage: NetworkImage(person['avatar']!),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    onTap: () => _onKeywordSelected(person['name']!),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person['name']!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF000000),
                          ),
                        ),
                        Text(
                          person['subtitle']!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9B9B9B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _recentPeople.remove(person);
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF2F4F7),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Color(0xFF9B9B9B),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSearchResults(List<PostItem> posts) {
    final matching = posts.where((p) {
      return p.caption.toLowerCase().contains(_searchQuery) ||
          p.authorName.toLowerCase().contains(_searchQuery);
    }).toList();

    if (matching.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 56,
                color: Color(0xFFB8BFC8),
              ),
              const SizedBox(height: 16),
              Text(
                'No results for "$_searchQuery"',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF000000),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try searching for actors, directors, or hashtags like #Audition',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9B9B9B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: matching.length,
      itemBuilder: (context, index) {
        return PostCard(post: matching[index]);
      },
    );
  }
}
