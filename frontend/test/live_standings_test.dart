import 'package:flutter_test/flutter_test.dart';
import 'package:looped_app/models/leaderboard_model.dart';
import 'package:looped_app/models/live_standings.dart';

/// Server payload shaped like GET /events/:id/leaderboard.
LeaderboardResponse _response(
  List<(String id, String name, int points)> rows, {
  int myRank = 1,
  int myPoints = 0,
}) {
  return LeaderboardResponse(
    eventId: 'e1',
    leaderboard: rows
        .map((r) => LeaderboardEntry(
              userId: r.$1,
              username: r.$2,
              points: r.$3,
            ))
        .toList(),
    myPosition: MyPosition(rank: myRank, points: myPoints),
  );
}

void main() {
  group('LiveStandings.from', () {
    test('raises my row to the local counter while the heartbeat lags', () {
      // Server still has me at 300 (last heartbeat); I'm at 700 on screen.
      final standings = LiveStandings.from(
        data: _response([
          ('rival', 'Ana', 500),
          ('me', 'Gero', 300),
        ], myRank: 2, myPoints: 300),
        localPoints: 700,
        myUserId: 'me',
      );

      expect(standings.board.first.userId, 'me');
      expect(standings.board.first.points, 700);
      expect(standings.myRank, 1);
      expect(standings.amLeading, isTrue);
    });

    test('never walks my points backwards if the local count is behind', () {
      final standings = LiveStandings.from(
        data: _response([('me', 'Gero', 900)], myRank: 1, myPoints: 900),
        localPoints: 100,
        myUserId: 'me',
      );

      expect(standings.board.single.points, 900);
    });

    test('shows me before any heartbeat has landed', () {
      final standings = LiveStandings.from(
        data: _response([('rival', 'Ana', 500)], myRank: 2),
        localPoints: 120,
        myUserId: 'me',
      );

      expect(standings.board.length, 2);
      expect(standings.myIndex, 1);
      expect(standings.myRank, 2);
      expect(standings.board[1].username, 'VOS');
      expect(standings.board[1].points, 120);
    });

    test('trusts the server rank when I am past the board cut', () {
      // A full board without me: inserting myself would fake a position.
      final full = List.generate(LiveStandings.serverBoardLimit, (i) => ('u$i', 'D$i', 5000 - i * 10));
      final standings = LiveStandings.from(
        data: _response(full, myRank: 73, myPoints: 40),
        localPoints: 90,
        myUserId: 'me',
      );

      expect(standings.board.length, LiveStandings.serverBoardLimit);
      expect(standings.myIndex, -1);
      expect(standings.myRank, 73);
      expect(standings.ahead, isNull);
      expect(standings.pointsToAhead, isNull);
      expect(standings.amLeading, isFalse);
    });

    test('reports the gap to the dancer one place ahead', () {
      final standings = LiveStandings.from(
        data: _response([
          ('a', 'Ana', 900),
          ('b', 'Beto', 800),
          ('me', 'Gero', 750),
        ], myRank: 3, myPoints: 750),
        localPoints: 750,
        myUserId: 'me',
      );

      expect(standings.myRank, 3);
      expect(standings.ahead!.username, 'Beto');
      expect(standings.pointsToAhead, 50);
    });

    test('handles a logged-out reader without inventing a row', () {
      final standings = LiveStandings.from(
        data: _response([('a', 'Ana', 900)]),
        localPoints: 500,
        myUserId: null,
      );

      expect(standings.board.length, 1);
      expect(standings.myIndex, -1);
      expect(standings.visibleRowIndexes, [0]);
    });

    test('an empty event stays empty for a reader with no id', () {
      final standings = LiveStandings.from(
        data: _response([]),
        localPoints: 0,
        myUserId: null,
      );

      expect(standings.isEmpty, isTrue);
    });
  });

  group('visibleRowIndexes', () {
    List<int> windowFor({required int myPosition, required int total}) {
      // Descending points so my index lands exactly on myPosition.
      final rows = List.generate(
        total,
        (i) => (i == myPosition ? 'me' : 'u$i', 'D$i', 10000 - i * 10),
      );
      return LiveStandings.from(
        data: _response(rows, myRank: myPosition + 1),
        localPoints: 0,
        myUserId: 'me',
      ).visibleRowIndexes;
    }

    test('shows only the podium when I am on it', () {
      expect(windowFor(myPosition: 1, total: 20), [0, 1, 2]);
    });

    test('shows the podium plus my neighbours when I am below it', () {
      expect(windowFor(myPosition: 9, total: 20), [0, 1, 2, 8, 9, 10]);
    });

    test('does not duplicate the podium when I am fourth', () {
      // #3 is already on the podium, so only me and the one below me are added.
      expect(windowFor(myPosition: 3, total: 20), [0, 1, 2, 3, 4]);
    });

    test('stops at the bottom of the board when I am last', () {
      expect(windowFor(myPosition: 9, total: 10), [0, 1, 2, 8, 9]);
    });

    test('never runs past a board shorter than the podium', () {
      expect(windowFor(myPosition: 1, total: 2), [0, 1]);
    });
  });
}
