import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// Bottom navigation shell strictly matching the Figma design specifications.
class MainWrapper extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainWrapper({super.key, required this.navigationShell});

  static const _items = <_NavItem>[
    _NavItem(
      label: 'Talent',
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
    ),
    _NavItem(
      label: 'Network',
      icon: Icons.language_rounded,
      selectedIcon: Icons.language_rounded,
    ),
    _NavItem(
      label: 'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
    ),
    _NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavItem(
      label: 'Casting',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
    ),
    _NavItem(
      label: 'Account',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.black.withValues(alpha: 0.10),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Navigation Items Row
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_items.length, (index) {
                    final item = _items[index];
                    final isSelected = index == currentIndex;

                    return GestureDetector(
                      onTap: () {
                        navigationShell.goBranch(
                          index,
                          initialLocation: index == currentIndex,
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: isSelected
                            ? const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              )
                            : const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE7F3FE)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              size: isSelected ? 20 : 23,
                              color: isSelected
                                  ? const Color(0xFF3899F3)
                                  : const Color(0xFF474B51),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 6),
                              Text(
                                item.label,
                                style: const TextStyle(
                                  color: Color(0xFF3899F3),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Bottom Home Indicator Bar matching Figma
              Container(
                margin: const EdgeInsets.only(top: 2, bottom: 6),
                width: 134,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFB8BFC8),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
