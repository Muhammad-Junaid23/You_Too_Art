import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/repositories/storage_repository.dart';
import 'package:you_too_art/features/profile/providers/user_portfolio_provider.dart';

class EditWorkMediaModal {
  static void showEditOrAddModal({
    required BuildContext context,
    required bool isVideo,
    required bool isEditing,
    WorkMediaItem? existingItem,
    required void Function(WorkMediaItem item) onSave,
    VoidCallback? onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditWorkMediaSheet(
        isVideo: isVideo,
        isEditing: isEditing,
        existingItem: existingItem,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }
}

class _EditWorkMediaSheet extends StatefulWidget {
  final bool isVideo;
  final bool isEditing;
  final WorkMediaItem? existingItem;
  final void Function(WorkMediaItem item) onSave;
  final VoidCallback? onDelete;

  const _EditWorkMediaSheet({
    required this.isVideo,
    required this.isEditing,
    this.existingItem,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_EditWorkMediaSheet> createState() => _EditWorkMediaSheetState();
}

class _EditWorkMediaSheetState extends State<_EditWorkMediaSheet> {
  late TextEditingController _titleController;
  late TextEditingController _urlController;
  late TextEditingController _mediaUrlController;
  String? _previewMediaUrl;

  @override
  void initState() {
    super.initState();
    final existingMedia = widget.existingItem?.mediaUrl ?? '';
    final existingUrl = widget.existingItem?.url ?? '';
    final isBase64 = existingMedia.startsWith('data:image');
    _titleController =
        TextEditingController(text: widget.existingItem?.title ?? '');
    _urlController = TextEditingController(text: existingUrl);

    // Auto-resolve YouTube thumbnails from mediaUrl or url
    var resolvedMedia = resolvePortfolioMediaUrl(existingMedia, isVideo: widget.isVideo);
    if ((resolvedMedia.isEmpty || !resolvedMedia.startsWith('http')) &&
        widget.isVideo &&
        existingUrl.isNotEmpty) {
      final ytThumb = extractYouTubeThumbnail(existingUrl);
      if (ytThumb != null) {
        resolvedMedia = ytThumb;
      }
    }

    _mediaUrlController = TextEditingController(
        text: isBase64 ? '' : (resolvedMedia.isNotEmpty ? resolvedMedia : existingMedia));
    _previewMediaUrl = resolvedMedia.isNotEmpty
        ? resolvedMedia
        : (existingMedia.isNotEmpty ? existingMedia : null);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _mediaUrlController.dispose();
    super.dispose();
  }

  bool _isUploading = false;

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (file != null) {
        setState(() => _isUploading = true);
        final bytes = await file.readAsBytes();
        try {
          final user = Supabase.instance.client.auth.currentUser;
          final uid = user?.id ?? UserPersonaNotifier.actorDefaultId;
          final storageRepo = StorageRepository();
          final secureUrl = await storageRepo.uploadImage(
            folder: 'portfolio',
            userId: uid,
            bytes: bytes,
            fileName: file.name,
          );
          if (mounted) {
            setState(() {
              _previewMediaUrl = secureUrl;
              _mediaUrlController.text = secureUrl;
              _isUploading = false;
            });
          }
        } catch (_) {
          if (mounted) {
            // High quality fallback sample so localstorage is not bloated with multi-MB base64
            setState(() {
              _previewMediaUrl = widget.isVideo
                  ? 'https://images.unsplash.com/photo-1556761175-5973dc0f32e7?auto=format&fit=crop&w=800&q=80'
                  : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80';
              _mediaUrlController.text = _previewMediaUrl!;
              _isUploading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Offline/network error: fallback image applied.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    final url = _urlController.text.trim();
    var mediaUrl = _previewMediaUrl ?? _mediaUrlController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    if (widget.isVideo) {
      // If mediaUrl is empty or a YouTube video link, resolve thumbnail from mediaUrl or url
      final ytThumb =
          extractYouTubeThumbnail(mediaUrl) ?? extractYouTubeThumbnail(url);
      if (ytThumb != null) {
        mediaUrl = ytThumb;
      }
    }

    final newItem = WorkMediaItem(
      id: widget.existingItem?.id ??
          '${widget.isVideo ? 'vid' : 'photo'}_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      url: url.isNotEmpty
          ? url
          : (widget.isVideo
              ? 'https://youtu.be/JXCRWxBA0fE'
              : 'https://drive.google.com/u/1/a3tc'),
      mediaUrl: mediaUrl.isNotEmpty
          ? mediaUrl
          : (widget.isVideo
              ? 'https://images.unsplash.com/photo-1556761175-5973dc0f32e7?auto=format&fit=crop&w=800&q=80'
              : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80'),
      isVideo: widget.isVideo,
      lastUpdated: 'Just Now',
    );

    widget.onSave(newItem);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(widget.isEditing
                ? '${widget.isVideo ? 'Video' : 'Photo'} updated successfully!'
                : '${widget.isVideo ? 'Video' : 'Photo'} added to portfolio!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF00C48C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaLabel = widget.isVideo ? 'Video' : 'Photo';
    final actionLabel = widget.isEditing ? 'Edit $mediaLabel' : 'Add $mediaLabel';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title row & close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFE0E0E0), width: 0.8),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close,
                          size: 16, color: Color(0xFF616161)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Preview image
              if (_previewMediaUrl != null && _previewMediaUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      buildPortfolioImage(
                        _previewMediaUrl!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      if (widget.isVideo)
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              size: 26, color: Colors.black87),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Media Picker Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickImage,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF3899F3),
                          ),
                        )
                      : const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(_isUploading
                      ? 'Uploading to Cloudinary...'
                      : (widget.isVideo
                          ? 'Pick Video Thumbnail'
                          : 'Pick Photo Image')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3899F3),
                    side: const BorderSide(color: Color(0xFF3899F3), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title input
              const Text(
                'Title',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF616161),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. ${widget.isVideo ? 'SPECIAL REPORT: Film Teaser' : 'Short Film on Teen Age Side Hustles'}',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // URL input
              Text(
                widget.isVideo ? 'Video Link (YouTube / Vimeo / Drive)' : 'Project / Drive Link',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF616161),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _urlController,
                onChanged: (val) {
                  if (widget.isVideo) {
                    final ytThumb = extractYouTubeThumbnail(val);
                    if (ytThumb != null &&
                        (_previewMediaUrl == null ||
                            _previewMediaUrl!.isEmpty ||
                            _previewMediaUrl!.contains('img.youtube.com') ||
                            _previewMediaUrl!.contains('i.ytimg.com') ||
                            _mediaUrlController.text.isEmpty ||
                            _mediaUrlController.text.contains('youtube.com') ||
                            _mediaUrlController.text.contains('youtu.be'))) {
                      setState(() {
                        _previewMediaUrl = ytThumb;
                        _mediaUrlController.text = ytThumb;
                      });
                    }
                  }
                },
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: widget.isVideo
                      ? 'https://youtu.be/...'
                      : 'https://drive.google.com/...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Image URL input (optional override)
              const Text(
                'Image / Thumbnail URL (Optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF616161),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _mediaUrlController,
                onChanged: (val) {
                  final trimmed = val.trim();
                  final ytThumb = extractYouTubeThumbnail(trimmed);
                  setState(() => _previewMediaUrl = ytThumb ?? trimmed);
                },
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'https://images.unsplash.com/...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tip: Use direct image links (e.g. Unsplash, Supabase, Cloudinary) or tap Pick above. Protected wallpaper sites block external embedding.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9E9E9E),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  if (widget.isEditing && widget.onDelete != null) ...[
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFE53935)),
                      onPressed: () {
                        widget.onDelete!();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${widget.isVideo ? 'Video' : 'Photo'} deleted'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3899F3),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.isEditing ? 'Save Changes' : 'Add $mediaLabel',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
