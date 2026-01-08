const mongoose = require('mongoose');

const SoloSessionSchema = new mongoose.Schema({
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    started_at: { type: Date, required: true },
    ended_at: { type: Date },
    duration_seconds: { type: Number },
    points: { type: Number, default: 0 },
    avg_intensity: { type: Number },
    created_at: { type: Date, default: Date.now }
});

module.exports = mongoose.model('SoloSession', SoloSessionSchema);
