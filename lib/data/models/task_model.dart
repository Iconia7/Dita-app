/// Task/Assignment data model
/// Represents a task in the study planner
class TaskModel {
  final int id;
  final int userId;
  final String title;
  final String? description;
  final DateTime dueDate;
  final bool isCompleted;
  final String? category;
  final int? priority; // 1 = Low, 2 = Medium, 3 = High
  final DateTime createdAt;
  final DateTime? completedAt;

  const TaskModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.dueDate,
    this.isCompleted = false,
    this.category,
    this.priority,
    required this.createdAt,
    this.completedAt,
  });

  /// Create from JSON
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Untitled Task',
      description: json['description'] as String?,
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? '') ?? DateTime.now().add(const Duration(days: 1)),
      isCompleted: json['is_completed'] as bool? ?? false,
      category: json['category'] as String?,
      priority: json['priority'] as int?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'due_date': dueDate.toIso8601String(),
      'is_completed': isCompleted,
      'category': category,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  /// Copy with updated fields
  TaskModel copyWith({
    int? id,
    int? userId,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? isCompleted,
    String? category,
    int? priority,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Check if task is overdue
  bool get isOverdue {
    if (isCompleted) return false;
    return dueDate.isBefore(DateTime.now());
  }

  /// Check if task is due today
  bool get isDueToday {
    final now = DateTime.now();
    return dueDate.year == now.year &&
           dueDate.month == now.month &&
           dueDate.day == now.day;
  }

  /// Get priority label
  String get priorityLabel {
    switch (priority) {
      case 3:
        return 'High';
      case 2:
        return 'Medium';
      case 1:
        return 'Low';
      default:
        return 'None';
    }
  }

  /// Get due date label
  String get dueDateLabel {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (isDueToday) return 'Due Today';
    if (difference == 1) return 'Due Tomorrow';
    if (difference == -1) return 'Due Yesterday';
    if (difference < 0) return 'Overdue ${-difference} days';
    if (difference <= 7) return 'Due in $difference days';

    return '${dueDate.day}/${dueDate.month}/${dueDate.year}';
  }
}
