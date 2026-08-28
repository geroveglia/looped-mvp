const mongoose = require("mongoose");
const DanceSession = require("../models/DanceSession");
const User = require("../models/User");
const { createTtlCache } = require("./ttlCache");
const { buildStandings, BOARD_LIMIT } = require("./leaderboardStandings");

// Every dancer at an event polls the same table — only my_position differs.
// Sixty phones polling every 15s asked for that identical table 240 times a
// minute, and each ask ran three aggregations. This window keeps the answer
// well inside the client's own poll interval while collapsing that load.
const TTL_MS = 8000;

const cache = createTtlCache({ ttlMs: TTL_MS });

/// Every dancer's total for one event, best first, plus the display data for
/// the ones that made the visible cut. One aggregation where there used to be
/// three: the board, my points and my rank all come out of the same pass.
async function computeStandings(eventId) {
  const eventObjId = new mongoose.Types.ObjectId(String(eventId));

  const totals = await DanceSession.aggregate([
    { $match: { event_id: eventObjId } },
    { $group: { _id: "$user_id", points: { $sum: "$points" } } },
    { $sort: { points: -1 } },
  ]);

  const visibleIds = totals.slice(0, BOARD_LIMIT).map((t) => t._id);
  const users = await User.find({ _id: { $in: visibleIds } })
    .select("username avatar_url")
    .lean();

  return { ...buildStandings({ totals, users }), computedAt: Date.now() };
}

/// Standings for an event, shared by everyone reading them within [TTL_MS].
///
/// The key is stringified on the way in: the cache is a Map, and an ObjectId
/// only ever equals itself by reference, so an un-normalized caller would miss
/// every time and leak an entry per request.
function getEventStandings(eventId) {
  const key = String(eventId);
  return cache.get(key, () => computeStandings(key));
}

/// For results that must not lag — a host closing an event, say.
function invalidateEvent(eventId) {
  cache.invalidate(String(eventId));
}

module.exports = { getEventStandings, invalidateEvent, TTL_MS };
