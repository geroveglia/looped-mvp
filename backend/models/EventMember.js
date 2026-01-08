const mongoose = require('mongoose');

const EventMemberSchema = new mongoose.Schema({
    event_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Event', required: true },
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    joined_at: { type: Date, default: Date.now }
});

// Prevent double joining
EventMemberSchema.index({ event_id: 1, user_id: 1 }, { unique: true });

module.exports = mongoose.model('EventMember', EventMemberSchema);
