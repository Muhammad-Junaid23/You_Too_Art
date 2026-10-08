import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:you_too_art/app/constants/app_colors.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';

/// Bottom sheet for adding a video or photo to the portfolio.
/// Supports both file upload (via Cloudinary) and pasting a link.
class AddMediaSheet extends ConsumerStatefulWidget {
  final String mediaType; // 'video' | 'photo'

  const AddMediaSheet({super.key, required this.mediaType});

  @override
  ConsumerState<AddMediaSheet> createState() => _AddMediaSheetState();
}

class _AddMediaSheetState extends ConsumerState<AddMediaSheet> {
  final _linkController = TextEditingController();
  final _titleController = TextEditingController();
  String? _uploadedUrl;
  bool _uploading = false;

  @override
  void dispose() {
    _linkController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  bool get _isVideo => widget.mediaType == 'video';

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    final file = await picker.pickMedia();
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final repo = ref.read(storageRepositoryProvider);
      final userId = ref.read(authProvider.notifier).currentUid ?? 'anonymous';
      final url = await repo.uploadPortfolioMedia(
        userId: userId,
        bytes: await file.readAsBytes(),
        fileName: file.name,
        mediaType: widget.mediaType,
      );
      if (!mounted) return;
      setState(() => _uploadedUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _submit() {
    final url = _uploadedUrl ?? _linkController.text.trim();
    final title = _titleController.text.trim();
    if (url.isEmpty || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a link or upload and a title'),
        ),
      );
      return;
    }
    Navigator.of(context).pop({'url': url, 'title': title});
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final label = _isVideo ? 'Add Video' : 'Add Photo';
    final uploadLabel = _isVideo ? 'Paste Video Link' : 'Paste Photo Link';
    final titleHint = _isVideo ? 'Enter video title' : 'Enter photo title';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // File picker
          GestureDetector(
            onTap: _uploading ? null : _pickFile,
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
                  : Icon(Icons.upload, color: colors.link, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _uploadedUrl != null
                ? 'Uploaded ✓'
                : 'Upload ${_isVideo ? "Video" : "Photo"}',
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),

          Text(
            'OR $uploadLabel',
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _linkController,
            enabled: _uploadedUrl == null,
            decoration: InputDecoration(hintText: uploadLabel),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _titleController,
            decoration: InputDecoration(hintText: titleHint),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.border,
                      foregroundColor: colors.textSecondary,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(55),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(55),
                      ),
                    ),
                    child: Text(_isVideo ? 'Add' : 'Upload'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
