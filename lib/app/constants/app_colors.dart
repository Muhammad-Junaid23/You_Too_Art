import 'package:flutter/material.dart';

/// Brand palette with light/dark resolution.
///
/// Screens should read colors via `AppColors.of(context).<token>`.
/// Never touch `_light` / `_dark` directly, and never branch on
/// `Theme.of(context).brightness` in a widget.
///
/// Placeholder hex values — swap after Figma review.
class AppColors {
  // ─── Brand ─────────────────────────────────────────
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color accent;

  // ─── Text ──────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;

  // ─── Backgrounds ───────────────────────────────────
  final Color scaffold;
  final Color surface;

  // ─── Borders ───────────────────────────────────────
  final Color border;

  // ─── Status ────────────────────────────────────────
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // ─── Misc ──────────────────────────────────────────
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppColors._({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.scaffold,
    required this.surface,
    required this.border,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  /// Resolves the palette for the current brightness.
  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  // ─── Light palette ─────────────────────────────────
  static const AppColors light = AppColors._(
    primary: Color(0xFF6C63FF),
    primaryLight: Color(0xFF9D97FF),
    primaryDark: Color(0xFF4A42DB),
    accent: Color(0xFFFF6584),
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF6B6B80),
    textHint: Color(0xFF9E9EB8),
    scaffold: Color(0xFFF5F5FA),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE0E0E8),
    success: Color(0xFF2ECC71),
    warning: Color(0xFFF39C12),
    error: Color(0xFFE74C3C),
    info: Color(0xFF3498DB),
    shimmerBase: Color(0xFFE0E0E0),
    shimmerHighlight: Color(0xFFF5F5F5),
  );

  // ─── Dark palette ──────────────────────────────────
  static const AppColors dark = AppColors._(
    primary: Color(0xFF6C63FF),
    primaryLight: Color(0xFF9D97FF),
    primaryDark: Color(0xFF4A42DB),
    accent: Color(0xFFFF6584),
    textPrimary: Color(0xFFEAEAEA),
    textSecondary: Color(0xFFB0B0C0),
    textHint: Color(0xFF7A7A90),
    scaffold: Color(0xFF121218),
    surface: Color(0xFF1E1E2C),
    border: Color(0xFF2C2C3E),
    success: Color(0xFF2ECC71),
    warning: Color(0xFFF39C12),
    error: Color(0xFFE74C3C),
    info: Color(0xFF3498DB),
    shimmerBase: Color(0xFF2C2C3E),
    shimmerHighlight: Color(0xFF3A3A50),
  );
}
