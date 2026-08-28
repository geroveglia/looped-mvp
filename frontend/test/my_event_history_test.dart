import 'package:flutter_test/flutter_test.dart';
import 'package:looped_app/models/my_event_history.dart';
import 'package:looped_app/models/my_event_stats.dart';

Map<String, dynamic> _event(
  String name, {
  String status = 'waiting',
  String? startsAt,
  bool iLeft = false,
}) {
  return {
    'name': name,
    'status': status,
    'starts_at': startsAt,
    'i_left': iLeft,
  };
}

void main() {
  group('MyEventsShelf', () {
    test('splits the feed into now, next and already danced', () {
      final shelf = MyEventsShelf.from([
        _event('Sótano', status: 'ended', startsAt: '2026-03-01T22:00:00Z'),
        _event('Terraza', status: 'active', startsAt: '2026-08-28T22:00:00Z'),
        _event('Costanera', status: 'waiting', startsAt: '2026-09-10T22:00:00Z'),
      ]);

      expect(shelf.live.single['name'], 'Terraza');
      expect(shelf.upcoming.single['name'], 'Costanera');
      expect(shelf.past.single['name'], 'Sótano');
      expect(shelf.length, 3);
    });

    test('puts the soonest party first among the upcoming ones', () {
      final shelf = MyEventsShelf.from([
        _event('Octubre', startsAt: '2026-10-01T22:00:00Z'),
        _event('Septiembre', startsAt: '2026-09-01T22:00:00Z'),
        _event('Diciembre', startsAt: '2026-12-01T22:00:00Z'),
      ]);

      expect(shelf.upcoming.map((e) => e['name']),
          ['Septiembre', 'Octubre', 'Diciembre']);
    });

    test('puts the most recent party first in the history', () {
      final shelf = MyEventsShelf.from([
        _event('Marzo', status: 'ended', startsAt: '2026-03-01T22:00:00Z'),
        _event('Julio', status: 'ended', startsAt: '2026-07-01T22:00:00Z'),
        _event('Mayo', status: 'ended', startsAt: '2026-05-01T22:00:00Z'),
      ]);

      expect(shelf.past.map((e) => e['name']), ['Julio', 'Mayo', 'Marzo']);
    });

    test('a party I walked out of is my history even while it is still live',
        () {
      final shelf = MyEventsShelf.from([
        _event('Me fui', status: 'active', iLeft: true),
      ]);

      expect(shelf.live, isEmpty);
      expect(shelf.past.single['name'], 'Me fui');
    });

    test('an event with no dates still lands in its section', () {
      final shelf = MyEventsShelf.from([
        _event('Sin fecha', status: 'ended'),
        _event('Con fecha', status: 'ended', startsAt: '2026-05-01T22:00:00Z'),
      ]);

      expect(shelf.past.map((e) => e['name']), ['Con fecha', 'Sin fecha']);
    });

    test('falls back to created_at when there is no start time', () {
      final shelf = MyEventsShelf.from([
        {'name': 'Vieja', 'status': 'ended', 'created_at': '2026-01-01T00:00:00Z'},
        {'name': 'Nueva', 'status': 'ended', 'created_at': '2026-06-01T00:00:00Z'},
      ]);

      expect(shelf.past.map((e) => e['name']), ['Nueva', 'Vieja']);
    });

    test('an empty membership list is an empty shelf, not three nulls', () {
      final shelf = MyEventsShelf.from([]);
      expect(shelf.isEmpty, isTrue);
      expect(shelf.live, isEmpty);
      expect(shelf.upcoming, isEmpty);
      expect(shelf.past, isEmpty);
    });
  });

  group('MyEventStats', () {
    Map<String, dynamic> payload() => {
          'event_id': 'e1',
          'event_name': 'Sótano',
          'event_status': 'ended',
          'rank': 2,
          'total_dancers': 40,
          'joined_at': '2026-03-01T21:00:00Z',
          'left_at': null,
          'summary': {
            'sessions_count': 2,
            'points': 1350,
            'dance_seconds': 1800,
            'best_session_points': 950,
            'first_danced_at': '2026-03-01T22:00:00Z',
            'last_danced_at': '2026-03-01T23:00:00Z',
            'is_dancing': false,
          },
          'sessions': [
            {
              '_id': 's1',
              'started_at': '2026-03-01T22:00:00Z',
              'ended_at': '2026-03-01T22:10:00Z',
              'duration_sec': 600,
              'points': 400,
            },
            {
              '_id': 's2',
              'started_at': '2026-03-01T23:00:00Z',
              'ended_at': null,
              'duration_sec': null,
              'points': 950,
            },
          ],
        };

    test('reads the totals and the board position', () {
      final stats = MyEventStats.fromJson(payload());

      expect(stats.rank, 2);
      expect(stats.totalDancers, 40);
      expect(stats.summary.points, 1350);
      expect(stats.summary.danceSeconds, 1800);
      expect(stats.sessions, hasLength(2));
      expect(stats.isPodium, isTrue);
      expect(stats.neverDanced, isFalse);
    });

    test('marks a session with no end as still open', () {
      final stats = MyEventStats.fromJson(payload());
      expect(stats.sessions.first.isOpen, isFalse);
      expect(stats.sessions.last.isOpen, isTrue);
      expect(stats.sessions.last.durationSec, isNull);
    });

    test('a dancer who joined and never danced is not on the podium', () {
      final stats = MyEventStats.fromJson({
        'event_id': 'e1',
        'rank': 1,
        'summary': {'sessions_count': 0, 'points': 0},
        'sessions': [],
      });

      expect(stats.neverDanced, isTrue);
      expect(stats.isPodium, isFalse);
    });

    test('survives a payload with fields missing', () {
      final stats = MyEventStats.fromJson({});
      expect(stats.rank, 0);
      expect(stats.sessions, isEmpty);
      expect(stats.summary.sessionsCount, 0);
      expect(stats.joinedAt, isNull);
    });
  });

  group('formatDanceTime', () {
    test('shows seconds for a session that barely started', () {
      expect(formatDanceTime(48), '48s');
    });

    test('shows whole minutes below the hour', () {
      expect(formatDanceTime(1800), '30m');
    });

    test('shows hours and minutes for a real night out', () {
      expect(formatDanceTime(5040), '1h 24m');
    });

    test('shows a flat hour without a stray zero', () {
      expect(formatDanceTime(3600), '1h 0m');
    });
  });
}
