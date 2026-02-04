import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../utils/app_logger.dart';

class StoryModel {
  final String id;
  final String? userId; // Optional as it might not be in the simple serializer
  final String username;
  final String? userAvatar;
  final String? imageUrl;
  final String? videoUrl;
  final String? caption;
  final DateTime createdAt;
  final bool isViewed;
  final bool isLiked;
  final int likes;
  final int commentCount;

  StoryModel({
    required this.id,
    this.userId,
    required this.username,
    this.userAvatar,
    this.imageUrl,
    this.videoUrl,
    this.caption,
    required this.createdAt,
    this.isViewed = false,
    this.isLiked = false,
    this.likes = 0,
    this.commentCount = 0,
  });

  bool get isExpired => DateTime.now().difference(createdAt).inHours >= 24;

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'].toString(),
      username: json['username'] ?? 'Anonymous',
      userAvatar: json['user_avatar'],
      imageUrl: json['image'],
      videoUrl: json['video'],
      caption: json['caption'],
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      isViewed: json['is_viewed'] ?? false,
      isLiked: json['is_liked'] ?? false,
      likes: json['likes'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
    );
  }

  StoryModel copyWith({
    String? id,
    String? userId,
    String? username,
    String? userAvatar,
    String? imageUrl,
    String? videoUrl,
    String? caption,
    DateTime? createdAt,
    bool? isViewed,
    bool? isLiked,
    int? likes,
    int? commentCount,
  }) {
    return StoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatar: userAvatar ?? this.userAvatar,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      isViewed: isViewed ?? this.isViewed,
      isLiked: isLiked ?? this.isLiked,
      likes: likes ?? this.likes,
      commentCount: commentCount ?? this.commentCount,
    );
  }
}

class StoriesNotifier extends StateNotifier<List<StoryModel>> {
  StoriesNotifier() : super([]) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final jsonList = await ApiService.get('stories/');
      if (jsonList is List) {
        state = jsonList.map((j) => StoryModel.fromJson(j)).toList();
        AppLogger.success('Fetched ${state.length} stories');
      }
    } catch (e) {
      AppLogger.error('Failed to fetch stories', error: e);
    }
  }

  Future<bool> addStory(File file, String? caption) async {
    try {
      final success = await ApiService.createStory(caption, file);
      if (success) {
        await refresh();
        return true;
      }
    } catch (e) {
      AppLogger.error('Failed to add story', error: e);
    }
    return false;
  }

  Future<void> markAsViewed(String storyId) async {
    try {
      final id = int.tryParse(storyId);
      if (id != null) {
        await ApiService.markStoryAsViewed(id);
        // Optimistic update
        state = state.map((s) => s.id == storyId ? 
          s.copyWith(isViewed: true) : s
        ).toList();
      }
    } catch (e) {
      AppLogger.error('Failed to mark story as viewed', error: e);
    }
  }

  Future<void> toggleLike(String storyId) async {
    try {
      final id = int.tryParse(storyId);
      if (id != null) {
        final result = await ApiService.post('stories/$id/like/', {});
        
        if (result != null && result['status'] == 'toggled') {
          state = state.map((s) => s.id == storyId ? 
            s.copyWith(
              isLiked: result['is_liked'],
              likes: result['likes']
            ) : s
          ).toList();
        }
      }
    } catch (e) {
      AppLogger.error('Failed to toggle like', error: e);
    }
  }

  Future<bool> addComment(String storyId, String text) async {
    try {
      final id = int.tryParse(storyId);
      if (id != null) {
        final result = await ApiService.post('stories/$id/comment/', {'text': text});
        if (result != null) {
          // Update comment count locally
          state = state.map((s) => s.id == storyId ? 
            s.copyWith(commentCount: s.commentCount + 1) : s
          ).toList();
          return true;
        }
      }
    } catch (e) {
      AppLogger.error('Failed to add comment', error: e);
    }
    return false;
  }
}

final storiesProvider = StateNotifierProvider<StoriesNotifier, List<StoryModel>>((ref) {
  return StoriesNotifier();
});
