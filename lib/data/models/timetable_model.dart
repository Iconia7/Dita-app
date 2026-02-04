/// Timetable entry data model
/// Represents a single class or exam entry in a timetable
class TimetableModel {
  final int id;
  final String type; // 'class' or 'exam'
  final String title;
  final String? code; // unit code
  final String? lecturer;
  final String? venue;
  final String dayOfWeek; // 'Monday', 'Tuesday', etc.
  final String startTime; // '08:00'
  final String endTime; // '10:00'
  final DateTime? examDate; // for exam timetables
  final String? description;
  final String? semester;
  final DateTime? createdAt;

  const TimetableModel({
    required this.id,
    required this.type,
    required this.title,
    this.code,
    this.lecturer,
    this.venue,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.examDate,
    this.description,
    this.semester,
    this.createdAt,
  });

  /// Create TimetableModel from JSON (API response)
  factory TimetableModel.fromJson(Map<String, dynamic> json) {
    return TimetableModel(
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? 'class',
      title: json['title'] as String? ?? json['unit_name'] as String? ?? 'Untitled',
      code: json['code'] as String? ?? json['unit_code'] as String?,
      lecturer: json['lecturer'] as String?,
      venue: json['venue'] as String? ?? json['room'] as String?,
      dayOfWeek: json['day_of_week'] as String? ?? json['day'] as String? ?? 'Monday',
      startTime: json['start_time'] as String? ?? '08:00',
      endTime: json['end_time'] as String? ?? '10:00',
      examDate: json['exam_date'] != null
          ? DateTime.tryParse(json['exam_date'] as String)
          : json['date'] != null
              ? DateTime.tryParse(json['date'] as String)
              : null,
      description: json['description'] as String?,
      semester: json['semester'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert TimetableModel to JSON (for storage/API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'code': code,
      'lecturer': lecturer,
      'venue': venue,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'exam_date': examDate?.toIso8601String(),
      'description': description,
      'semester': semester,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  TimetableModel copyWith({
    int? id,
    String? type,
    String? title,
    String? code,
    String? lecturer,
    String? venue,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
    DateTime? examDate,
    String? description,
    String? semester,
    DateTime? createdAt,
  }) {
    return TimetableModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      code: code ?? this.code,
      lecturer: lecturer ?? this.lecturer,
      venue: venue ?? this.venue,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      examDate: examDate ?? this.examDate,
      description: description ?? this.description,
      semester: semester ?? this.semester,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimetableModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TimetableModel(id: $id, title: $title, type: $type, day: $dayOfWeek)';
  }

  /// Check if this is a class entry
  bool get isClass => type == 'class';

  /// Check if this is an exam entry
  bool get isExam => type == 'exam';

  /// Get formatted time range
  String get timeRange => '$startTime - $endTime';

  /// Get day number (0 = Monday, 6 = Sunday)
  int get dayNumber {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days.indexOf(dayOfWeek);
  }

  /// Check if exam is in the past
  bool get isPastExam {
    if (examDate == null) return false;
    return examDate!.isBefore(DateTime.now());
  }

  /// Check if exam is upcoming (within 7 days)
  bool get isUpcomingExam {
    if (examDate == null) return false;
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));
    return examDate!.isAfter(now) && examDate!.isBefore(sevenDaysFromNow);
  }
}
