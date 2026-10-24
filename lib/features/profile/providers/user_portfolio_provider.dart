import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';

/// Extracts the 11-character YouTube video ID from various YouTube URL formats.
/// Supports standard watch, short-links, embeds, and YouTube Shorts.
String? extractYouTubeVideoId(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final regExp = RegExp(
    r'(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?|shorts)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );
  final match = regExp.firstMatch(trimmed);
  return match?.group(1);
}

/// Returns the YouTube thumbnail URL (hqdefault) for a given video URL or ID.
String? extractYouTubeThumbnail(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.contains('img.youtube.com') || trimmed.contains('i.ytimg.com')) {
    return trimmed;
  }
  final id = extractYouTubeVideoId(trimmed);
  if (id != null && id.isNotEmpty) {
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }
  return null;
}

/// Sanitizes media URLs for Flutter Web and cross-platform display.
/// - Transforms YouTube watch links into open-CORS video thumbnails.
/// - Proxies non-CORS external domains via images.weserv.nl on Flutter Web.
String resolvePortfolioMediaUrl(String rawUrl, {bool isVideo = false}) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('data:image')) return trimmed;

  // 1. If it's a YouTube URL, extract thumbnail
  if (!trimmed.contains('img.youtube.com') && !trimmed.contains('i.ytimg.com')) {
    final ytThumb = extractYouTubeThumbnail(trimmed);
    if (ytThumb != null) {
      return ytThumb;
    }
  }

  // 2. On Flutter Web, third-party image domains lacking CORS headers cause XMLHttpRequest errors.
  // Whitelist known CORS-friendly hosts, and proxy others safely.
  if (kIsWeb && (trimmed.startsWith('http://') || trimmed.startsWith('https://'))) {
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.host.isNotEmpty) {
      final host = uri.host.toLowerCase();
      const corsFriendlyHosts = [
        'images.unsplash.com',
        'img.youtube.com',
        'i.ytimg.com',
        'res.cloudinary.com',
        'picsum.photos',
        'fastly.picsum.photos',
        'images.weserv.nl',
        'via.placeholder.com',
        'lh3.googleusercontent.com',
        'avatars.githubusercontent.com',
      ];
      final isFriendly = host == 'localhost' ||
          corsFriendlyHosts.any((allowed) =>
              host == allowed ||
              host.endsWith('.$allowed') ||
              host.endsWith('.supabase.co'));
      if (!isFriendly) {
        return 'https://images.weserv.nl/?url=${Uri.encodeComponent(trimmed)}';
      }
    }
  }

  return trimmed;
}

class WorkMediaItem {
  final String id;
  final String title;
  final String url;
  final String mediaUrl;
  final bool isVideo;
  final String lastUpdated;

  const WorkMediaItem({
    required this.id,
    required this.title,
    required this.url,
    required this.mediaUrl,
    this.isVideo = false,
    this.lastUpdated = 'Just Now',
  });

  WorkMediaItem copyWith({
    String? id,
    String? title,
    String? url,
    String? mediaUrl,
    bool? isVideo,
    String? lastUpdated,
  }) {
    return WorkMediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      isVideo: isVideo ?? this.isVideo,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'mediaUrl': mediaUrl,
        'isVideo': isVideo,
        'lastUpdated': lastUpdated,
      };

  factory WorkMediaItem.fromJson(Map<String, dynamic> json) {
    final rawMediaUrl = json['mediaUrl'] as String? ?? '';
    final rawUrl = json['url'] as String? ?? '';
    final isVideo = json['isVideo'] as bool? ?? false;

    // Auto-fix any YouTube watch URLs or empty video thumbnails
    var effectiveMedia = rawMediaUrl;
    final ytThumbFromMedia = extractYouTubeThumbnail(effectiveMedia);
    if (ytThumbFromMedia != null) {
      effectiveMedia = ytThumbFromMedia;
    } else if (effectiveMedia.isEmpty && isVideo && rawUrl.isNotEmpty) {
      final ytThumbFromUrl = extractYouTubeThumbnail(rawUrl);
      if (ytThumbFromUrl != null) {
        effectiveMedia = ytThumbFromUrl;
      }
    }

    return WorkMediaItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: rawUrl,
      mediaUrl: effectiveMedia,
      isVideo: isVideo,
      lastUpdated: json['lastUpdated'] as String? ?? 'Just Now',
    );
  }
}

class UserPortfolioState {
  final List<WorkMediaItem> videos;
  final List<WorkMediaItem> photos;

  const UserPortfolioState({
    required this.videos,
    required this.photos,
  });

  UserPortfolioState copyWith({
    List<WorkMediaItem>? videos,
    List<WorkMediaItem>? photos,
  }) {
    return UserPortfolioState(
      videos: videos ?? this.videos,
      photos: photos ?? this.photos,
    );
  }

  Map<String, dynamic> toJson() => {
        'videos': videos.map((v) => v.toJson()).toList(),
        'photos': photos.map((p) => p.toJson()).toList(),
      };

