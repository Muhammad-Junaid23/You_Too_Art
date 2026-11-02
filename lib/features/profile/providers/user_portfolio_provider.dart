import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';

/// Extracts the 11-character YouTube video ID from various YouTube URL formats.
/// Supports standard watch, short-links, embeds, YouTube Shorts, and thumbnail URLs.
String? extractYouTubeVideoId(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final regExp = RegExp(
    r'(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:vi?|e(?:mbed)?|shorts)\/|\S*?[?&]v=)|youtu\.be\/|ytimg\.com\/vi\/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );
  final match = regExp.firstMatch(trimmed);
  return match?.group(1);
}

/// Resolves a video link to a playable destination (e.g. YouTube watch URL if thumbnail or video ID).
String resolvePlayableVideoUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return '';
  final ytId = extractYouTubeVideoId(trimmed);
  if (ytId != null && ytId.isNotEmpty) {
    return 'https://www.youtube.com/watch?v=$ytId';
  }
  return trimmed;
}

/// Unpacks any proxy wrapper (such as images.weserv.nl) to return the original media URL.
String unpackOriginalMediaUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.startsWith('https://images.weserv.nl/?url=') ||
      trimmed.startsWith('http://images.weserv.nl/?url=')) {
    final uri = Uri.tryParse(trimmed);
    final inner = uri?.queryParameters['url'];
    if (inner != null && inner.isNotEmpty) {
      return inner;
    }
  }
  return trimmed;
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
    final rawMediaUrl =
        (json['media_url'] ?? json['mediaUrl']) as String? ?? '';
    final rawUrl = (json['url'] ?? rawMediaUrl) as String? ?? '';
    final isVideo = json['isVideo'] as bool? ??
        (json['media_type']?.toString().toLowerCase() == 'video');

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
      url: isVideo
          ? resolvePlayableVideoUrl(rawUrl.isNotEmpty ? rawUrl : rawMediaUrl)
          : unpackOriginalMediaUrl(rawUrl.isNotEmpty ? rawUrl : rawMediaUrl),
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
    final currentUid = ref.watch(currentUidProvider);
    final effectiveUid = (currentUid != null && currentUid.isNotEmpty)
        ? currentUid
        : activePersona.id;
    void listener() {
      final active = ref.read(userPersonaProvider);
      final uid = ref.read(currentUidProvider) ?? active.id;
      state = AppPersistenceService.instance.getPortfolio(uid);
    }
    AppPersistenceService.instance.addListener(listener);
    ref.onDispose(() => AppPersistenceService.instance.removeListener(listener));
    return AppPersistenceService.instance.getPortfolio(effectiveUid);
  }

  String _resolveUid(String? targetUserId) {
    if (targetUserId != null && targetUserId.isNotEmpty) return targetUserId;
    final currentUid = ref.read(currentUidProvider);
    if (currentUid != null && currentUid.isNotEmpty) return currentUid;
    return ref.read(userPersonaProvider).id;
  }

  void addVideo(WorkMediaItem item, [String? targetUserId]) {
    final uid = _resolveUid(targetUserId);
    final current = AppPersistenceService.instance.getPortfolio(uid);
    final updated = current.copyWith(videos: [...current.videos, item]);
    AppPersistenceService.instance.savePortfolio(uid, updated);
    state = updated;
  }

  void updateVideo(int index, WorkMediaItem item, [String? targetUserId]) {
    final uid = _resolveUid(targetUserId);
    final current = AppPersistenceService.instance.getPortfolio(uid);
    if (index >= 0 && index < current.videos.length) {
      final updatedList = List<WorkMediaItem>.from(current.videos);
      updatedList[index] = item;
      final updated = current.copyWith(videos: updatedList);
      AppPersistenceService.instance.savePortfolio(uid, updated);
      state = updated;
    }
  }

  void deleteVideo(int index, [String? targetUserId, WorkMediaItem? itemToDelete]) {
    final uid = _resolveUid(targetUserId);
    final current = AppPersistenceService.instance.getPortfolio(uid);
    final updatedList = List<WorkMediaItem>.from(current.videos);
    if (index >= 0 && index < updatedList.length) {
      updatedList.removeAt(index);
    }
    if (itemToDelete != null) {
      updatedList.removeWhere((v) =>
          v.id == itemToDelete.id ||
          (v.title.trim() == itemToDelete.title.trim() &&
              (v.url == itemToDelete.url || v.mediaUrl == itemToDelete.mediaUrl)));
    }
    final updated = current.copyWith(videos: updatedList);
    AppPersistenceService.instance.savePortfolio(uid, updated);
    state = updated;
  }

  void addPhoto(WorkMediaItem item, [String? targetUserId]) {
    final uid = _resolveUid(targetUserId);
    final current = AppPersistenceService.instance.getPortfolio(uid);
    final updated = current.copyWith(photos: [...current.photos, item]);
    AppPersistenceService.instance.savePortfolio(uid, updated);
    state = updated;
  }

  void updatePhoto(int index, WorkMediaItem item, [String? targetUserId]) {
    final uid = _resolveUid(targetUserId);
    final current = AppPersistenceService.instance.getPortfolio(uid);
    if (index >= 0 && index < current.photos.length) {
      final updatedList = List<WorkMediaItem>.from(current.photos);
      updatedList[index] = item;
      final updated = current.copyWith(photos: updatedList);
      AppPersistenceService.instance.savePortfolio(uid, updated);
      state = updated;
    }
  }

  void deletePhoto(int index, [String? targetUserId, WorkMediaItem? itemToDelete]) {
    final uid = _resolveUid(targetUserId);
    final current = AppPersistenceService.instance.getPortfolio(uid);
    final updatedList = List<WorkMediaItem>.from(current.photos);
    if (index >= 0 && index < updatedList.length) {
      updatedList.removeAt(index);
    }
    if (itemToDelete != null) {
      updatedList.removeWhere((p) =>
          p.id == itemToDelete.id ||
          (p.title.trim() == itemToDelete.title.trim() &&
              (p.url == itemToDelete.url || p.mediaUrl == itemToDelete.mediaUrl)));
    }
    final updated = current.copyWith(photos: updatedList);
    AppPersistenceService.instance.savePortfolio(uid, updated);
    state = updated;
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
