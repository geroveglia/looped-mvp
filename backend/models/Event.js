const mongoose = require('mongoose');

const EventSchema = new mongoose.Schema({
    name: { type: String, required: true },
    host_user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    is_public: { type: Boolean, default: true },
    invite_code: { type: String },
    status: { type: String, enum: ['waiting', 'active', 'ended'], default: 'waiting' },
    created_at: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Event', EventSchema);
