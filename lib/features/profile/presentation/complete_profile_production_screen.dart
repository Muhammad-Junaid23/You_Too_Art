import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/app/constants/app_colors.dart';
import 'package:you_too_art/core/providers/geo_providers.dart';
import 'package:you_too_art/core/utils/role_formatter.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/profile/providers/complete_profile_production_provider.dart';
import 'package:you_too_art/features/profile/widgets/profile_avatar_picker.dart';
import 'package:you_too_art/features/profile/widgets/profile_complete_sheet.dart';

class CompleteProfileProductionScreen extends ConsumerStatefulWidget {
  const CompleteProfileProductionScreen({super.key});

  @override
  ConsumerState<CompleteProfileProductionScreen> createState() =>
      _CompleteProfileProductionScreenState();
}

class _CompleteProfileProductionScreenState
    extends ConsumerState<CompleteProfileProductionScreen> {
  final _nameController = TextEditingController();
  final _incorporationController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _incorporationController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _onCreateProfile() async {
    final ok = await ref.read(productionProfileProvider.notifier).save();
    if (!mounted) return;

    if (ok) {
      _showProfileCompleteSheet();
    } else {
      final msg =
          ref.read(productionProfileProvider).errorMessage ??
          'Could not save profile';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showProfileCompleteSheet() {
    final name = ref.read(productionProfileProvider).companyName;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileCompleteSheet(
        firstName: name,
        onProceed: () {
          Navigator.of(context).pop();
          context.go(AppRoutes.home);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    final profile = ref.watch(productionProfileProvider);
    final auth = ref.watch(authProvider);

    final countriesAsync = ref.watch(countriesProvider);
    final citiesAsync = profile.country == null
        ? const AsyncValue.data(<Map<String, dynamic>>[])
        : ref.watch(citiesProvider(profile.country!));

    final roleLabel = RoleFormatter.format(auth.role ?? 'Production House');

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
                      'Complete Profile',
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                        children: [
                          const TextSpan(text: 'Category: '),
                          TextSpan(
                            text: roleLabel,
                            style: TextStyle(
                              color: colors.link,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    ProfileAvatarPicker(
                      currentUrl: profile.profileImagePath,
                      onUploaded: (url) => ref
                          .read(productionProfileProvider.notifier)
                          .setProfileImage(url),
                    ),
                    const SizedBox(height: 20),

                    _RequiredField(
                      label: 'Name',
                      controller: _nameController,
                      onChanged: (v) => ref
                          .read(productionProfileProvider.notifier)
                          .setCompanyName(v),
                    ),
                    const SizedBox(height: 16),

                    _RequiredField(
                      label: 'Incorporation Number',
                      controller: _incorporationController,
                      onChanged: (v) => ref
                          .read(productionProfileProvider.notifier)
                          .setIncorporationNumber(v),
                    ),
                    const SizedBox(height: 16),

                    _YearDropdown(
                      label: 'Established Year',
                      value: profile.establishedYear,
                      hint: 'Choose Year',
                      onChanged: (v) => ref
                          .read(productionProfileProvider.notifier)
                          .setEstablishedYear(v),
                    ),
                    const SizedBox(height: 16),

                    _RequiredField(
                      label: 'Address',
                      controller: _addressController,
                      onChanged: (v) => ref
                          .read(productionProfileProvider.notifier)
                          .setAddress(v),
                    ),
                    const SizedBox(height: 16),

                    _DropdownField(
                      label: 'Country',
                      value: profile.country,
                      hint: 'Choose Country',
                      items: countriesAsync.when(
                        data: (list) => list
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c['code'] as String,
                                child: Text(c['name'] as String),
                              ),
                            )
                            .toList(),
                        loading: () => const [],
                        error: (_, _) => const [],
                      ),
                      onChanged: (v) {
                        ref
                            .read(productionProfileProvider.notifier)
                            .setCountry(v);
                        ref
                            .read(productionProfileProvider.notifier)
                            .clearCity();
                      },
                    ),
                    const SizedBox(height: 16),

                    _DropdownField(
                      label: 'City',
                      value: profile.city,
                      hint: 'Choose City',
                      items: citiesAsync.when(
                        data: (list) => list
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c['name'] as String,
                                child: Text(c['name'] as String),
                              ),
                            )
                            .toList(),
                        loading: () => const [],
                        error: (_, _) => const [],
                      ),
                      onChanged: (v) => ref
                          .read(productionProfileProvider.notifier)
                          .setCity(v),
                    ),
                    const SizedBox(height: 16),

                    _RequiredField(
                      label: 'Short Bio',
                      controller: _bioController,
                      maxLines: 4,
                      onChanged: (v) => ref
                          .read(productionProfileProvider.notifier)
                          .setBio(v),
                    ),
                    const SizedBox(height: 16),

                    _RequiredField(
                      label: 'Official Website',
                      controller: _websiteController,
                      hintText: 'e.g. www.studiofilms.com',
                      isRequired: false,
                      onChanged: (v) => ref
                          .read(productionProfileProvider.notifier)
                          .setWebsite(v),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom action row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: profile.isSaving ? null : _onCreateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.surface,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(55),
                          ),
                        ),
                        child: profile.isSaving
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
                            : const Text('Create Profile'),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text.rich(
                TextSpan(
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                  children: [
                    const TextSpan(
                      text: 'by creating an account, you agree with the ',
                    ),
                    TextSpan(
                      text: 'Terms & Conditions',
                      style: TextStyle(
                        color: colors.link,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: ' of '),
                    TextSpan(
                      text: 'You2Art',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets (private to this screen) ────────────────

class _RequiredField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final void Function(String) onChanged;
  final bool isRequired;
  final String? hintText;

  const _RequiredField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    required this.onChanged,
    this.isRequired = true,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
            children: [
              TextSpan(text: label),
              if (isRequired)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: colors.required),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: maxLines > 1 ? 14 : 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final List<DropdownMenuItem<String>> items;
  final void Function(String?) onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final validValue = items.any((i) => i.value == value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
            children: [
              TextSpan(text: label),
              TextSpan(
                text: ' *',
                style: TextStyle(color: colors.required),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: validValue,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(hintText: hint),
          isExpanded: true,
        ),
      ],
    );
  }
}

class _YearDropdown extends StatelessWidget {
  final String label;
  final int? value;
  final String hint;
  final void Function(int?) onChanged;

  const _YearDropdown({
    required this.label,
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    final currentYear = DateTime.now().year;
    final years = List<int>.generate(
      currentYear - 1900 + 1,
      (i) => currentYear - i,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
            children: [
              TextSpan(text: label),
              TextSpan(
                text: ' *',
                style: TextStyle(color: colors.required),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: years.contains(value) ? value : null,
          items: years
              .map(
                (y) =>
                    DropdownMenuItem<int>(value: y, child: Text(y.toString())),
              )
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(hintText: hint),
          isExpanded: true,
        ),
      ],
    );
  }
}
