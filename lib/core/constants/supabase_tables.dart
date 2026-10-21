/// Constants for Supabase table names.
/// Keeps table references centralized to avoid typos and ease migration.
class SupabaseTables {
  SupabaseTables._();

  static const String users = 'users';
  static const String posts = 'posts';
  static const String postLikes = 'post_likes';
  static const String postComments = 'post_comments';
  static const String connections = 'connections';
  static const String conversations = 'conversations';
  static const String messages = 'messages';
  static const String castingCalls = 'casting_calls';
  static const String castingApplications = 'casting_applications';
  static const String portfolioItems = 'portfolio_items';
  static const String notifications = 'notifications';
}