  factory UserPortfolioState.fromJson(Map<String, dynamic> json) {
    final rawVideos = json['videos'] as List? ?? [];
    final rawPhotos = json['photos'] as List? ?? [];
    return UserPortfolioState(
      videos: rawVideos
          .map((item) => WorkMediaItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      photos: rawPhotos
          .map((item) => WorkMediaItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class UserPortfolioNotifier extends Notifier<UserPortfolioState> {
  static SharedPreferences? globalPrefs;

  static UserPortfolioState getPortfolioFor(
    String userId, [
    SharedPreferences? prefs,
  ]) {
    return AppPersistenceService.instance.getPortfolio(userId);
  }

  @override
  UserPortfolioState build() {
    final activePersona = ref.watch(userPersonaProvider);
    void listener() {
      final active = ref.read(userPersonaProvider);
      state = AppPersistenceService.instance.getPortfolio(active.id);
    }
    AppPersistenceService.instance.addListener(listener);
    ref.onDispose(() => AppPersistenceService.instance.removeListener(listener));
    return AppPersistenceService.instance.getPortfolio(activePersona.id);
  }

  String _resolveUid(String? targetUserId) {
    return targetUserId ?? ref.read(userPersonaProvider).id;
  }

  void addVideo(WorkMediaItem item, [String? targetUserId]) {
    final uid = _resolveUid(targetUserId);
    final current = AppPersistenceService.instance.getPortfolio(uid);
    final updated = current.copyWith(videos: [...current.videos, item]);
    AppPersistenceService.instance.savePortfolio(uid, updated);
    final activeId = ref.read(userPersonaProvider).id;
    if (UserPersonaNotifier.isSamePersona(uid, activeId)) {
      state = updated;
    }
  }

  void updateVideo(int index, WorkMediaItem item, [String? targetUserId]) {
    final uid = _resolveUid(targetUserId);
    final current = AppPersistenceService.instance.getPortfolio(uid);
    if (index >= 0 && index < current.videos.length) {
      final updatedList = List<WorkMediaItem>.from(current.videos);
      updatedList[index] = item;
      final updated = current.copyWith(videos: updatedList);
      AppPersistenceService.instance.savePortfolio(uid, updated);
      final activeId = ref.read(userPersonaProvider).id;
      if (UserPersonaNotifier.isSamePersona(uid, activeId)) {
        state = updated;
      }
    }
  }

  void deleteVideo(int index, [String? targetUserId]) {
    final uid = _resolveUid(targetUserId);
    final current = AppPersistenceService.instance.getPortfolio(uid);
    if (index >= 0 && index < current.videos.length) {
      final updatedList = List<WorkMediaItem>.from(current.videos);
      updatedList.removeAt(index);
      final updated = current.copyWith(videos: updatedList);
      AppPersistenceService.instance.savePortfolio(uid, updated);
      final activeId = ref.read(userPersonaProvider).id;
      if (UserPersonaNotifier.isSamePersona(uid, activeId)) {
        state = updated;
      }
    }
  }

  void addPhoto(WorkMediaItem item, [String? targetUserId]) {
    final uid = _resolveUid(targetUserId);
    final current = AppPersistenceService.instance.getPortfolio(uid);
    final updated = current.copyWith(photos: [...current.photos, item]);
    AppPersistenceService.instance.savePortfolio(uid, updated);
    final activeId = ref.read(userPersonaProvider).id;
    if (UserPersonaNotifier.isSamePersona(uid, activeId)) {
      state = updated;
    }
  }

  void updatePhoto(int index, WorkMediaItem item, [String? targetUserId]) {
    final uid = _resolveUid(targetUserId);
    final current = AppPersistenceService.instance.getPortfolio(uid);
    if (index >= 0 && index < current.photos.length) {
      final updatedList = List<WorkMediaItem>.from(current.photos);
      updatedList[index] = item;
      final updated = current.copyWith(photos: updatedList);
      AppPersistenceService.instance.savePortfolio(uid, updated);
      final activeId = ref.read(userPersonaProvider).id;
      if (UserPersonaNotifier.isSamePersona(uid, activeId)) {
        state = updated;
      }
    }
  }

  void deletePhoto(int index, [String? targetUserId]) {
    final uid = _resolveUid(targetUserId);
    final current = AppPersistenceService.instance.getPortfolio(uid);
    if (index >= 0 && index < current.photos.length) {
      final updatedList = List<WorkMediaItem>.from(current.photos);
      updatedList.removeAt(index);
      final updated = current.copyWith(photos: updatedList);
      AppPersistenceService.instance.savePortfolio(uid, updated);
      final activeId = ref.read(userPersonaProvider).id;
      if (UserPersonaNotifier.isSamePersona(uid, activeId)) {
        state = updated;
      }
    }
  }
}

final userWorkPortfolioProvider =
    NotifierProvider<UserPortfolioNotifier, UserPortfolioState>(() {
  return UserPortfolioNotifier();
});

/// Renders either a base64 data-URI, network URL, or graceful fallback icon.
Widget buildPortfolioImage(
  String mediaUrl, {
  double? height,
  double? width,
  BoxFit fit = BoxFit.cover,
}) {
  final resolved = resolvePortfolioMediaUrl(mediaUrl);
  if (resolved.isEmpty) {
    return _buildFallback(height, width);
  }

  if (resolved.startsWith('data:image')) {
    try {
      final commaIndex = resolved.indexOf(',');
      final base64Data =
          commaIndex != -1 ? resolved.substring(commaIndex + 1) : resolved;
      final bytes = base64Decode(base64Data);
      return Image.memory(
        bytes,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            _buildFallback(height, width),
      );
    } catch (_) {
      return _buildFallback(height, width);
    }
  }

  return Image.network(
    resolved,
    height: height,
    width: width,
    fit: fit,
    errorBuilder: (context, error, stackTrace) =>
        _buildFallback(height, width),
  );
}

Widget _buildFallback(double? height, double? width) {
  final isCompact = (height != null && height < 90);
  return Container(
    height: height,
    width: width,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF4F6F9), Color(0xFFE5E9F0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    alignment: Alignment.center,
    child: isCompact
        ? const Icon(Icons.image_outlined, size: 24, color: Color(0xFF9E9E9E))
        : const Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 32, color: Color(0xFF9E9E9E)),
              SizedBox(height: 6),
              Text(
                'Media Preview',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9E9E9E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
  );
}
