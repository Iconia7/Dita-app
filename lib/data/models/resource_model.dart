/// Resource data model
/// Represents an academic resource (notes, books, past papers, etc.)
class ResourceModel {
  final int id;
  final String title;
  final String description;
  final String fileUrl;
  final String? thumbnailUrl;
  final String category; // 'notes', 'past_papers', 'books', etc.
  final String? subject;
  final String? year; // academic year
  final String? semester;
  final int downloads;
  final double? rating;
  final int uploadedBy; // user ID
  final String? uploaderName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ResourceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.fileUrl,
    this.thumbnailUrl,
    required this.category,
    this.subject,
    this.year,
    this.semester,
    this.downloads = 0,
    this.rating,
    required this.uploadedBy,
    this.uploaderName,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create ResourceModel from JSON (API response)
  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    return ResourceModel(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      fileUrl: json['file_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      category: json['category'] as String,
      subject: json['subject'] as String?,
      year: json['year'] as String?,
      semester: json['semester'] as String?,
      downloads: json['downloads'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble(),
      uploadedBy: json['uploaded_by'] as int,
      uploaderName: json['uploader_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert ResourceModel to JSON (for storage/API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'file_url': fileUrl,
      'thumbnail_url': thumbnailUrl,
      'category': category,
      'subject': subject,
      'year': year,
      'semester': semester,
      'downloads': downloads,
      'rating': rating,
      'uploaded_by': uploadedBy,
      'uploader_name': uploaderName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  ResourceModel copyWith({
    int? id,
    String? title,
    String? description,
    String? fileUrl,
    String? thumbnailUrl,
    String? category,
    String? subject,
    String? year,
    String? semester,
    int? downloads,
    double? rating,
    int? uploadedBy,
    String? uploaderName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ResourceModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      fileUrl: fileUrl ?? this.fileUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      category: category ?? this.category,
      subject: subject ?? this.subject,
      year: year ?? this.year,
      semester: semester ?? this.semester,
      downloads: downloads ?? this.downloads,
      rating: rating ?? this.rating,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploaderName: uploaderName ?? this.uploaderName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ResourceModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ResourceModel(id: $id, title: $title, category: $category)';
  }

  /// Get file extension
  String get fileExtension {
    final uri = Uri.tryParse(fileUrl);
    if (uri != null) {
      final path = uri.path;
      final lastDot = path.lastIndexOf('.');
      if (lastDot != -1) {
        return path.substring(lastDot + 1).toLowerCase();
      }
    }
    return '';
  }

  /// Check if resource is popular (> 50 downloads)
  bool get isPopular => downloads > 50;

  /// Get category icon
  String get categoryIcon {
    switch (category.toLowerCase()) {
      case 'notes':
        return '📝';
      case 'past_papers':
        return '📄';
      case 'books':
        return '📚';
      case 'videos':
        return '🎥';
      default:
        return '📎';
    }
  }
}
