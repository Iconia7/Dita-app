/// User data model
/// Represents a user in the DITA app
/// 
/// This model replaces the Map<String, dynamic> user objects used throughout the app
/// Benefits: Type safety, null safety, immutability, serialization
class UserModel {
  final int id;
  final String username;
  final String email;
  final String? avatar;
  final String? admissionNumber;
  final String? program;
  final int? yearOfStudy;
  final String? phoneNumber;
  final String? accessToken;
  final String? refreshToken;
  final int? points;
  final String? bio;
  final bool? isPaidMember;
  final String? membershipExpiry;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? attendancePercentage;  // Parsed from backend

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.avatar,
    this.admissionNumber,
    this.program,
    this.yearOfStudy,
    this.phoneNumber,
    this.accessToken,
    this.refreshToken,
    this.points,
    this.bio,
    this.isPaidMember,
    this.membershipExpiry,
    this.createdAt,
    this.updatedAt,
    this.attendancePercentage,
  });

  /// Create UserModel from JSON (API response)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? 'Unknown',
      email: json['email'] as String? ?? '',
      avatar: json['avatar'] as String?,
      admissionNumber: json['admission_number'] as String?,
      program: json['program'] as String?,
      yearOfStudy: json['year_of_study'] as int?,
      phoneNumber: json['phone_number'] as String?,
      accessToken: json['access'] as String?,
      refreshToken: json['refresh'] as String?,
      points: json['points'] as int?,
      bio: json['bio'] as String?,
      isPaidMember: json['is_paid_member'] as bool?,
      membershipExpiry: json['membership_expiry'] as String?,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at'] as String)
        : null,
      updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String)
        : null,
    );
  }

  /// Convert UserModel to JSON (for storage/API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar': avatar,
      'admission_number': admissionNumber,
      'program': program,
      'year_of_study': yearOfStudy,
      'phone_number': phoneNumber,
      'access': accessToken,
      'refresh': refreshToken,
      'points': points,
      'bio': bio,
      'is_paid_member': isPaidMember,
      'membership_expiry': membershipExpiry,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? email,
    String? avatar,
    String? admissionNumber,
    String? program,
    int? yearOfStudy,
    String? phoneNumber,
    String? accessToken,
    String? refreshToken,
    int? points,
    String? bio,
    bool? isPaidMember,
    String? membershipExpiry,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? attendancePercentage,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      program: program ?? this.program,
      yearOfStudy: yearOfStudy ?? this.yearOfStudy,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      points: points ?? this.points,
      bio: bio ?? this.bio,
      isPaidMember: isPaidMember ?? this.isPaidMember,
      membershipExpiry: membershipExpiry ?? this.membershipExpiry,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attendancePercentage: attendancePercentage ?? this.attendancePercentage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, email: $email)';
  }

  /// Get display name (username or admission number)
  String get displayName => username.isNotEmpty ? username : admissionNumber ?? 'User';

  /// Check if user has complete profile
  bool get hasCompleteProfile {
    return admissionNumber != null && 
           program != null && 
           yearOfStudy != null && 
           phoneNumber != null;
  }

  /// Get year label
  String get yearLabel => yearOfStudy != null ? 'Year $yearOfStudy' : 'Year N/A';

  /// Get attendance percentage from backend (not hardcoded)
  double get attendanceRate => attendancePercentage ?? 0.0;
}
