/// Comment data model
/// Represents a comment on a community post
class CommentModel {
  final int id;
  final int postId;
  final int authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final bool isOwner; // Helper for UI
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    this.isOwner = false,
    required this.createdAt,
  });

  /// Create from JSON
  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as int? ?? 0,
      postId: json['post'] as int? ?? 0,
      authorId: json['user'] as int? ?? 0,
      authorName: json['user_name'] as String? ?? json['username'] as String? ?? 'Unknown',
      authorAvatar: json['user_avatar'] as String? ?? json['avatar'] as String?,
      content: json['content'] as String? ?? json['text'] as String? ?? '',
      isOwner: json['is_owner'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post': postId,
      'user': authorId,
      'user_name': authorName,
      'user_avatar': authorAvatar,
      'content': content,
      'is_owner': isOwner,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Copy with updated fields
  CommentModel copyWith({
    int? id,
    int? postId,
    int? authorId,
    String? authorName,
    String? authorAvatar,
    String? content,
    DateTime? createdAt,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
