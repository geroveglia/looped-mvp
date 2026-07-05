const mongoose = require('mongoose');

// User-level block (store UGC requirement): the blocker stops seeing the
// blocked user in search/feed and neither can send friend requests.
const BlockSchema = new mongoose.Schema({
    blocker: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    blocked: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    created_at: { type: Date, default: Date.now }
});

BlockSchema.index({ blocker: 1, blocked: 1 }, { unique: true });

module.exports = mongoose.model('Block', BlockSchema);
