const mongoose = require('mongoose');

// User report (store UGC requirement). Reviewed manually for now;
// an admin dashboard can consume this collection later.
const ReportSchema = new mongoose.Schema({
    reporter: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    reported: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    reason: {
        type: String,
        enum: ['spam', 'abuse', 'cheating', 'inappropriate', 'other'],
        default: 'other'
    },
    details: { type: String, maxlength: 500 },
    created_at: { type: Date, default: Date.now }
});

ReportSchema.index({ reported: 1, created_at: -1 });

module.exports = mongoose.model('Report', ReportSchema);
