import 'dart:io';
import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../../services/api_service.dart';
import '../../../core/errors/exceptions.dart';
import '../../../utils/app_logger.dart';

/// Remote data source for community features
/// Handles posts and comments
class CommunityRemoteDataSource {
  /// Fetch all community posts
  Future<List<PostModel>> getPosts({int? page, int? limit}) async {
    try {
      final jsonList = await ApiService.getCommunityPosts(page: page, limit: limit);
      final posts = jsonList
          .map((json) => PostModel.fromJson(json as Map<String, dynamic>))
          .toList();
      AppLogger.success('Parsed ${posts.length} posts');
      return posts;
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing posts', error: e, stackTrace: stackTrace);
      throw DataParsingException('Failed to parse posts data');
    }
  }

  /// Fetch comments for a specific post
  Future<List<CommentModel>> getComments(int postId) async {
    try {
      final jsonList = await ApiService.getComments(postId);
      final comments = jsonList
          .map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
          .toList();
      AppLogger.success('Parsed ${comments.length} comments for post $postId');
      return comments;
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing comments', error: e, stackTrace: stackTrace);
      throw DataParsingException('Failed to parse comments data');
    }
  }

  /// Create a new post
  Future<bool> createPost(Map<String, String> fields, File? imageFile) async {
    try {
      return await ApiService.createPost(fields, imageFile);
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error creating post', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to create post');
    }
  }

  /// Like a post
  Future<Map<String, dynamic>?> likePost(int postId) async {
    try {
      return await ApiService.likePost(postId);
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error liking post', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to like post');
    }
  }

  /// Edit a post
  Future<bool> editPost(int postId, Map<String, dynamic> data) async {
    try {
      return await ApiService.editPost(postId, data);
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error editing post', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to edit post');
    }
  }

  /// Delete a post
  Future<bool> deletePost(int postId) async {
    try {
      return await ApiService.deletePost(postId);
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting post', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to delete post');
    }
  }

  /// Post a comment
  Future<bool> postComment(int postId, String text) async {
    try {
      return await ApiService.postComment(postId, text);
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error posting comment', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to post comment');
    }
  }

  /// Delete a comment
  Future<bool> deleteComment(int commentId) async {
    try {
      return await ApiService.deleteComment(commentId);
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting comment', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to delete comment');
    }
  }
}
