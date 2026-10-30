import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:you_too_art/core/widgets/app_avatar.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/home/models/post_item.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';
import 'package:you_too_art/features/home/widgets/post_card.dart';
import 'package:you_too_art/features/profile/presentation/user_profile_screen.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';

/// Screen supporting persistent Recent Searches and live search results matching Figma design.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const String _recentKey = 'recent_searches_list_v1';
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _recentKeywords = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getStringList(_recentKey);
    if (saved != null) {
      setState(() {
        _recentKeywords = List<String>.from(saved);
      });
    }
  }

  Future<void> _saveKeyword(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final list = List<String>.from(_recentKeywords);
    list.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
    list.insert(0, trimmed);
    if (list.length > 15) list.removeLast();

    setState(() {
      _recentKeywords = list;
    });
    await prefs.setStringList(_recentKey, list);
  }

  Future<void> _removeKeyword(String keyword) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final list = List<String>.from(_recentKeywords);
    list.removeWhere((item) => item.toLowerCase() == keyword.toLowerCase());
    setState(() {
      _recentKeywords = list;
    });
    await prefs.setStringList(_recentKey, list);
  }

  Future<void> _clearAllKeywords() async {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _recentKeywords.clear();
    });
    await prefs.remove(_recentKey);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onKeywordSelected(String keyword) {
    _searchController.text = keyword;
    _saveKeyword(keyword);
    setState(() {
      _searchQuery = keyword.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(homeFeedProvider);
    final usersAsync = ref.watch(allRegisteredUsersProvider);

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
              onSubmitted: (val) {
                _saveKeyword(val);
              },
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF000000),
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                hoverColor: Colors.transparent,
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF9B9B9B),
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            size: 18, color: Color(0xFF9B9B9B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                hintText: 'Search posts, talent, categories...',
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
                    color: Color(0xFF3899F3),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _searchQuery.isEmpty
          ? _buildRecentSearches()
          : _buildSearchResults(
              feedAsync.value ?? [],
              usersAsync.value ?? [],
            ),
    );
  }

  Widget _buildRecentSearches() {
    if (_recentKeywords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F4F7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 28,
                  color: Color(0xFF8E95A0),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'No recent searches',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Search for posts, production houses, actors, or keywords.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8E95A0),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
              onTap: _clearAllKeywords,
              child: const Text(
                'Clear All',
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
                  onTap: () => _removeKeyword(keyword),
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

  Widget _buildSearchResults(
    List<PostItem> posts,
    List<dynamic> users,
  ) {
    final matchingPosts = posts.where((p) {
      return p.caption.toLowerCase().contains(_searchQuery) ||
          p.authorName.toLowerCase().contains(_searchQuery);
    }).toList();

    final matchingUsers = users.where((u) {
      final name = (u.name as String? ?? '').toLowerCase();
      final first = (u.firstName as String? ?? '').toLowerCase();
      final last = (u.lastName as String? ?? '').toLowerCase();
      final role = (u.role as String? ?? '').toLowerCase();
      return name.contains(_searchQuery) ||
          first.contains(_searchQuery) ||
          last.contains(_searchQuery) ||
          role.contains(_searchQuery);
    }).toList();

    if (matchingPosts.isEmpty && matchingUsers.isEmpty) {
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
                'Try searching with a different name, role, or keyword.',
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

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Matching Users / Profiles
        if (matchingUsers.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Profiles',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          ...matchingUsers.map((u) {
            final displayName = u.name.isNotEmpty
                ? u.name
                : (u.firstName.isNotEmpty
                    ? '${u.firstName} ${u.lastName}'.trim()
                    : u.email.split('@').first);
            final role = u.role != 'unset' ? u.role : 'Artist';

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: AppAvatar(
                imageUrl: u.profileImagePath,
                name: displayName,
                radius: 20,
              ),
              title: Text(
                displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                role,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8E95A0),
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Color(0xFF8E95A0),
              ),
              onTap: () {
                _saveKeyword(displayName);
                final talent = TalentModel.fromUser(u);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(initialTalent: talent),
                  ),
                );
              },
            );
          }),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
        ],

        // Matching Feed Posts
        if (matchingPosts.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Posts',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          ...matchingPosts.map((post) => PostCard(post: post)),
        ],
      ],
    );
  }
}
