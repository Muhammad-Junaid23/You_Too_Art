import 'package:flutter/material.dart';

import 'package:you_too_art/app/constants/app_colors.dart';

/// Bottom sheet shown after a profile save succeeds.
/// Displays a green success circle and a "Proceed to Home" button.
class ProfileCompleteSheet extends StatelessWidget {
  final String firstName;
  final VoidCallback onProceed;

  const ProfileCompleteSheet({
    super.key,
    required this.firstName,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 176,
            height: 176,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 176,
                  height: 176,
                  decoration: BoxDecoration(
                    color: colors.successSurface.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: colors.successSurface.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 44),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Profile Complete',
            style: text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
              children: [
                const TextSpan(text: 'Thanks '),
                TextSpan(
                  text: firstName,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' for completing your profile.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onProceed,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(55),
                ),
              ),
              child: const Text('Proceed to Home'),
            ),
          ),
        ],
      ),
    );
  }
}
