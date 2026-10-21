import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:you_too_art/core/repositories/chat_repository.dart';
import 'package:you_too_art/core/repositories/connection_repository.dart';
import 'package:you_too_art/core/repositories/notification_repository.dart';
import 'package:you_too_art/core/repositories/portfolio_repository.dart';
import 'package:you_too_art/core/repositories/post_repository.dart';
import 'package:you_too_art/core/repositories/storage_repository.dart';

/// Provides the [SupabaseClient] singleton to the app via Riverpod.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return NotificationRepository(client);
});

final connectionRepositoryProvider = Provider<ConnectionRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ConnectionRepository(client);
});

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PortfolioRepository(client);
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ChatRepository(client);
});

/// Provides the [PostRepository] for social feed posts.
final postRepositoryProvider = Provider<PostRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PostRepository(client);
});

/// Provides the [StorageRepository] for Cloudinary uploads.
final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository();
});

/// Watches a user's portfolio items in real time.
final userPortfolioProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
      return ref.watch(portfolioRepositoryProvider).watchPortfolio(userId);
    });
