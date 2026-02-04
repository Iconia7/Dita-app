class AchievementModel {
  final int id;
  final String name;
  final String description;
  final String? iconUrl;
  final DateTime earnedAt;

  AchievementModel({
    required this.id,
    required this.name,
    required this.description,
    this.iconUrl,
    required this.earnedAt,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'],
      name: json['achievement_name'],
      description: json['achievement_description'],
      iconUrl: json['achievement_icon'],
      earnedAt: DateTime.parse(json['earned_at']),
    );
  }
}
