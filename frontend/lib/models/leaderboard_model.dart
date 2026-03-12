class LeaderboardResponse {
  final String eventId;
  final List<LeaderboardEntry> leaderboard;
  final MyPosition myPosition;

  LeaderboardResponse({
    required this.eventId,
    required this.leaderboard,
    required this.myPosition,
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
    return LeaderboardEntry(
      userId: json['user_id'] ?? '',
      username: json['username'] ?? 'Anonymous',
      avatarUrl: json['avatar_url'],
      points: json['points'] ?? 0,
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
