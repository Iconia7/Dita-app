/// Announcement data model
/// Represents a news/announcement item
class AnnouncementModel {
  final int id;
  final String title;
  final String messageBody;
  final String? image;
  final DateTime datePosted;
  final String? category;
  final bool isUrgent;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.messageBody,
    this.image,
    required this.datePosted,
    this.category,
    this.isUrgent = false,
  });

  /// Create from JSON
  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'No Title',
      messageBody: json['message'] as String? ?? json['message_body'] as String? ?? '',
      image: json['image'] as String?,
      datePosted: json['date_posted'] != null 
          ? DateTime.tryParse(json['date_posted'] as String) ?? DateTime.now()
          : DateTime.now(),
      category: json['category'] as String?,
      isUrgent: json['is_urgent'] as bool? ?? false,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message_body': messageBody,
      'image': image,
      'date_posted': datePosted.toIso8601String(),
      'category': category,
      'is_urgent': isUrgent,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnnouncementModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
