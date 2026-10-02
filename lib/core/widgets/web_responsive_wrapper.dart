import 'package:flutter/material.dart';

import 'package:you_too_art/app/constants/app_colors.dart';

/// Wraps the application to enforce a mobile-first layout (~430px max width).
///
/// On desktop and web viewports wider than 430px:
/// - Centers the application horizontally.
/// - Constrains the width to 430px (standard modern mobile viewport).
/// - Adds a subtle container border and shadow for an app-like frame.
/// - Uses a neutral dark background outside the mobile frame.
///
/// On native mobile or smaller screens:
/// - Fills the full screen width with zero extra decoration.
class WebResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const WebResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 430.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If viewport is small enough or on mobile, render directly
        if (constraints.maxWidth <= maxWidth) {
          return child;
        }

        final colors = AppColors.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final outerBackground = isDark
            ? const Color(0xFF0F1117)
            : const Color(0xFFE2E8F0);

        return ColoredBox(
          color: outerBackground,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: constraints.maxHeight,
              ),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    vertical: BorderSide(
                      color: colors.border.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
