/// What the dancer did at one event, as GET /events/:id/my-stats reports it.
///
/// A party is danced in tandas — the app opens and closes, the phone locks, the
/// stale-session sweep closes one and the next /start opens another — so the
/// numbers that matter are the totals across every session, plus the place on
/// the board that everyone else also sees.
class MyEventStats {
  final String eventId;
  final String eventName;
  final String eventStatus;

  /// Place on the event board. Competition-style, same as the leaderboard.
  final int rank;

  /// How many people danced at all — the denominator for [rank].
  final int totalDancers;

  final DateTime? joinedAt;

  /// Set when the dancer left the event; null while still a member.
  final DateTime? leftAt;

  final EventSessionsSummary summary;

  /// Oldest first, the way the night actually went.
  final List<EventSession> sessions;

  const MyEventStats({
    required this.eventId,
    required this.eventName,
    required this.eventStatus,
    required this.rank,
    required this.totalDancers,
    required this.joinedAt,
    required this.leftAt,
    required this.summary,
    required this.sessions,
  });

  /// True when there is nothing to show: joined, never danced.
  bool get neverDanced => summary.sessionsCount == 0;

  bool get isPodium => !neverDanced && rank <= 3;

  factory MyEventStats.fromJson(Map<String, dynamic> json) {
    final rawSessions = (json['sessions'] as List?) ?? const [];
    return MyEventStats(
      eventId: json['event_id']?.toString() ?? '',
      eventName: json['event_name']?.toString() ?? '',
      eventStatus: json['event_status']?.toString() ?? '',
      rank: _int(json['rank']),
      totalDancers: _int(json['total_dancers']),
      joinedAt: _date(json['joined_at']),
      leftAt: _date(json['left_at']),
      summary: EventSessionsSummary.fromJson(
          (json['summary'] as Map?)?.cast<String, dynamic>() ?? const {}),
      sessions: rawSessions
          .whereType<Map>()
          .map((s) => EventSession.fromJson(s.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class EventSessionsSummary {
  final int sessionsCount;
  final int points;
  final int danceSeconds;
  final int bestSessionPoints;
  final DateTime? firstDancedAt;
  final DateTime? lastDancedAt;

  /// A session is still open — the dancer is on the floor as we speak.
  final bool isDancing;

  const EventSessionsSummary({
    required this.sessionsCount,
    required this.points,
    required this.danceSeconds,
    required this.bestSessionPoints,
    required this.firstDancedAt,
    required this.lastDancedAt,
    required this.isDancing,
  });

  factory EventSessionsSummary.fromJson(Map<String, dynamic> json) {
    return EventSessionsSummary(
      sessionsCount: _int(json['sessions_count']),
      points: _int(json['points']),
      danceSeconds: _int(json['dance_seconds']),
      bestSessionPoints: _int(json['best_session_points']),
      firstDancedAt: _date(json['first_danced_at']),
      lastDancedAt: _date(json['last_danced_at']),
      isDancing: json['is_dancing'] == true,
    );
  }
}

class EventSession {
  final String id;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSec;
  final int points;

  const EventSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.durationSec,
    required this.points,
  });

  bool get isOpen => endedAt == null;

  factory EventSession.fromJson(Map<String, dynamic> json) {
    return EventSession(
      id: json['_id']?.toString() ?? '',
      startedAt: _date(json['started_at']),
      endedAt: _date(json['ended_at']),
      durationSec: json['duration_sec'] is num
          ? (json['duration_sec'] as num).round()
          : null,
      points: _int(json['points']),
    );
  }
}

/// Human duration for a card: "1h 24m", "24m", "48s".
String formatDanceTime(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m';
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

int _int(dynamic value) => value is num ? value.round() : 0;

DateTime? _date(dynamic value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
