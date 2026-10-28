import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/features/chats/providers/chat_provider.dart';

class _NavItem {
  final String label;
  final String svgPath;

  const _NavItem({
    required this.label,
    required this.svgPath,
  });
}

/// Bottom navigation shell strictly matching the Figma design specifications.
class MainWrapper extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainWrapper({super.key, required this.navigationShell});

  static const _items = <_NavItem>[
    _NavItem(
      label: 'Talent',
      svgPath: 'assets/icons/talent_svg.svg',
    ),
    _NavItem(
      label: 'Network',
      svgPath: 'assets/icons/network_svg.svg',
    ),
    _NavItem(
      label: 'Chat',
      svgPath: 'assets/icons/chat_svg.svg',
    ),
    _NavItem(
      label: 'Home',
      svgPath: 'assets/icons/home_svg.svg',
    ),
    _NavItem(
      label: 'Casting',
      svgPath: 'assets/icons/casting_svg.svg',
    ),
    _NavItem(
      label: 'Account',
      svgPath: 'assets/icons/account_svg.svg',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    final unreadChatCount = ref.watch(totalUnreadChatCountProvider);

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
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                final isSelected = index == currentIndex;

                Widget iconWidget = SvgPicture.asset(
                  item.svgPath,
                  width: isSelected ? 20 : 22,
                  height: isSelected ? 20 : 22,
                  colorFilter: ColorFilter.mode(
                    isSelected
                        ? const Color(0xFF3899F3)
                        : const Color(0xFF474B51),
                    BlendMode.srcIn,
                  ),
                );

                if (item.label == 'Chat' && unreadChatCount > 0) {
                  iconWidget = Stack(
                    clipBehavior: Clip.none,
                    children: [
                      iconWidget,
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3899F3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 15,
                            minHeight: 15,
                          ),
                          child: Center(
                            child: Text(
                              unreadChatCount > 99 ? '99+' : '$unreadChatCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return GestureDetector(
                  onTap: () {
                    if (index < AppRoutes.branchNavKeys.length) {
                      final targetNavKey = AppRoutes.branchNavKeys[index];
                      if (targetNavKey.currentState?.canPop() == true) {
                        targetNavKey.currentState?.popUntil((route) => route.isFirst);
                      }
                    }
                    navigationShell.goBranch(
                      index,
                      initialLocation: true,
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
                        iconWidget,
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
        ),
      ),
    );
  }
}
