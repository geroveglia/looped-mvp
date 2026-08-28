/// Where an event sits in the dancer's own timeline.
enum EventPhase {
  /// The floor is open right now.
  live,

  /// Announced, not started yet.
  upcoming,

  /// Over — or a party the dancer walked out of. Either way, history.
  past,
}

/// "Mis eventos" is really three lists wearing one name: what is happening now,
/// what is still coming, and everything already danced. Mixing them into a
/// single feed sorted by creation date is what made the history invisible — a
/// party from last March sat between two upcoming ones with a countdown that
/// read "EN CURSO".
class MyEventsShelf {
  final List<Map<String, dynamic>> live;
  final List<Map<String, dynamic>> upcoming;
  final List<Map<String, dynamic>> past;

  const MyEventsShelf({
    required this.live,
    required this.upcoming,
    required this.past,
  });

  bool get isEmpty => live.isEmpty && upcoming.isEmpty && past.isEmpty;

  int get length => live.length + upcoming.length + past.length;

  factory MyEventsShelf.from(List<Map<String, dynamic>> events) {
    final live = <Map<String, dynamic>>[];
    final upcoming = <Map<String, dynamic>>[];
    final past = <Map<String, dynamic>>[];

    for (final event in events) {
      switch (phaseOf(event)) {
        case EventPhase.live:
          live.add(event);
        case EventPhase.upcoming:
          upcoming.add(event);
        case EventPhase.past:
          past.add(event);
      }
    }

    // Soonest first up top — that is the one you have to get ready for.
    upcoming.sort((a, b) => _startMillis(a).compareTo(_startMillis(b)));
    // Most recent first down below — that is the one you want to look back at.
    past.sort((a, b) => _startMillis(b).compareTo(_startMillis(a)));

    return MyEventsShelf(live: live, upcoming: upcoming, past: past);
  }
}

/// The server's `status` decides, with one exception: a party the dancer left
/// is history for *them* even while it is still going for everybody else.
EventPhase phaseOf(Map<String, dynamic> event) {
  if (event['i_left'] == true) return EventPhase.past;
  switch (event['status']) {
    case 'active':
      return EventPhase.live;
    case 'ended':
      return EventPhase.past;
    default:
      return EventPhase.upcoming;
  }
}

/// Sort key. Falls back to created_at, then to 0, so a malformed row lands at
/// the far end of its section instead of throwing the whole list away.
int _startMillis(Map<String, dynamic> event) {
  for (final key in const ['starts_at', 'created_at']) {
    final raw = event[key];
    if (raw is! String) continue;
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
  }
  return 0;
}
