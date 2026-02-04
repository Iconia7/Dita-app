import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/core/storage/local_storage.dart';
import 'package:dita_app/data/datasources/local/community_local_datasource.dart';
import 'package:dita_app/data/datasources/remote/community_remote_datasource.dart';
import 'package:dita_app/data/repositories/community_repository.dart';
import 'package:dita_app/data/models/post_model.dart';
import 'package:dita_app/data/models/comment_model.dart';
import 'package:dita_app/providers/auth_provider.dart';
import 'package:dita_app/providers/network_provider.dart';
import 'package:dita_app/utils/app_logger.dart';

// ========== State Classes ==========

class CommunityState {
  final List<PostModel> posts;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

   CommunityState({
    required this.posts,
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  CommunityState copyWith({
    List<PostModel>? posts,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return CommunityState(
      posts: posts ?? this.posts,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

// ========== Dependency Injection Providers ==========

/// Community local data source provider
final communityLocalDataSourceProvider = Provider<CommunityLocalDataSource>((ref) {
  return CommunityLocalDataSource(LocalStorage());
});

/// Community remote data source provider
final communityRemoteDataSourceProvider = Provider<CommunityRemoteDataSource>((ref) {
  return CommunityRemoteDataSource();
});

/// Community repository provider
final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(
    remoteDataSource: ref.watch(communityRemoteDataSourceProvider),
    localDataSource: ref.watch(communityLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

// ========== State Providers ==========

/// Community posts state provider
class CommunityNotifier extends StateNotifier<AsyncValue<CommunityState>> {
  final CommunityRepository _repository;
  static const int _limit = 10;

  CommunityNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadPosts();
  }

  /// Load posts (initial or refresh)
  Future<void> loadPosts() async {
    try {
      state = const AsyncValue.loading();
      AppLogger.info('Loading community posts...');

      final result = await _repository.getPosts(page: 1, limit: _limit);

      result.fold(
        (failure) {
          AppLogger.warning('Failed to load posts: ${failure.message}');
          state = AsyncValue.error(failure.message, StackTrace.current);
        },
        (posts) {
          AppLogger.success('Loaded ${posts.length} posts');
          state = AsyncValue.data(CommunityState(
            posts: posts,
            page: 1,
            hasMore: posts.length >= _limit,
            isLoadingMore: false,
          ));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error loading posts', error: e, stackTrace: stackTrace);
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Load next page of posts
  Future<void> loadMore() async {
    final currentState = state.value;
    if (currentState == null || currentState.isLoadingMore || !currentState.hasMore) return;

    try {
      AppLogger.info('Loading more community posts (Page: ${currentState.page + 1})...');
      
      state = AsyncValue.data(currentState.copyWith(isLoadingMore: true));

      final nextPage = currentState.page + 1;
      final result = await _repository.getPosts(page: nextPage, limit: _limit);

      result.fold(
        (failure) {
          AppLogger.warning('Failed to load more posts: ${failure.message}');
          state = AsyncValue.data(currentState.copyWith(isLoadingMore: false, hasMore: false));
        },
        (newPosts) {
          if (newPosts.isEmpty) {
            state = AsyncValue.data(currentState.copyWith(isLoadingMore: false, hasMore: false));
          } else {
            state = AsyncValue.data(currentState.copyWith(
              posts: [...currentState.posts, ...newPosts],
              page: nextPage,
              isLoadingMore: false,
              hasMore: newPosts.length >= _limit,
            ));
            AppLogger.success('Loaded ${newPosts.length} additional posts');
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error loading more posts', error: e, stackTrace: stackTrace);
      state = AsyncValue.data(currentState.copyWith(isLoadingMore: false));
    }
  }

  /// Create a new post
  Future<bool> createPost(Map<String, String> fields, File? imageFile) async {
    try {
      AppLogger.info('Creating post...');

      final result = await _repository.createPost(fields, imageFile);

      return result.fold(
        (failure) {
          AppLogger.warning('Create post failed: ${failure.message}');
          return false;
        },
        (success) {
          if (success) {
            AppLogger.success('Post created successfully');
            // Refresh posts list
            loadPosts();
          }
          return success;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Create post error', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Like a post
  Future<bool> likePost(int postId) async {
    try {
      AppLogger.info('Liking post $postId');

      final result = await _repository.likePost(postId);

      return result.fold(
        (failure) {
          AppLogger.warning('Like post failed: ${failure.message}');
          return false;
        },
        (data) {
          AppLogger.success('Post liked');
          
          // Optimistic update: Find and update the post in the current list
          state.whenData((currentState) {
            final posts = currentState.posts;
            final index = posts.indexWhere((p) => p.id == postId);
            if (index != -1) {
              final post = posts[index];
              final updatedPost = post.copyWith(
                hasLiked: !post.hasLiked,
                likeCount: post.hasLiked ? post.likeCount - 1 : post.likeCount + 1,
              );
              
              final updatedList = List<PostModel>.from(posts);
              updatedList[index] = updatedPost;
              state = AsyncValue.data(currentState.copyWith(posts: updatedList));
            }
          });
          return true;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Like post error', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Edit a post
  Future<bool> editPost(int postId, Map<String, dynamic> data) async {
    try {
      AppLogger.info('Editing post $postId');

      final result = await _repository.editPost(postId, data);

      return result.fold(
        (failure) {
          AppLogger.warning('Edit post failed: ${failure.message}');
          return false;
        },
        (success) {
          if (success) {
            AppLogger.success('Post edited');
            loadPosts();
          }
          return success;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Edit post error', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Delete a post
  Future<bool> deletePost(int postId) async {
    try {
      AppLogger.info('Deleting post $postId');

      final result = await _repository.deletePost(postId);

      return result.fold(
        (failure) {
          AppLogger.warning('Delete post failed: ${failure.message}');
          return false;
        },
        (success) {
          if (success) {
            AppLogger.success('Post deleted');
            loadPosts();
          }
          return success;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Delete post error', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Refresh posts
  Future<void> refresh() async {
    await loadPosts();
  }
}

/// Community posts provider
final communityProvider =
    StateNotifierProvider<CommunityNotifier, AsyncValue<CommunityState>>((ref) {
  final repository = ref.watch(communityRepositoryProvider);
  return CommunityNotifier(repository);
});

// ========== Comments Provider ==========

/// Comments provider for a specific post
/// This is a family provider - creates separate state for each post
final commentsProvider = StateNotifierProvider.family<
    CommentsNotifier,
    AsyncValue<List<CommentModel>>,
    int>((ref, postId) {
  final repository = ref.watch(communityRepositoryProvider);
  return CommentsNotifier(repository, postId);
});

/// Comments notifier
class CommentsNotifier extends StateNotifier<AsyncValue<List<CommentModel>>> {
  final CommunityRepository _repository;
  final int _postId;

  CommentsNotifier(this._repository, this._postId)
      : super(const AsyncValue.loading()) {
    loadComments();
  }

  /// Load comments for the post
  Future<void> loadComments() async {
    try {
      state = const AsyncValue.loading();
      AppLogger.info('Loading comments for post $_postId...');

      final result = await _repository.getComments(_postId);

      result.fold(
        (failure) {
          AppLogger.warning('Failed to load comments: ${failure.message}');
          state = AsyncValue.error(failure.message, StackTrace.current);
        },
        (comments) {
          AppLogger.success('Loaded ${comments.length} comments');
          state = AsyncValue.data(comments);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error loading comments', error: e, stackTrace: stackTrace);
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Post a comment
  Future<bool> postComment(String text) async {
    try {
      AppLogger.info('Posting comment on post $_postId');

      final result = await _repository.postComment(_postId, text);

      return result.fold(
        (failure) {
          AppLogger.warning('Post comment failed: ${failure.message}');
          return false;
        },
        (success) {
          if (success) {
            AppLogger.success('Comment posted');
            loadComments();
          }
          return success;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Post comment error', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Delete a comment
  Future<bool> deleteComment(int commentId) async {
    try {
      AppLogger.info('Deleting comment $commentId');

      final result = await _repository.deleteComment(commentId, _postId);

      return result.fold(
        (failure) {
          AppLogger.warning('Delete comment failed: ${failure.message}');
          return false;
        },
        (success) {
          if (success) {
            AppLogger.success('Comment deleted');
            loadComments();
          }
          return success;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Delete comment error', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Refresh comments
  Future<void> refresh() async {
    await loadComments();
  }
}
