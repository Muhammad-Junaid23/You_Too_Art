import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:you_too_art/core/providers/supabase_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/widgets/app_avatar.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/home/models/post_item.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';
import 'package:you_too_art/features/home/widgets/tag_people_sheet.dart';

/// Full-screen Create / Edit Post page strictly matching Figma Images 2 & 3.
class CreatePostScreen extends ConsumerStatefulWidget {
  final bool initialWithPhoto;
  final PostItem? postToEdit;

  const CreatePostScreen({
    super.key,
    this.initialWithPhoto = false,
    this.postToEdit,
  });

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = HashtagTextEditingController();
  final _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _existingImageUrl;
  List<String> _taggedPeople = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.postToEdit != null) {
      _captionController.text = widget.postToEdit!.caption;
      _existingImageUrl = widget.postToEdit!.mediaUrl;
      _taggedPeople = List<String>.from(widget.postToEdit!.taggedUsers);
    } else if (widget.initialWithPhoto) {
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
    if (caption.isEmpty &&
        _selectedImageBytes == null &&
        _existingImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text or select a photo')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? mediaUrl = _existingImageUrl;
      final currentUid = ref.read(currentUidProvider) ??
          ref.read(supabaseClientProvider).auth.currentUser?.id;

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

      if (widget.postToEdit != null) {
        final clearImage = _selectedImageBytes == null &&
            (_existingImageUrl == null || _existingImageUrl!.isEmpty);
        await ref.read(homeFeedProvider.notifier).updatePost(
              postId: widget.postToEdit!.id,
              caption: caption,
              mediaUrl: mediaUrl,
              clearMediaUrl: clearImage,
              taggedUsers: _taggedPeople,
            );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post updated successfully!')),
          );
        }
      } else {
        await ref.read(homeFeedProvider.notifier).addNewPost(
              caption: caption,
              mediaUrl: mediaUrl,
              mediaType: mediaUrl != null ? 'image' : null,
              taggedUsers: _taggedPeople,
            );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post published successfully!')),
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
    final activePersona = ref.watch(userPersonaProvider);
    final userAsync = ref.watch(currentUserProfileProvider);
    final user = userAsync.value;

    final displayName = (user?.name.isNotEmpty == true)
        ? user!.name
        : (user?.firstName.isNotEmpty == true
            ? '${user!.firstName} ${user.lastName}'.trim()
            : (activePersona.name.isNotEmpty && !activePersona.name.toLowerCase().contains('wajahat')
                ? activePersona.name
                : (user?.email.split('@').first ?? 'User')));
    final userImg = user?.profileImagePath;
    final avatarUrl = (userImg != null && userImg.isNotEmpty)
        ? userImg
        : (!activePersona.name.toLowerCase().contains('wajahat')
            ? activePersona.avatarUrl
            : null);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.postToEdit != null ? 'Edit Post' : 'Create Post',
          style: const TextStyle(
            color: Color(0xFF000000),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                        AppAvatar(
                          imageUrl: avatarUrl,
                          name: displayName,
                          radius: 24,
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
                        hintText: 'What do you want to talk about?',
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
                      )
                    else if (_existingImageUrl != null &&
                        _existingImageUrl!.isNotEmpty)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _existingImageUrl!,
                              width: double.infinity,
                              height: 240,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 180,
                                  color: const Color(0xFFF2F4F7),
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Color(0xFF9B9B9B),
                                      size: 32,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _existingImageUrl = null;
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                                : Text(
                                    widget.postToEdit != null
                                        ? 'Update Post'
                                        : 'Post Now',
                                    style: const TextStyle(
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

/// Custom controller that renders hashtags in blue live as the user types,
/// preserving 100% of whitespaces and spaces without dropping or skipping.
class HashtagTextEditingController extends TextEditingController {
  HashtagTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    if (text.isEmpty) {
      return TextSpan(style: style, text: '');
    }

    final children = <TextSpan>[];
    final hashtagRegex = RegExp(r'#[a-zA-Z0-9_\u0600-\u06FF]+');

    text.splitMapJoin(
      hashtagRegex,
      onMatch: (Match match) {
        children.add(
          TextSpan(
            text: match[0],
            style: (style ?? const TextStyle()).copyWith(
              color: const Color(0xFF3899F3),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        return '';
      },
      onNonMatch: (String nonMatch) {
        if (nonMatch.isNotEmpty) {
          children.add(
            TextSpan(
              text: nonMatch,
              style: style,
            ),
          );
        }
        return '';
      },
    );

    return TextSpan(style: style, children: children);
  }
}
