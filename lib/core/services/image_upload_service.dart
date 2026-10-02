import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:you_too_art/core/repositories/storage_repository.dart';

/// Bucket categories for image uploads.
enum ImageBucket {
  avatar('avatars'),
  post('posts'),
  portfolio('portfolio'),
  casting('casting');

  final String folder;
  const ImageBucket(this.folder);
}

/// Service that adapts [XFile] (from image_picker) to [StorageRepository] uploads.
class ImageUploadService {
  final StorageRepository _storageRepo;

  ImageUploadService(this._storageRepo);

  /// Upload an [XFile] to Cloudinary under the specified [bucket].
  ///
  /// Returns the secure URL of the uploaded file.
  Future<String> upload({
    required XFile file,
    required ImageBucket bucket,
    required String userId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final fileName = file.name;

      return await _storageRepo.uploadImage(
        folder: bucket.folder,
        userId: userId,
        bytes: bytes,
        fileName: fileName,
        onProgress: onProgress,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ImageUploadService.upload: $e');
      rethrow;
    }
  }

  /// Upload a file if provided, otherwise return the [existingUrl].
  ///
  /// Useful for edit forms where the user may or may not change the image.
  Future<String?> uploadOrKeep({
    XFile? file,
    required ImageBucket bucket,
    required String userId,
    String? existingUrl,
    void Function(double progress)? onProgress,
  }) async {
    if (file == null) return existingUrl;

    return upload(
      file: file,
      bucket: bucket,
      userId: userId,
      onProgress: onProgress,
    );
  }
}
