import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/app/constants/app_colors.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';

/// Role options shown on Choose Category.
/// The value is what we store in `users.role`; the label is what's shown.
class RoleOption {
  final String value;
  final String label;
  const RoleOption(this.value, this.label);
}

const _roles = <RoleOption>[
  RoleOption('production_house', 'Production House'),
  RoleOption('director', 'Director'),
  RoleOption('actor', 'Actor'),
  RoleOption('singer', 'Singer'),
  RoleOption('musician', 'Musician'),
  RoleOption('dancer', 'Dancer'),
  RoleOption('choreographer', 'Choreographer'),
  RoleOption('editor', 'Editor'),
  RoleOption('cinematographer', 'Cinematographer'),
  RoleOption('still_photographer', 'Still Photographer'),
  RoleOption('sound_mixing', 'Sound Mixing'),
  RoleOption('vfx', 'VFX'),
  RoleOption('producer', 'Producer'),
  RoleOption('stunt_director', 'Stunt Director'),
  RoleOption('art_director', 'Art Director'),
  RoleOption('dubbing_artist', 'Dubbing Artist'),
  RoleOption('makeup_artist', 'Makeup Artist'),
  RoleOption('costume_designer', 'Costume Designer'),
  RoleOption('anchor', 'Anchor'),
  RoleOption('standup_comedian', 'Standup Comedian'),
  RoleOption('writer', 'Writer'),
];

class ChooseCategoryScreen extends ConsumerStatefulWidget {
  const ChooseCategoryScreen({super.key});

  @override
  ConsumerState<ChooseCategoryScreen> createState() =>
      _ChooseCategoryScreenState();
}

class _ChooseCategoryScreenState extends ConsumerState<ChooseCategoryScreen> {
  String? _selected;
  bool _saving = false;

  Future<void> _onSave() async {
    final role = _selected;
    if (role == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(authProvider).isLoggedIn
          ? (await _currentUid())
          : null;
      if (uid == null) {
        throw StateError('No signed-in user');
      }

      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.updateProfile(uid: uid, updates: {'role': role});

      if (!mounted) return;
      // Branch by role
      if (role == 'production_house') {
        context.go(AppRoutes.completeProfileProduction);
      } else {
        context.go(AppRoutes.completeProfileIndividual);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<String?> _currentUid() async {
    // AuthRepository is available via authRepositoryProvider
    final repo = ref.read(authRepositoryProvider);
    return repo.currentUid;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 24,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Choose Category',
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Two-column grid of pills
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _roles.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 3.6,
                          ),
                      itemBuilder: (context, i) {
                        final role = _roles[i];
                        final selected = _selected == role.value;
                        return _RolePill(
                          label: role.label,
                          selected: selected,
                          onTap: () => setState(() => _selected = role.value),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bottom bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => context.go(AppRoutes.home),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: colors.border,
                          foregroundColor: colors.textSecondary,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(55),
                          ),
                        ),
                        child: const Text('Skip For Now'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.surface,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(55),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Save and Next'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RolePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colors.link.withValues(alpha: 0.10)
              : colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? colors.link : colors.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Radio circle
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? colors.link : colors.border,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors.link,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
