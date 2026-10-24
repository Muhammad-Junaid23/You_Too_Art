import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/app/constants/app_colors.dart';
import 'package:you_too_art/core/providers/geo_providers.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/profile/providers/complete_profile_provider.dart';
import 'package:you_too_art/features/profile/providers/user_portfolio_provider.dart';
import 'package:you_too_art/features/profile/widgets/add_media_sheet.dart';
import 'package:you_too_art/features/profile/widgets/profile_avatar_picker.dart';
import 'package:you_too_art/features/profile/widgets/profile_complete_sheet.dart';

class CompleteProfileIndividualScreen extends ConsumerStatefulWidget {
  const CompleteProfileIndividualScreen({super.key});

  @override
  ConsumerState<CompleteProfileIndividualScreen> createState() =>
      _CompleteProfileIndividualScreenState();
}

class _CompleteProfileIndividualScreenState
    extends ConsumerState<CompleteProfileIndividualScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _onCreateProfile() async {
    final ok = await ref.read(completeProfileProvider.notifier).save();
    if (!mounted) return;

    if (ok) {
      _showProfileCompleteSheet();
    } else {
      final msg =
          ref.read(completeProfileProvider).errorMessage ??
          'Could not save profile';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showProfileCompleteSheet() {
    final name = ref.read(completeProfileProvider).firstName;
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

  Future<void> _deleteItem(String id) async {
    try {
      await ref.read(portfolioRepositoryProvider).deletePortfolioItem(id);
      final uid = ref.read(authProvider.notifier).currentUid ?? '';
      ref.invalidate(userPortfolioProvider(uid));

      // Also remove from local portfolio if present
      final currentPort = AppPersistenceService.instance.getPortfolio(uid);
      final vidIdx = currentPort.videos.indexWhere((v) => v.id == id || v.url == id);
      if (vidIdx != -1) {
        ref.read(userWorkPortfolioProvider.notifier).deleteVideo(vidIdx, uid);
      }
      final photoIdx = currentPort.photos.indexWhere((p) => p.id == id || p.url == id);
      if (photoIdx != -1) {
        ref.read(userWorkPortfolioProvider.notifier).deletePhoto(photoIdx, uid);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    final profile = ref.watch(completeProfileProvider);

    final uid = ref.watch(authProvider.notifier).currentUid;
    final portfolioAsync = uid == null
        ? const AsyncValue.data(<Map<String, dynamic>>[])
        : ref.watch(userPortfolioProvider(uid));

    final allItems = portfolioAsync.value ?? const <Map<String, dynamic>>[];
    final videos = allItems.where((i) => i['media_type'] == 'video').toList();
    final photos = allItems.where((i) => i['media_type'] == 'photo').toList();

    final auth = ref.watch(authProvider);
    final countriesAsync = ref.watch(countriesProvider);
    final citiesAsync = profile.country == null
        ? const AsyncValue.data(<Map<String, dynamic>>[])
        : ref.watch(citiesProvider(profile.country!));

    // Role label — "actor" → "Actor"
    final roleLabel = _titleCase(auth.role ?? 'Actor');

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
                          .read(completeProfileProvider.notifier)
                          .setProfileImage(url),
                    ),
                    const SizedBox(height: 20),

                    // First + Last name row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _RequiredField(
                            label: 'First Name',
                            controller: _firstNameController,
                            onChanged: (v) => ref
                                .read(completeProfileProvider.notifier)
                                .setFirstName(v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RequiredField(
                            label: 'Last Name',
                            controller: _lastNameController,
                            onChanged: (v) => ref
                                .read(completeProfileProvider.notifier)
                                .setLastName(v),
                          ),
                        ),
                      ],
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
                            .read(completeProfileProvider.notifier)
                            .setCountry(v);
                        ref.read(completeProfileProvider.notifier).clearCity();
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
                      onChanged: (v) =>
                          ref.read(completeProfileProvider.notifier).setCity(v),
                    ),
                    const SizedBox(height: 16),

                    _RequiredField(
                      label: 'Short Bio',
                      controller: _bioController,
                      maxLines: 4,
                      onChanged: (v) =>
                          ref.read(completeProfileProvider.notifier).setBio(v),
                    ),
                    const SizedBox(height: 24),

                    _MediaSectionHeader(
                      title: 'Videos (${videos.length})',
                      subtitle: videos.isEmpty
                          ? 'No videos to show'
                          : 'Last updated, just now',
                      onAdd: () => _openMediaSheet('video'),
                    ),
                    if (videos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...videos.map(
                        (v) => _PortfolioTile(
                          item: v,
                          onDelete: () => _deleteItem(v['id'] as String),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _MediaSectionHeader(
                      title: 'Photos (${photos.length})',
                      subtitle: photos.isEmpty
                          ? 'No photos to show'
                          : 'Last updated, just now',
                      onAdd: () => _openMediaSheet('photo'),
                    ),
                    if (photos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...photos.map(
                        (p) => _PortfolioTile(
                          item: p,
                          onDelete: () => _deleteItem(p['id'] as String),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
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

  Future<void> _openMediaSheet(String type) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AddMediaSheet(mediaType: type),
    );

    if (result == null || !mounted) return;

    // Persist to portfolio_items and local persistent portfolio state.
    try {
      final uid = ref.read(authProvider.notifier).currentUid;
      if (uid == null) throw StateError('Not signed in');
      await ref
          .read(portfolioRepositoryProvider)
          .addPortfolioItem(
            userId: uid,
            title: result['title']!,
            mediaUrl: result['url']!,
            mediaType: type,
          );
      ref.invalidate(userPortfolioProvider(uid));

      final isVideo = type.toLowerCase() == 'video';
      final rawMediaUrl = result['url']!;
      final sanitized = resolvePortfolioMediaUrl(rawMediaUrl, isVideo: isVideo);
      final newItem = WorkMediaItem(
        id: 'port_${DateTime.now().millisecondsSinceEpoch}',
        title: result['title']!,
        url: rawMediaUrl,
        mediaUrl: sanitized.isNotEmpty ? sanitized : rawMediaUrl,
        isVideo: isVideo,
        lastUpdated: 'Just Now',
      );

      final currentPort = AppPersistenceService.instance.getPortfolio(uid);
      final isDummy = currentPort.videos.any((v) => v.id == 'vid_1' && v.title.contains('Gilgit-Baltistan'));
      if (isDummy) {
        const emptyPort = UserPortfolioState(videos: [], photos: []);
        AppPersistenceService.instance.savePortfolio(uid, emptyPort);
        AppPersistenceService.instance.savePortfolio('actor', emptyPort);
        AppPersistenceService.instance.savePortfolio(AppPersistenceService.actorDefaultId, emptyPort);
      }

      if (isVideo) {
        ref.read(userWorkPortfolioProvider.notifier).addVideo(newItem, uid);
      } else {
        ref.read(userWorkPortfolioProvider.notifier).addPhoto(newItem, uid);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$type added')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(RegExp(r'[_ ]+'))
        .map(
          (w) => w.isEmpty
              ? ''
              : w[0].toUpperCase() + w.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}

// ─── Reusable sub-widgets ────────────────────────────────

class _RequiredField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final void Function(String) onChanged;

  const _RequiredField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    required this.onChanged,
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

    // Guard: if the current value isn't in the items list, ignore it.
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

class _MediaSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onAdd;

  const _MediaSectionHeader({
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: text.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.successSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add, color: colors.success, size: 20),
          ),
        ),
      ],
    );
  }
}

class _PortfolioTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete;

  const _PortfolioTile({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isVideo = item['media_type'] == 'video';
    final url = item['media_url'] as String? ?? '';
    final title = item['title'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.avatarBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isVideo ? Icons.play_circle_outline : Icons.image_outlined,
              color: colors.link,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: colors.link),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            color: colors.error,
          ),
        ],
      ),
    );
  }
}
