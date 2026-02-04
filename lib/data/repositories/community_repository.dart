import 'dart:io';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../datasources/remote/community_remote_datasource.dart';
import '../datasources/local/community_local_datasource.dart';
import '../../core/network/network_info.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../utils/app_logger.dart';

/// Repository for community posts and comments with offline-first capabilities
class CommunityRepository {
  final CommunityRemoteDataSource remoteDataSource;
  final CommunityLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  CommunityRepository({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Get all community posts (offline-first)
  Future<Either<Failure, List<PostModel>>> getPosts({int? page, int? limit}) async {
    try {
      final isConnected = await networkInfo.isConnected;
      final isFirstPage = page == null || page == 1;

      if (isConnected) {
        try {
          // Fetch from remote
          final posts = await remoteDataSource.getPosts(page: page, limit: limit);
          
          // Cache only first page or refresh all if we fetch with pagination? 
          // For simplicity, only cache first page locally to keep the "latest" feed offline
          if (isFirstPage) {
            await localDataSource.cachePosts(posts);
          }
          
          AppLogger.success('Fetched ${posts.length} posts from remote (page: $page)');
          return Right(posts);
        } catch (e) {
          AppLogger.warning('Remote fetch failed, falling back to cache');
          
          // Fallback to cache
          final cachedPosts = await localDataSource.getCachedPosts();
          if (cachedPosts != null && cachedPosts.isNotEmpty) {
            return Right(cachedPosts);
          }
          
          return Left(ServerFailure('Failed to fetch posts'));
        }
      } else {
        // Offline: return cached data
        AppLogger.info('Offline mode: using cached posts');
        final cachedPosts = await localDataSource.getCachedPosts();
        
        if (cachedPosts != null && cachedPosts.isNotEmpty) {
          return Right(cachedPosts);
        }
        
        return Left(NetworkFailure('No internet connection and no cached data'));
      }
    } catch (e, stackTrace) {
      AppLogger.error('Repository error getting posts', error: e, stackTrace: stackTrace);
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  /// Get comments for a post (offline-first)
  Future<Either<Failure, List<CommentModel>>> getComments(int postId) async {
    try {
      final isConnected = await networkInfo.isConnected;

      if (isConnected) {
        try {
          final comments = await remoteDataSource.getComments(postId);
          await localDataSource.cacheComments(postId, comments);
          return Right(comments);
        } catch (e) {
          final cachedComments = await localDataSource.getCachedComments(postId);
          if (cachedComments != null) {
            return Right(cachedComments);
          }
          return Left(ServerFailure('Failed to fetch comments'));
        }
      } else {
        final cachedComments = await localDataSource.getCachedComments(postId);
        if (cachedComments != null) {
          return Right(cachedComments);
        }
        return Left(NetworkFailure('No internet connection and no cached data'));
      }
    } catch (e, stackTrace) {
      AppLogger.error('Repository error getting comments', error: e, stackTrace: stackTrace);
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  /// Create a new post (online only)
  Future<Either<Failure, bool>> createPost(
    Map<String, String> fields,
    File? imageFile,
  ) async {
    try {
      final isConnected = await networkInfo.isConnected;

      if (!isConnected) {
        return Left(NetworkFailure('Cannot create post while offline'));
      }

      final success = await remoteDataSource.createPost(fields, imageFile);
      
      if (success) {
        // Invalidate cache
        await localDataSource.clearPostsCache();
        return const Right(true);
      }
      
      return Left(ServerFailure('Failed to create post'));
    } catch (e, stackTrace) {
      AppLogger.error('Repository error creating post', error: e, stackTrace: stackTrace);
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  /// Like a post (online only)
  Future<Either<Failure, Map<String, dynamic>>> likePost(int postId) async {
    try {
      final isConnected = await networkInfo.isConnected;

      if (!isConnected) {
        return Left(NetworkFailure('Cannot like post while offline'));
      }

      final result = await remoteDataSource.likePost(postId);
      
      if (result != null) {
        return Right(result);
      }
      
      return Left(ServerFailure('Failed to like post'));
    } catch (e, stackTrace) {
      AppLogger.error('Repository error liking post', error: e, stackTrace: stackTrace);
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  /// Edit a post (online only)
  Future<Either<Failure, bool>> editPost(
    int postId,
    Map<String, dynamic> data,
  ) async {
    try {
      final isConnected = await networkInfo.isConnected;

      if (!isConnected) {
        return Left(NetworkFailure('Cannot edit post while offline'));
      }

      final success = await remoteDataSource.editPost(postId, data);
      
      if (success) {
        await localDataSource.clearPostsCache();
        return const Right(true);
      }
      
      return Left(ServerFailure('Failed to edit post'));
    } catch (e, stackTrace) {
      AppLogger.error('Repository error editing post', error: e, stackTrace: stackTrace);
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  /// Delete a post (online only)
  Future<Either<Failure, bool>> deletePost(int postId) async {
    try {
      final isConnected = await networkInfo.isConnected;

      if (!isConnected) {
        return Left(NetworkFailure('Cannot delete post while offline'));
      }

      final success = await remoteDataSource.deletePost(postId);
      
      if (success) {
        await localDataSource.clearPostsCache();
        return const Right(true);
      }
      
      return Left(ServerFailure('Failed to delete post'));
    } catch (e, stackTrace) {
      AppLogger.error('Repository error deleting post', error: e, stackTrace: stackTrace);
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  /// Post a comment (online only)
  Future<Either<Failure, bool>> postComment(int postId, String text) async {
    try {
      final isConnected = await networkInfo.isConnected;

      if (!isConnected) {
        return Left(NetworkFailure('Cannot post comment while offline'));
      }

      final success = await remoteDataSource.postComment(postId, text);
      
      if (success) {
        await localDataSource.clearCommentsCache(postId);
        return const Right(true);
      }
      
      return Left(ServerFailure('Failed to post comment'));
    } catch (e, stackTrace) {
      AppLogger.error('Repository error posting comment', error: e, stackTrace: stackTrace);
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  /// Delete a comment (online only)
  Future<Either<Failure, bool>> deleteComment(int commentId, int postId) async {
    try {
      final isConnected = await networkInfo.isConnected;

      if (!isConnected) {
        return Left(NetworkFailure('Cannot delete comment while offline'));
      }

      final success = await remoteDataSource.deleteComment(commentId);
      
      if (success) {
        await localDataSource.clearCommentsCache(postId);
        return const Right(true);
      }
      
      return Left(ServerFailure('Failed to delete comment'));
    } catch (e, stackTrace) {
      AppLogger.error('Repository error deleting comment', error: e, stackTrace: stackTrace);
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }
}
