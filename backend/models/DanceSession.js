const mongoose = require('mongoose');

const DanceSessionSchema = new mongoose.Schema({
    event_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Event', required: true },
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    started_at: { type: Date, required: true },
    ended_at: { type: Date },
    duration_sec: { type: Number },
    points: { type: Number, default: 0 }
});

module.exports = mongoose.model('DanceSession', DanceSessionSchema);
