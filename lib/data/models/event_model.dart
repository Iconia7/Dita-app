/// Event data model
/// Represents an event/announcement in the DITA app
class EventModel {
  final int id;
  final String title;
  final String description;
  final DateTime date;
  final String? time;
  final String? location;
  final String? image;
  final String? category;
  final int attendeeCount;
  final bool hasRsvpd;
  final bool hasAttended;
  final DateTime? createdAt;

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.time,
    this.location,
    this.image,
    this.category,
    this.attendeeCount = 0,
    this.hasRsvpd = false,
    this.hasAttended = false,
    this.createdAt,
  });

  /// Create from JSON
  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      time: json['time'] as String?,
      location: json['venue'] as String?, // Backend sends 'venue' not 'location'
      image: json['image'] as String?,
      category: json['category'] as String?,
      attendeeCount: json['attendee_count'] as int? ?? 0,
      hasRsvpd: json['has_rsvped'] as bool? ?? false,
      hasAttended: json['hasAttended'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'time': time,
      'location': location,
      'image': image,
      'category': category,
      'attendee_count': attendeeCount,
      'has_rsvped': hasRsvpd,
      'hasAttended': hasAttended,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Copy with updated fields
  EventModel copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? date,
    String? time,
    String? location,
    String? image,
    String? category,
    int? attendeeCount,
    bool? hasRsvpd,
    bool? hasAttended,
    DateTime? createdAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      image: image ?? this.image,
      category: category ?? this.category,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      hasRsvpd: hasRsvpd ?? this.hasRsvpd,
      hasAttended: hasAttended ?? this.hasAttended,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Is event in the past?
  bool get isPast => date.isBefore(DateTime.now());

  /// Is event upcoming?
  bool get isUpcoming => !isPast;

  /// Get formatted date string
  String get formattedDate {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';
    
    return '${date.day}/${date.month}/${date.year}';
  }
}
