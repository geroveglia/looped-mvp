import 'dart:math' as math;

import 'leaderboard_model.dart';

/// The event standings as the dancer should see them *right now*.
///
/// Two things make this more than a sorted list:
///
/// * My own points reach the server only on the heartbeat (every 60s), so the
///   raw board shows me behind the counter spinning on the dance screen. Here
///   my row is raised to the local total.
/// * The server returns the top 50 only. Past that there is no honest way to
///   place myself among the rows I received, so I stay off the board and my
///   rank comes from the server's own count.
class LiveStandings {
  /// Sorted board, points descending, with my row already merged.
  final List<LeaderboardEntry> board;

  /// My index in [board], or -1 when I am past the server's cut.
  final int myIndex;

  /// My 1-based position. Falls back to the server's rank when off the board.
  final int myRank;

  const LiveStandings({
    required this.board,
    required this.myIndex,
    required this.myRank,
  });

  /// The server's board size cap (`$limit` in GET /events/:id/leaderboard).
  static const int serverBoardLimit = 100;

  factory LiveStandings.from({
    required LeaderboardResponse data,
    required int localPoints,
    required String? myUserId,
    int boardLimit = serverBoardLimit,
  }) {
    final board = List<LeaderboardEntry>.from(data.leaderboard);

    if (myUserId != null) {
      final index = board.indexWhere((e) => e.userId == myUserId);
      if (index >= 0) {
        final mine = board[index];
        // max(): server points are monotonic, never walk them backwards.
        board[index] = LeaderboardEntry(
          userId: mine.userId,
          username: mine.username,
          avatarUrl: mine.avatarUrl,
          points: math.max(mine.points, localPoints),
          rank: mine.rank,
        );
      } else if (board.length < boardLimit) {
        // No heartbeat has landed yet, but there is room on the board: the
        // dancer should see themselves from the first second.
        board.add(LeaderboardEntry(
          userId: myUserId,
          username: 'VOS',
          points: math.max(data.myPosition.points, localPoints),
        ));
      }
    }

    board.sort((a, b) => b.points.compareTo(a.points));

    final myIndex =
        myUserId == null ? -1 : board.indexWhere((e) => e.userId == myUserId);
    return LiveStandings(
      board: board,
      myIndex: myIndex,
      myRank: myIndex >= 0 ? myIndex + 1 : data.myPosition.rank,
    );
  }

  bool get isEmpty => board.isEmpty;

  bool get amLeading => myIndex == 0;

  /// The dancer one place ahead of me — null when I lead, or when I am off
  /// the board and there is no way to know who that is.
  LeaderboardEntry? get ahead => myIndex > 0 ? board[myIndex - 1] : null;

  /// Points I need to take the place above me. Null when there is nobody there.
  int? get pointsToAhead {
    final rival = ahead;
    if (rival == null) return null;
    return rival.points - board[myIndex].points;
  }

  /// Top 3 plus my immediate neighbours, as indexes into [board]. The rival one
  /// place ahead is what makes someone dance harder; the middle of the table is
  /// noise. Ascending, so a jump between values means rows were skipped.
  List<int> get visibleRowIndexes {
    final shown = <int>{};
    for (var i = 0; i < board.length && i < 3; i++) {
      shown.add(i);
    }
    if (myIndex >= 3) {
      for (var i = myIndex - 1; i <= myIndex + 1; i++) {
        if (i >= 3 && i < board.length) shown.add(i);
      }
    }
    return shown.toList()..sort();
  }
}
