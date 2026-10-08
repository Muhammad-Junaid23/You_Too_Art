import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Configuration for Cloudinary uploads.
class CloudinaryConfig {
  /// Your Cloudinary cloud name. Replace with actual value.
  static const String cloudName = 'dsxhrelpu';

  /// Unsigned upload preset configured in Cloudinary dashboard.
  static const String unsignedPreset = 'you_too_art_unsigned';

  /// Base upload URL.
  static String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/auto/upload';
}

/// Repository for uploading files to Cloudinary via unsigned upload.
///
/// Uses `http.MultipartRequest` for uploads. No Supabase Storage is used.
class StorageRepository {
  /// Uploads an image to Cloudinary.
  ///
  /// [folder] — Cloudinary folder path (e.g., `avatars`, `posts`).
  /// [userId] — Used to namespace uploads.
  /// [bytes] — The raw file bytes.
  /// [fileName] — Original file name for MIME detection.
  /// [onProgress] — Optional callback for upload progress (0.0 to 1.0).
  ///
  /// Returns the secure URL of the uploaded image.
  Future<String> uploadImage({
    required String folder,
    required String userId,
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final uri = Uri.parse(CloudinaryConfig.uploadUrl);
      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = CloudinaryConfig.unsignedPreset;
      request.fields['folder'] = '$folder/$userId';

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception(
          'Cloudinary upload failed with status ${response.statusCode}: ${response.body}',
        );
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = data['secure_url'] as String?;
      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception(
          'Could not find secure_url in Cloudinary response: ${response.body}',
        );
      }

      return secureUrl;
    } catch (e) {
      if (kDebugMode) debugPrint('StorageRepository.uploadImage: $e');
      rethrow;
    }
  }

  /// Uploads an avatar image with a standardized folder path.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    return uploadImage(
      folder: 'avatars',
      userId: userId,
      bytes: bytes,
      fileName: fileName,
      onProgress: onProgress,
    );
  }

  /// Uploads a profile image. Requires [userId] to namespace.
  Future<String> uploadProfileImage({
    required String userId,
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) {
    return uploadAvatar(
      userId: userId,
      bytes: bytes,
      fileName: fileName,
      onProgress: onProgress,
    );
  }

  /// Uploads a portfolio video or photo. [mediaType] should be 'video' or 'photo'.
  Future<String> uploadPortfolioMedia({
    required String userId,
    required Uint8List bytes,
    required String fileName,
    required String mediaType,
    void Function(double progress)? onProgress,
  }) {
    return uploadImage(
      folder: mediaType == 'video' ? 'portfolio/videos' : 'portfolio/photos',
      userId: userId,
      bytes: bytes,
      fileName: fileName,
      onProgress: onProgress,
    );
  }
}
