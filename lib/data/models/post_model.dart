/// Community Post data model
/// Represents a post in the community feed
class PostModel {
  final int id;
  final int authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final String? image;
  final int likeCount;
  final int commentCount;
  final bool hasLiked;
  final String category;
  final bool isAnonymous;
  final bool isOwner; // Helper for UI not always from API, but good to have if API sends it
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    this.image,
    this.likeCount = 0,
    this.commentCount = 0,
    this.hasLiked = false,
    this.category = 'GENERAL',
    this.isAnonymous = false,
    this.isOwner = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create from JSON
  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as int? ?? 0,
      authorId: json['user'] as int? ?? 0,
      authorName: json['user_name'] as String? ?? json['username'] as String? ?? 'Unknown',
      authorAvatar: json['user_avatar'] as String? ?? json['avatar'] as String?,
      content: json['content'] as String? ?? '',
      image: json['image'] as String?,
      likeCount: json['likes'] as int? ?? json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      hasLiked: json['is_liked'] as bool? ?? json['has_liked'] as bool? ?? false,
      category: json['category'] as String? ?? 'GENERAL',
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      isOwner: json['is_owner'] as bool? ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': authorId,
      'user_name': authorName,
      'user_avatar': authorAvatar,
      'content': content,
      'image': image,
      'like_count': likeCount,
      'comment_count': commentCount,
      'has_liked': hasLiked,
      'category': category,
      'is_anonymous': isAnonymous,
      'is_owner': isOwner,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Copy with updated fields
  PostModel copyWith({
    int? id,
    int? authorId,
    String? authorName,
    String? authorAvatar,
    String? content,
    String? image,
    int? likeCount,
    int? commentCount,
    bool? hasLiked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      image: image ?? this.image,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      hasLiked: hasLiked ?? this.hasLiked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Check if post was edited
  bool get isEdited => updatedAt != null && updatedAt != createdAt;
}
