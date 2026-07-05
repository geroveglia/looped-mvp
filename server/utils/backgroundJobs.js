/**
 * Periodic maintenance jobs.
 * Started from server.js once MongoDB is connected.
 */

const Event = require('../models/Event');
const DanceSession = require('../models/DanceSession');
const EventMember = require('../models/EventMember');
const { pushToUsers } = require('./push');

// A session with no heartbeat for this long is considered abandoned
// (phone died, app killed). The client heartbeats every ~60s.
const STALE_SESSION_MS = 15 * 60 * 1000;
// Events with no ends_at can't stay active forever; parties don't last a day.
const MAX_EVENT_LIFETIME_MS = 24 * 60 * 60 * 1000;

const SWEEP_INTERVAL_MS = 5 * 60 * 1000;
const EVENT_STATUS_INTERVAL_MS = 60 * 1000;

/**
 * Close open sessions whose owner disappeared (no /stop, no heartbeats).
 * They are closed at the last evidence of activity and flagged auto_closed,
 * so a late explicit /stop can still finalize them with real totals.
 */
async function closeStaleSessions() {
    const cutoff = new Date(Date.now() - STALE_SESSION_MS);
    const stale = await DanceSession.find({
        ended_at: null,
        $or: [
            { last_heartbeat_at: { $lt: cutoff } },
            { last_heartbeat_at: null, started_at: { $lt: cutoff } },
        ],
    }).limit(500);

    for (const session of stale) {
        const lastSeen = session.last_heartbeat_at || session.started_at;
        session.ended_at = lastSeen;
        session.duration_sec = Math.max(
            0,
            Math.round((lastSeen.getTime() - session.started_at.getTime()) / 1000)
        );
        session.auto_closed = true;
        await session.save();
    }

    if (stale.length > 0) {
        console.log(`[jobs] Auto-closed ${stale.length} stale dance session(s)`);
    }
}

/**
 * Time-based event lifecycle, so the host doesn't have to press START/END
 * at the exact moment (manual PATCH /events/:id/status still works):
 *  - waiting -> active  once starts_at passes (unless the event is long over)
 *  - active  -> ended   once ends_at passes, or 24h after start if open-ended
 *  - waiting -> ended   for events that were never activated and are long past
 */
async function updateEventStatuses() {
    const now = new Date();
    const staleStart = new Date(now.getTime() - MAX_EVENT_LIFETIME_MS);

    // Find first (instead of a blind updateMany) so members of each newly
    // activated event can get a push notification.
    const toActivate = await Event.find({
        status: 'waiting',
        starts_at: { $lte: now, $gt: staleStart },
        $or: [{ ends_at: null }, { ends_at: { $gt: now } }],
    }).select('_id name');

    if (toActivate.length > 0) {
        await Event.updateMany(
            { _id: { $in: toActivate.map(e => e._id) } },
            { $set: { status: 'active' } }
        );
        for (const event of toActivate) {
            notifyEventStarted(event); // fire-and-forget
        }
    }
    const activated = { modifiedCount: toActivate.length };

    const endedByTime = await Event.updateMany(
        { status: 'active', ends_at: { $lte: now } },
        { $set: { status: 'ended' } }
    );

    const endedByAge = await Event.updateMany(
        {
            status: { $in: ['active', 'waiting'] },
            starts_at: { $lte: staleStart },
            $or: [{ ends_at: null }, { ends_at: { $lte: now } }],
        },
        { $set: { status: 'ended' } }
    );

    const changed =
        (activated.modifiedCount || 0) +
        (endedByTime.modifiedCount || 0) +
        (endedByAge.modifiedCount || 0);
    if (changed > 0) {
        console.log(
            `[jobs] Event statuses: +${activated.modifiedCount || 0} active, ` +
            `+${(endedByTime.modifiedCount || 0) + (endedByAge.modifiedCount || 0)} ended`
        );
    }
}

/** Push "the party started" to every member of a newly activated event. */
async function notifyEventStarted(event) {
    try {
        const members = await EventMember.find({
            event_id: event._id,
            left_at: null,
        }).select('user_id');
        if (members.length === 0) return;
        await pushToUsers(members.map(m => m.user_id), {
            title: '¡Arrancó la fiesta! 🎉',
            body: `${event.name} ya está activo — entrá y empezá a sumar puntos`,
            data: { event_id: event._id.toString() },
        });
    } catch (err) {
        console.error('[jobs] notifyEventStarted failed:', err.message);
    }
}

function startBackgroundJobs() {
    const safe = (fn, name) => () =>
        fn().catch(err => console.error(`[jobs] ${name} failed:`, err.message));

    // Run once at boot to catch up after downtime, then on their intervals.
    safe(updateEventStatuses, 'updateEventStatuses')();
    safe(closeStaleSessions, 'closeStaleSessions')();

    setInterval(safe(updateEventStatuses, 'updateEventStatuses'), EVENT_STATUS_INTERVAL_MS);
    setInterval(safe(closeStaleSessions, 'closeStaleSessions'), SWEEP_INTERVAL_MS);
}

module.exports = {
    startBackgroundJobs,
    closeStaleSessions,
    updateEventStatuses,
    notifyEventStarted,
};
