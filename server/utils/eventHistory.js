// What one dancer did at one event, folded out of their sessions.
//
// A dancer can open and close the app several times during the same party, so
// "my stats for this event" is never a single session: it is the sum of them.

/**
 * Seconds a session lasted.
 *
 * duration_sec is written at /stop, so a session that is still open — or one
 * the stale-session sweep closed without finalizing — has none. Those are
 * measured from the clock instead, and an open one counts up to [now].
 */
function sessionSeconds(session, now) {
    if (typeof session.duration_sec === 'number' && session.duration_sec > 0) {
        return Math.round(session.duration_sec);
    }
    const started = session.started_at
        ? new Date(session.started_at).getTime()
        : NaN;
    if (isNaN(started)) return 0;
    const ended = session.ended_at
        ? new Date(session.ended_at).getTime()
        : now.getTime();
    if (isNaN(ended)) return 0;
    return Math.max(0, Math.round((ended - started) / 1000));
}

/**
 * @param {Array} sessions  this dancer's DanceSessions for one event
 * @returns totals plus the window they span; zeroed when they never danced.
 */
function summarizeSessions(sessions, { now = new Date() } = {}) {
    const summary = {
        sessions_count: sessions.length,
        points: 0,
        dance_seconds: 0,
        best_session_points: 0,
        first_danced_at: null,
        last_danced_at: null,
        // An open session means they are on the floor right now.
        is_dancing: false,
    };

    for (const session of sessions) {
        const points = Math.max(0, Math.round(session.points || 0));
        summary.points += points;
        summary.dance_seconds += sessionSeconds(session, now);
        if (points > summary.best_session_points) {
            summary.best_session_points = points;
        }
        if (!session.ended_at) summary.is_dancing = true;

        const started = session.started_at ? new Date(session.started_at) : null;
        if (started && !isNaN(started.getTime())) {
            if (!summary.first_danced_at || started < summary.first_danced_at) {
                summary.first_danced_at = started;
            }
            if (!summary.last_danced_at || started > summary.last_danced_at) {
                summary.last_danced_at = started;
            }
        }
    }

    return summary;
}

module.exports = { summarizeSessions, sessionSeconds };
