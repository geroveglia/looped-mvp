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
      eventId: json['event_id'],
      leaderboard: (json['leaderboard'] as List)
          .map((e) => LeaderboardEntry.fromJson(e))
          .toList(),
      myPosition: MyPosition.fromJson(json['my_position']),
    );
  }
}

class LeaderboardEntry {
  final String userId;
  final String username;
  final String? avatarUrl;
  final int points;

  LeaderboardEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.points,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
      points: json['points'],
    );
  }
}

class MyPosition {
  final int rank;
  final int points;

  MyPosition({required this.rank, required this.points});

  factory MyPosition.fromJson(Map<String, dynamic> json) {
    return MyPosition(
      rank: json['rank'],
      points: json['points'],
    );
  }
}
