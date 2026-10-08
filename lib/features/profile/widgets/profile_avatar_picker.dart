import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:you_too_art/app/constants/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';

/// Circular avatar uploader. Uses Cloudinary via StorageRepository.
class ProfileAvatarPicker extends ConsumerStatefulWidget {
  final String? currentUrl;
  final void Function(String url) onUploaded;

  const ProfileAvatarPicker({
    super.key,
    required this.currentUrl,
    required this.onUploaded,
  });

  @override
  ConsumerState<ProfileAvatarPicker> createState() =>
      _ProfileAvatarPickerState();
}

class _ProfileAvatarPickerState extends ConsumerState<ProfileAvatarPicker> {
  bool _uploading = false;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final repo = ref.read(storageRepositoryProvider);
      final userId = ref.read(authProvider.notifier).currentUid ?? 'anonymous';
      final url = await repo.uploadProfileImage(
        userId: userId,
        bytes: await file.readAsBytes(), // works on web + mobile
        fileName: file.name,
      );
      if (!mounted) return;
      widget.onUploaded(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Profile',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _uploading ? null : _pick,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.avatarBg,
              shape: BoxShape.circle,
            ),
            child: _uploading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : widget.currentUrl != null
                ? ClipOval(
                    child: Image.network(
                      widget.currentUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(Icons.upload, color: colors.link, size: 28),
          ),
        ),
      ],
    );
  }
}
