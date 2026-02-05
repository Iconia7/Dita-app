// Storage key constants for Hive boxes and SharedPreferences
class StorageKeys {
  StorageKeys._(); // Private constructor to prevent instantiation

  // Hive Box Names
  static const String userBox = 'user_box';
  static const String eventsBox = 'events_box';
  static const String announcementsBox = 'announcements_box'; // NEW
  static const String postsBox = 'posts_box';
  static const String tasksBox = 'tasks_box';

  static const String timetableBox = 'timetable_box';
  static const String leaderboardBox = 'leaderboard_box';
  static const String settingsBox = 'settings_box';

  // User Data Keys
  static const String currentUser = 'current_user';
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';

  // Settings Keys
  static const String isDarkMode = 'is_dark_mode';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String hasSeenOnboarding = 'has_seen_onboarding';
  static const String hasDismissedMigrationAlert = 'has_dismissed_migration_alert';
  static const String lastSyncTimestamp = 'last_sync_timestamp';

  // Cache Keys
  static const String eventsCacheKey = 'cached_events';
  static const String postsCacheKey = 'cached_posts';
  static const String leaderboardCacheKey = 'cached_leaderboard';

  static const String resourcesCacheKey = 'cached_resources';
  static const String cachedEvents = 'cached_events';
  static const String cachedPosts = 'cached_posts';
  static const String cachedComments = 'cached_comments';
  
  static const String resourcesBox = 'resources_box';
  static const String cachedAnnouncements = 'cached_announcements'; // NEW

  // Timestamps
  static const String eventsTimestamp = 'events_timestamp';
  static const String announcementsTimestamp = 'announcements_timestamp'; // NEW
  static const String postsTimestamp = 'posts_timestamp';

  static const String resourcesTimestamp = 'resources_timestamp';
  static const String leaderboardTimestamp = 'leaderboard_timestamp';
  static const String commentsTimestamp = 'comments_timestamp'; 
  static const String eventsCacheTimestamp = 'events_cache_timestamp';
  static const String postsCacheTimestamp = 'posts_cache_timestamp';
  static const String profileCacheTimestamp = 'profile_cache_timestamp';

  // Cache Expiry (in hours)
  static const int cacheExpiryHours = 24;
}
