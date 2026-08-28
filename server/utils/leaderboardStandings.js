// How many dancers the client receives. Someone past this cut still gets an
// honest rank in my_position, but no row of their own and nobody to chase, so
// it has to sit above a real party's headcount.
// Keep in sync with LiveStandings.serverBoardLimit on the client.
const BOARD_LIMIT = 100;

/// Turns one grouped aggregation into everything the endpoint needs.
///
/// [totals] is `{ _id: userId, points }` sorted by points descending — every
/// dancer in the event, not just the visible ones, because a rank is only
/// correct when counted against the whole floor. [users] carries the display
/// data for the dancers that made the cut.
///
/// Ranks are competition-style: tied dancers share a place and the next one
/// skips (500, 500, 300 → 1st, 1st, 3rd), matching what the three separate
/// aggregations used to compute with `count(points > mine) + 1`.
function buildStandings({ totals, users, boardLimit = BOARD_LIMIT }) {
  const userById = new Map(users.map((u) => [String(u._id), u]));

  // The visible table. A dancer whose user document is gone is dropped, the
  // way the old $lookup + $unwind pair silently did.
  const board = [];
  for (const row of totals.slice(0, boardLimit)) {
    const user = userById.get(String(row._id));
    if (!user) continue;
    board.push({
      user_id: row._id,
      username: user.username,
      avatar_url: user.avatar_url,
      points: row.points,
    });
  }

  // One pass over the sorted totals: everything before the first entry with
  // my score is strictly ahead of me, so that index *is* my rank minus one.
  const ranks = new Map();
  let strictlyAhead = 0;
  for (let i = 0; i < totals.length; i++) {
    if (i > 0 && totals[i].points < totals[i - 1].points) strictlyAhead = i;
    ranks.set(String(totals[i]._id), {
      points: totals[i].points,
      rank: strictlyAhead + 1,
    });
  }

  // Someone who joined but has not scored yet sits behind everyone who has.
  const defaultRank = totals.filter((t) => t.points > 0).length + 1;

  return { board, ranks, defaultRank };
}

/// What a single dancer sees of the standings.
function positionOf(standings, userId) {
  const mine = standings.ranks.get(String(userId));
  return mine
    ? { rank: mine.rank, points: mine.points }
    : { rank: standings.defaultRank, points: 0 };
}

module.exports = { buildStandings, positionOf, BOARD_LIMIT };
