import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

class UserPortfolioNotifier extends Notifier<UserPortfolioState> {
  static const List<WorkMediaItem> _defaultVideos = [
    WorkMediaItem(
      id: 'vid_1',
      title: 'SPECIAL REPORT: What\'s the Trouble in Gilgit-Baltistan?',
      url: 'https://youtu.be/JXCRWxBA0fE',
      mediaUrl:
          'https://images.unsplash.com/photo-1556761175-5973dc0f32e7?auto=format&fit=crop&w=800&q=80',
      isVideo: true,
      lastUpdated: 'Just Now',
    ),
  ];

  static const List<WorkMediaItem> _defaultPhotos = [
    WorkMediaItem(
      id: 'photo_1',
      title: 'Short Film on Teen Age Side Hustles',
      url: 'https://drive.google.com/u/1/a3tc',
      mediaUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80',
      isVideo: false,
      lastUpdated: '2 days ago',
    ),
    WorkMediaItem(
      id: 'photo_2',
      title: 'Cinematic Moodboard - Red Studio',
      url: 'https://drive.google.com/u/1/photo2',
      mediaUrl:
          'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=800&q=80',
      isVideo: false,
      lastUpdated: '3 days ago',
    ),
    WorkMediaItem(
      id: 'photo_3',
      title: 'Behind the Scenes - Indie Production',
      url: 'https://drive.google.com/u/1/photo3',
      mediaUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=800&q=80',
      isVideo: false,
      lastUpdated: '5 days ago',
    ),
    WorkMediaItem(
      id: 'photo_4',
      title: 'Golden Hour Character Study',
      url: 'https://drive.google.com/u/1/photo4',
      mediaUrl:
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=800&q=80',
      isVideo: false,
      lastUpdated: '1 week ago',
    ),
    WorkMediaItem(
      id: 'photo_5',
      title: 'Monochrome Dramatic Monologue',
      url: 'https://drive.google.com/u/1/photo5',
      mediaUrl:
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=800&q=80',
      isVideo: false,
      lastUpdated: '1 week ago',
    ),
    WorkMediaItem(
      id: 'photo_6',
      title: 'Theatre Rehearsal Stills',
      url: 'https://drive.google.com/u/1/photo6',
      mediaUrl:
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=800&q=80',
      isVideo: false,
      lastUpdated: '2 weeks ago',
    ),
    WorkMediaItem(
      id: 'photo_7',
      title: 'Stage Presence & Silhouette',
      url: 'https://drive.google.com/u/1/photo7',
      mediaUrl:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=800&q=80',
      isVideo: false,
      lastUpdated: '2 weeks ago',
    ),
    WorkMediaItem(
      id: 'photo_8',
      title: 'Editorial Headshots Session',
      url: 'https://drive.google.com/u/1/photo8',
      mediaUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=800&q=80',
      isVideo: false,
      lastUpdated: '3 weeks ago',
    ),
    WorkMediaItem(
      id: 'photo_9',
      title: 'Casting Reel Stills - Period Drama',
      url: 'https://drive.google.com/u/1/photo9',
      mediaUrl:
          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=800&q=80',
      isVideo: false,
      lastUpdated: '1 month ago',
    ),
    WorkMediaItem(
      id: 'photo_10',
      title: 'Urban Action Sequence Frames',
      url: 'https://drive.google.com/u/1/photo10',
      mediaUrl:
          'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=800&q=80',
      isVideo: false,
      lastUpdated: '1 month ago',
    ),
    WorkMediaItem(
      id: 'photo_11',
      title: 'Expressive Close-ups - Emotional Arc',
      url: 'https://drive.google.com/u/1/photo11',
      mediaUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80',
      isVideo: false,
      lastUpdated: '1 month ago',
    ),
    WorkMediaItem(
      id: 'photo_12',
      title: 'Director Showcase Wrap Stills',
      url: 'https://drive.google.com/u/1/photo12',
      mediaUrl:
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=800&q=80',
      isVideo: false,
      lastUpdated: '2 months ago',
    ),
  ];

  @override
  UserPortfolioState build() {
    return const UserPortfolioState(
      videos: _defaultVideos,
      photos: _defaultPhotos,
    );
  }

  void addVideo(WorkMediaItem item) {
    state = state.copyWith(videos: [...state.videos, item]);
  }

  void updateVideo(int index, WorkMediaItem item) {
    if (index >= 0 && index < state.videos.length) {
      final updated = List<WorkMediaItem>.from(state.videos);
      updated[index] = item;
      state = state.copyWith(videos: updated);
    }
  }

  void deleteVideo(int index) {
    if (index >= 0 && index < state.videos.length) {
      final updated = List<WorkMediaItem>.from(state.videos);
      updated.removeAt(index);
      state = state.copyWith(videos: updated);
    }
  }

  void addPhoto(WorkMediaItem item) {
    state = state.copyWith(photos: [...state.photos, item]);
  }

  void updatePhoto(int index, WorkMediaItem item) {
    if (index >= 0 && index < state.photos.length) {
      final updated = List<WorkMediaItem>.from(state.photos);
      updated[index] = item;
      state = state.copyWith(photos: updated);
    }
  }

  void deletePhoto(int index) {
    if (index >= 0 && index < state.photos.length) {
      final updated = List<WorkMediaItem>.from(state.photos);
      updated.removeAt(index);
      state = state.copyWith(photos: updated);
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
  if (mediaUrl.startsWith('data:image')) {
    try {
      final commaIndex = mediaUrl.indexOf(',');
      final base64Data =
          commaIndex != -1 ? mediaUrl.substring(commaIndex + 1) : mediaUrl;
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
    mediaUrl,
    height: height,
    width: width,
    fit: fit,
    errorBuilder: (context, error, stackTrace) =>
        _buildFallback(height, width),
  );
}

Widget _buildFallback(double? height, double? width) {
  return Container(
    height: height,
    width: width,
    color: const Color(0xFFF0F1F3),
    alignment: Alignment.center,
    child: const Icon(Icons.image_outlined, size: 36, color: Color(0xFFBDBDBD)),
  );
}
