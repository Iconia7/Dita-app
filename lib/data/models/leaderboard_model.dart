/// Leaderboard entry data model
/// Represents a user's position on the leaderboard
class LeaderboardModel {
  final int rank;
  final int userId;
  final String username;
  final String? avatar;
  final int points;
  final String? program;
  final int? yearOfStudy;
  final String? admissionNumber;

  const LeaderboardModel({
    required this.rank,
    required this.userId,
    required this.username,
    this.avatar,
    required this.points,
    this.program,
    this.yearOfStudy,
    this.admissionNumber,
  });

  /// Create LeaderboardModel from JSON (API response)
  factory LeaderboardModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardModel(
      rank: json['rank'] as int? ?? 0,
      userId: json['user_id'] as int? ?? json['id'] as int? ?? 0,
      username: json['username'] as String? ?? 'Unknown',
      avatar: json['avatar'] as String?,
      points: json['points'] as int? ?? 0,
      program: json['program'] as String?,
      yearOfStudy: json['year_of_study'] as int?,
      admissionNumber: json['admission_number'] as String?,
    );
  }

  /// Convert LeaderboardModel to JSON (for storage)
  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'user_id': userId,
      'username': username,
      'avatar': avatar,
      'points': points,
      'program': program,
      'year_of_study': yearOfStudy,
      'admission_number': admissionNumber,
    };
  }

  /// Create a copy with updated fields
  LeaderboardModel copyWith({
    int? rank,
    int? userId,
    String? username,
    String? avatar,
    int? points,
    String? program,
    int? yearOfStudy,
    String? admissionNumber,
  }) {
    return LeaderboardModel(
      rank: rank ?? this.rank,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      points: points ?? this.points,
      program: program ?? this.program,
      yearOfStudy: yearOfStudy ?? this.yearOfStudy,
      admissionNumber: admissionNumber ?? this.admissionNumber,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaderboardModel && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() {
    return 'LeaderboardModel(rank: $rank, username: $username, points: $points)';
  }

  /// Get medal emoji for top 3
  String? get medal {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return null;
    }
  }

  /// Check if in top 10
  bool get isTopTen => rank <= 10;

  /// Get year label
  String get yearLabel => yearOfStudy != null ? 'Year $yearOfStudy' : '';
}
