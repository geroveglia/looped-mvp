class SoloSession {
  final String? id;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final int points;
  final double? avgIntensity;
  final DateTime createdAt;

  SoloSession({
    this.id,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.points = 0,
    this.avgIntensity,
    required this.createdAt,
  });

  factory SoloSession.fromJson(Map<String, dynamic> json) {
    return SoloSession(
      id: json['_id'],
      userId: json['user_id'] ?? '',
      startedAt: DateTime.parse(json['started_at']),
      endedAt:
          json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      durationSeconds: json['duration_seconds'],
      points: json['points'] ?? 0,
      avgIntensity: json['avg_intensity']?.toDouble(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'user_id': userId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'points': points,
      'avg_intensity': avgIntensity,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
