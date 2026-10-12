import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';
import 'package:you_too_art/features/home/widgets/tag_people_sheet.dart';

/// Full-screen Create Post page strictly matching Figma Images 2 & 3.
class CreatePostScreen extends ConsumerStatefulWidget {
  final bool initialWithPhoto;

  const CreatePostScreen({
    super.key,
    this.initialWithPhoto = false,
  });

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  List<String> _taggedPeople = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialWithPhoto) {
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

  Future<void> _openTagPeople() async {
    final result = await TagPeopleSheet.show(
      context,
      initialSelected: _taggedPeople,
    );
    if (result != null) {
      setState(() {
        _taggedPeople = result;
      });
    }
  }

  Future<void> _submitPost() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text or select a photo')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? mediaUrl;
      final currentUid = ref.read(currentUidProvider);

      if (_selectedImageBytes != null && currentUid != null) {
        final storage = ref.read(storageRepositoryProvider);
        try {
          mediaUrl = await storage.uploadImage(
            folder: 'posts',
            userId: currentUid,
            bytes: _selectedImageBytes!,
            fileName: _selectedImageName ?? 'post_image.jpg',
          );
        } catch (e) {
          if (kDebugMode) debugPrint('Upload error: $e');
        }
      }

      await ref.read(homeFeedProvider.notifier).addNewPost(
            caption: caption,
            mediaUrl: mediaUrl,
            mediaType: mediaUrl != null ? 'image' : null,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post published successfully!')),
        );
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
    final userAsync = ref.watch(currentUserProfileProvider);
    final user = userAsync.value;

    final displayName = user?.name.isNotEmpty == true
        ? user!.name
        : 'Muhammad Wajahat';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF000000)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author Info Row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFE7F3FE),
                          backgroundImage: (user?.profileImagePath != null &&
                                  user!.profileImagePath!.isNotEmpty)
                              ? NetworkImage(user.profileImagePath!)
                              : const NetworkImage(
                                  'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
                                ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF000000),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'New Post',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9B9B9B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Post Text Input Field
                    TextField(
                      controller: _captionController,
                      maxLines: null,
                      minLines: 4,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF000000),
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        hintText:
                            'One Day To Go! Get Ready for a Huge Surprise.\n\n#Reveal\n#Audition\n#FawadKhan',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF9B9B9B),
                          height: 1.4,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),

                    // Tagged People Indicator
                    if (_taggedPeople.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: _taggedPeople.map((name) {
                          return Chip(
                            backgroundColor: const Color(0xFFE7F3FE),
                            label: Text(
                              '@$name',
                              style: const TextStyle(
                                color: Color(0xFF3899F3),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onDeleted: () {
                              setState(() {
                                _taggedPeople.remove(name);
                              });
                            },
                            deleteIconColor: const Color(0xFF3899F3),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Selected Image Preview (Figma Image 3)
                    if (_selectedImageBytes != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _selectedImageBytes!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImageBytes = null;
                                  _selectedImageName = null;
                                });
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.45),
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

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Actions (Photo & Tag People pills + Discard & Post Now buttons)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE6E7E8))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Photo & Tag People Pills
                  Row(
                    children: [
                      // Photo Pill
                      InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F3FE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_outlined,
                                size: 18,
                                color: Color(0xFF3899F3),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Photo',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3899F3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Tag People Pill
                      InkWell(
                        onTap: _openTagPeople,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x19FF5F2D),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_offer_outlined,
                                size: 18,
                                color: Color(0xFFFF5F2D),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _taggedPeople.isNotEmpty
                                    ? 'Tag People (${_taggedPeople.length})'
                                    : 'Tag People',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF000000),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Discard and Post Now Buttons
                  Row(
                    children: [
                      // Discard Button
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFE5E5),
                              foregroundColor: const Color(0xFFFF0000),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text(
                              'Discard',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF0000),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Post Now Button
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitPost,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF000000),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Post Now',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
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
          ],
        ),
      ),
    );
  }
}
