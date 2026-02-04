import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../utils/app_logger.dart';

/// Local data source for community posts and comments using Hive
class CommunityLocalDataSource {
  final LocalStorage _storage;

  CommunityLocalDataSource(this._storage);

  /// Cache list of posts
  Future<void> cachePosts(List<PostModel> posts) async {
    try {
      final jsonList = posts.map((post) => post.toJson()).toList();
      await _storage.put(StorageKeys.postsBox, StorageKeys.cachedPosts, jsonList);
      await _storage.put(
        StorageKeys.postsBox,
        StorageKeys.postsTimestamp,
        DateTime.now().toIso8601String(),
      );
      AppLogger.success('Cached ${posts.length} posts locally');
    } catch (e, stackTrace) {
      AppLogger.error('Error caching posts', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get cached posts
  Future<List<PostModel>?> getCachedPosts() async {
    try {
      final jsonList = await _storage.get<List>(
        StorageKeys.postsBox,
        StorageKeys.cachedPosts,
      );

      if (jsonList == null) {
        AppLogger.info('No cached posts found');
        return null;
      }

      // Check if cache is expired
      if (await _isCacheExpired(StorageKeys.postsTimestamp)) {
        AppLogger.info('Posts cache expired');
        await clearPostsCache();
        return null;
      }

      final posts = jsonList
          .map((json) => PostModel.fromJson(json as Map<String, dynamic>))
          .toList();
      AppLogger.success('Retrieved ${posts.length} cached posts');
      return posts;
    } catch (e, stackTrace) {
      AppLogger.error('Error retrieving cached posts', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Cache comments for a specific post
  Future<void> cacheComments(int postId, List<CommentModel> comments) async {
    try {
      final jsonList = comments.map((comment) => comment.toJson()).toList();
      final key = '${StorageKeys.cachedComments}_$postId';
      await _storage.put(StorageKeys.postsBox, key, jsonList);
      await _storage.put(
        StorageKeys.postsBox,
        '${StorageKeys.commentsTimestamp}_$postId',
        DateTime.now().toIso8601String(),
      );
      AppLogger.success('Cached ${comments.length} comments for post $postId');
    } catch (e, stackTrace) {
      AppLogger.error('Error caching comments', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get cached comments for a post
  Future<List<CommentModel>?> getCachedComments(int postId) async {
    try {
      final key = '${StorageKeys.cachedComments}_$postId';
      final jsonList = await _storage.get<List>(StorageKeys.postsBox, key);

      if (jsonList == null) {
        AppLogger.info('No cached comments found for post $postId');
        return null;
      }

      // Check if cache is expired
      final timestampKey = '${StorageKeys.commentsTimestamp}_$postId';
      if (await _isCacheExpired(timestampKey)) {
        AppLogger.info('Comments cache expired for post $postId');
        await clearCommentsCache(postId);
        return null;
      }

      final comments = jsonList
          .map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
          .toList();
      AppLogger.success('Retrieved ${comments.length} cached comments');
      return comments;
    } catch (e, stackTrace) {
      AppLogger.error('Error retrieving cached comments', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Clear posts cache
  Future<void> clearPostsCache() async {
    try {
      await _storage.delete(StorageKeys.postsBox, StorageKeys.cachedPosts);
      await _storage.delete(StorageKeys.postsBox, StorageKeys.postsTimestamp);
      AppLogger.info('Posts cache cleared');
    } catch (e, stackTrace) {
      AppLogger.error('Error clearing posts cache', error: e, stackTrace: stackTrace);
    }
  }

  /// Clear comments cache for a specific post
  Future<void> clearCommentsCache(int postId) async {
    try {
      final key = '${StorageKeys.cachedComments}_$postId';
      final timestampKey = '${StorageKeys.commentsTimestamp}_$postId';
      await _storage.delete(StorageKeys.postsBox, key);
      await _storage.delete(StorageKeys.postsBox, timestampKey);
      AppLogger.info('Comments cache cleared for post $postId');
    } catch (e, stackTrace) {
      AppLogger.error('Error clearing comments cache', error: e, stackTrace: stackTrace);
    }
  }

  /// Check if cache is expired (24 hours)
  Future<bool> _isCacheExpired(String timestampKey) async {
    final timestamp = await _storage.get<String>(
      StorageKeys.postsBox,
      timestampKey,
    );

    if (timestamp == null) return true;

    final cachedTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(cachedTime);

    return difference > const Duration(hours: 24);
  }
}
