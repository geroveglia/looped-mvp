const mongoose = require('mongoose');

const DanceSessionSchema = new mongoose.Schema({
    event_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Event', required: true },
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    started_at: { type: Date, required: true },
    ended_at: { type: Date },
    duration_sec: { type: Number },
    points: { type: Number, default: 0 },
    is_suspicious: { type: Boolean, default: false },
    suspicion_score: { type: Number, default: 0 },
    motion_stats: { type: Map, of: mongoose.Schema.Types.Mixed },
    // Live-sync bookkeeping: updated by POST /sessions/heartbeat. Sessions with
    // no heartbeat for a while are auto-closed by the stale-session sweep.
    last_heartbeat_at: { type: Date },
    // True when the sweep closed it; an explicit /stop can still finalize it.
    auto_closed: { type: Boolean, default: false }
});

// Hot paths: leaderboards group by event, sweeps scan open sessions
DanceSessionSchema.index({ event_id: 1, user_id: 1 });
DanceSessionSchema.index({ ended_at: 1, last_heartbeat_at: 1 });

module.exports = mongoose.model('DanceSession', DanceSessionSchema);
