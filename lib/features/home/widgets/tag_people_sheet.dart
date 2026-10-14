import 'package:flutter/material.dart';
import 'package:you_too_art/core/widgets/app_avatar.dart';

/// Modal bottom sheet for tagging connections matching Figma Image 4.
class TagPeopleSheet extends StatefulWidget {
  final List<String> initialSelectedNames;

  const TagPeopleSheet({
    super.key,
    this.initialSelectedNames = const [],
  });

  static Future<List<String>?> show(
    BuildContext context, {
    List<String> initialSelected = const [],
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TagPeopleSheet(initialSelectedNames: initialSelected),
    );
  }

  @override
  State<TagPeopleSheet> createState() => _TagPeopleSheetState();
}

class _TagPeopleSheetState extends State<TagPeopleSheet> {
  final _searchController = TextEditingController();
  late Set<String> _selectedNames;
  String _searchQuery = '';

  final List<Map<String, String>> _connections = [
    {
      'name': 'Alexander Cole',
      'subtitle': 'Connected, 2 Days Ago',
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
    },
    {
      'name': 'Giana Workman',
      'subtitle': 'Connected, 2 Days Ago',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
    },
    {
      'name': 'Marley Dokidis',
      'subtitle': 'Connected, 2 Days Ago',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    },
    {
      'name': 'Allison Press',
      'subtitle': 'Connected, 2 Days Ago',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    },
    {
      'name': 'Allison Rosser',
      'subtitle': 'Connected, 2 Days Ago',
      'avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150',
    },
    {
      'name': 'Yasir Hafeez',
      'subtitle': 'Connected, 3 Days Ago',
      'avatar': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
    },
    {
      'name': 'Qasim Muneer',
      'subtitle': 'Connected, 4 Days Ago',
      'avatar': 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=150',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedNames = Set<String>.from(widget.initialSelectedNames);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _connections.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c['name']!.toLowerCase().contains(_searchQuery);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFB8BFC8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: "Tag People" + close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tag People',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF000000),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF2F4F7),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF474B51),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _searchController,
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
                  hintText: 'Search people...',
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

          // Section label: "Selected"
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Selected',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9B9B9B),
              ),
            ),
          ),

          // Connections list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 0.5,
                indent: 72,
                color: Color(0xFFE6E7E8),
              ),
              itemBuilder: (context, index) {
                final user = filtered[index];
                final name = user['name']!;
                final isSelected = _selectedNames.contains(name);

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedNames.remove(name);
                      } else {
                        _selectedNames.add(name);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        AppAvatar(
                          imageUrl: user['avatar'],
                          name: name,
                          radius: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF000000),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user['subtitle']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9B9B9B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Trailing check indicator
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? const Color(0xFF3899F3)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF3899F3)
                                  : const Color(0xFFB8BFC8),
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Action Buttons: Cancel and Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE6E7E8))),
            ),
            child: Row(
              children: [
                // Cancel button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE2E2E2),
                        foregroundColor: const Color(0xFF000000),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Tag button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(context, _selectedNames.toList()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000000),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        _selectedNames.isNotEmpty
                            ? 'Tag (${_selectedNames.length})'
                            : 'Tag',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
