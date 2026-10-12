import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:you_too_art/app/constants/app_colors.dart';
import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';

/// Modal bottom sheet for composing and publishing a post.
class CreatePostSheet extends ConsumerStatefulWidget {
  final bool startWithPhoto;

  const CreatePostSheet({
    super.key,
    this.startWithPhoto = false,
  });

  static Future<void> show(BuildContext context, {bool startWithPhoto = false}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreatePostSheet(startWithPhoto: startWithPhoto),
    );
  }

  @override
  ConsumerState<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<CreatePostSheet> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.startWithPhoto) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickImage();
      });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = file.name;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error picking image: $e');
    }
  }

  Future<void> _submitPost() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text or select an image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? mediaUrl;
      final currentUid = ref.read(currentUidProvider);

      if (_selectedImageBytes != null && currentUid != null) {
        final storage = ref.read(storageRepositoryProvider);
        mediaUrl = await storage.uploadImage(
          folder: 'posts',
          userId: currentUid,
          bytes: _selectedImageBytes!,
          fileName: _selectedImageName ?? 'post_image.jpg',
        );
      }

      final success = await ref.read(homeFeedProvider.notifier).addNewPost(
            caption: caption,
            mediaUrl: mediaUrl,
            mediaType: mediaUrl != null ? 'image' : null,
          );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post published successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to publish post')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final userAsync = ref.watch(currentUserProfileProvider);
    final user = userAsync.value;

    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 30,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create Post',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.link,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Post',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: colors.border),

          // Author info row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colors.link.withValues(alpha: 0.1),
                  backgroundImage: (user?.profileImagePath != null &&
                          user!.profileImagePath!.isNotEmpty)
                      ? NetworkImage(user.profileImagePath!)
                      : null,
                  child: (user?.profileImagePath == null ||
                          user!.profileImagePath!.isEmpty)
                      ? Text(
                          user?.name.isNotEmpty == true
                              ? user!.name[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: colors.link,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name.isNotEmpty == true ? user!.name : 'You',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Public',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Post input field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _captionController,
              maxLines: 4,
              minLines: 2,
              style: TextStyle(fontSize: 15, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: "What's on your mind? Add #hashtags to connect...",
                hintStyle: TextStyle(
                  color: colors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 15,
                ),
                border: InputBorder.none,
              ),
            ),
          ),

          // Image Preview (if picked)
          if (_selectedImageBytes != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _selectedImageBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImageBytes = null;
                          _selectedImageName = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Bottom Action Bar inside sheet (Pick image, add hashtag, etc.)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF3899F3),
                    size: 24,
                  ),
                  tooltip: 'Add Photo',
                ),
                IconButton(
                  onPressed: () {
                    final current = _captionController.text;
                    _captionController.text =
                        current.isEmpty ? '#' : '$current #';
                    _captionController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _captionController.text.length),
                    );
                  },
                  icon: const Icon(
                    Icons.tag_rounded,
                    color: Color(0xFFFF7A00),
                    size: 24,
                  ),
                  tooltip: 'Add Hashtag',
                ),
                const Spacer(),
                Text(
                  '${_captionController.text.length} chars',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
