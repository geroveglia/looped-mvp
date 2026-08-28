class LeaderboardResponse {
  final String eventId;
  final List<LeaderboardEntry> leaderboard;
  final MyPosition myPosition;

  /// When the server built this table, not when we received it. The board is
  /// shared between everyone at the event for a few seconds, so a fresh reply
  /// can carry a slightly older table — this is the age the dancer is shown.
  final DateTime? updatedAt;

  LeaderboardResponse({
    required this.eventId,
    required this.leaderboard,
    required this.myPosition,
    this.updatedAt,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) {
    return LeaderboardResponse(
      eventId: json['event_id'] ?? '',
      leaderboard: (json['leaderboard'] as List?)
              ?.map((e) => LeaderboardEntry.fromJson(e))
              .toList() ??
          [],
      myPosition: json['my_position'] != null
          ? MyPosition.fromJson(json['my_position'])
          : MyPosition(rank: 0, points: 0),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '')
          ?.toLocal(),
    );
  }
}

class LeaderboardEntry {
  final String userId;
  final String username;
  final String? avatarUrl;
  final int points;
  final String rank;

  LeaderboardEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.points,
    this.rank = 'ghost',
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    // Tolerates both response shapes: /events/:id/leaderboard uses
    // user_id/points, aggregation endpoints may emit _id/totalPoints.
    return LeaderboardEntry(
      userId: (json['user_id'] ?? json['_id'] ?? '').toString(),
      username: json['username'] ?? 'Anonymous',
      avatarUrl: json['avatar_url'],
      points: ((json['points'] ?? json['totalPoints'] ?? 0) as num).toInt(),
      rank: json['rank'] ?? 'ghost',
    );
  }
}

class MyPosition {
  final int rank;
  final int points;

  MyPosition({required this.rank, required this.points});

  factory MyPosition.fromJson(Map<String, dynamic> json) {
    return MyPosition(
      rank: json['rank'] ?? 0,
      points: json['points'] ?? 0,
    );
  }
}
