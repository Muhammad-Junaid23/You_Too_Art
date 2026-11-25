import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/app/constants/app_colors.dart';
import 'package:you_too_art/core/providers/geo_providers.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/core/utils/role_formatter.dart';
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
  final _experienceController = TextEditingController();
  final _websiteController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _websiteController.dispose();
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
    final localPortfolio = ref.watch(userWorkPortfolioProvider);

    final remoteItems = portfolioAsync.value ?? const <Map<String, dynamic>>[];
    final allItems = <Map<String, dynamic>>[
      ...remoteItems,
      for (final v in localPortfolio.videos)
        if (!remoteItems.any((r) => r['id']?.toString() == v.id))
          {
            'id': v.id,
            'title': v.title,
            'media_url': v.mediaUrl,
            'media_type': 'video',
          },
      for (final p in localPortfolio.photos)
        if (!remoteItems.any((r) => r['id']?.toString() == p.id))
          {
            'id': p.id,
            'title': p.title,
            'media_url': p.mediaUrl,
            'media_type': 'photo',
          },
    ];

    // Deduplicate any repeated items by title and media type
    final seen = <String>{};
    final uniqueItems = <Map<String, dynamic>>[];
    for (final item in allItems) {
      final title = (item['title'] ?? '').toString();
      final titleKey = title.toLowerCase().trim();
      final typeKey = (item['media_type'] ?? '').toString().toLowerCase().trim();
      final key = '$typeKey:$titleKey';
      if (titleKey.isNotEmpty && !seen.add(key)) {
        continue;
      }
      uniqueItems.add(item);
    }

    final videos = uniqueItems.where((i) => i['media_type'] == 'video').toList();
    final photos = uniqueItems.where((i) => i['media_type'] == 'photo').toList();

    final auth = ref.watch(authProvider);
    final countriesAsync = ref.watch(countriesProvider);
    final citiesAsync = profile.country == null
        ? const AsyncValue.data(<Map<String, dynamic>>[])
        : ref.watch(citiesProvider(profile.country!));

    // Role label — formatted consistently as "Actor • Director"
    final roleLabel = RoleFormatter.format(auth.role ?? 'Actor');

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
                    const SizedBox(height: 16),

                    _RequiredField(
                      label: 'Experience',
                      controller: _experienceController,
                      hintText: 'e.g. 5+ Years in Narrative Film & Theatre',
                      isRequired: false,
                      onChanged: (v) => ref
                          .read(completeProfileProvider.notifier)
                          .setExperience(v),
                    ),
                    const SizedBox(height: 16),

                    _RequiredField(
                      label: 'Official Website',
                      controller: _websiteController,
                      hintText: 'e.g. www.artistportfolio.com',
                      isRequired: false,
                      onChanged: (v) => ref
                          .read(completeProfileProvider.notifier)
                          .setWebsite(v),
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
      final isVideo = type.toLowerCase() == 'video';
      final rawMediaUrl = result['url']!;
      final sanitized = resolvePortfolioMediaUrl(rawMediaUrl, isVideo: isVideo);
      final finalUrl = sanitized.isNotEmpty ? sanitized : rawMediaUrl;

      final inserted = await ref
          .read(portfolioRepositoryProvider)
          .addPortfolioItem(
            userId: uid,
            title: result['title']!,
            mediaUrl: finalUrl,
            mediaType: type,
          );
      ref.invalidate(userPortfolioProvider(uid));

      final insertedId = inserted['id']?.toString() ?? '';
      final newItem = WorkMediaItem(
        id: insertedId.isNotEmpty
            ? insertedId
            : 'port_${DateTime.now().millisecondsSinceEpoch}',
        title: result['title']!,
        url: finalUrl,
        mediaUrl: finalUrl,
        isVideo: isVideo,
        lastUpdated: 'Just Now',
      );


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
}

// ─── Reusable sub-widgets ────────────────────────────────

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F8F3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Color(0xFF00C48C), size: 20),
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
    final isVideo = item['media_type'] == 'video';
    final url = item['media_url'] as String? ?? '';
    final title = item['title'] as String? ?? '';
    final thumbUrl = isVideo
        ? (extractYouTubeThumbnail(url) ?? url)
        : resolvePortfolioMediaUrl(url);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Thumbnail ──────────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: buildPortfolioImage(
                  thumbUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              if (isVideo)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 30,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              if (isVideo && url.toLowerCase().contains('youtu'))
                Positioned(
                  bottom: 10,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_fill,
                            size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'YouTube',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // ── Title + URL + Delete ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3899F3),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: const Color(0xFFE53935),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
