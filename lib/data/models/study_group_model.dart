class StudyGroupModel {
  final int id;
  final String name;
  final String courseCode;
  final String description;
  final int memberCount;
  final DateTime createdAt;
  final bool isMember;
  final int creatorId;

  StudyGroupModel({
    required this.id,
    required this.name,
    required this.courseCode,
    required this.description,
    required this.memberCount,
    required this.createdAt,
    required this.isMember,
    required this.creatorId,
  });

  factory StudyGroupModel.fromJson(Map<String, dynamic> json) {
    return StudyGroupModel(
      id: json['id'],
      name: json['name'],
      courseCode: json['course_code'],
      description: json['description'],
      memberCount: json['member_count'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      isMember: json['is_member'] ?? false,
      creatorId: json['creator'] as int? ?? 0,
    );
  }
}

class GroupMessageModel {
  final int id;
  final String username;
  final String? avatar;
  final String content;
  final DateTime timestamp;

  GroupMessageModel({
    required this.id,
    required this.username,
    this.avatar,
    required this.content,
    required this.timestamp,
  });

  factory GroupMessageModel.fromJson(Map<String, dynamic> json) {
    return GroupMessageModel(
      id: json['id'],
      username: json['username'],
      avatar: json['avatar'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
