const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
    email: { type: String, required: true, unique: true },
    password_hash: { type: String, required: true },
    username: { type: String, required: true },
    avatar_url: { type: String },
    level: { type: Number, default: 1 },
    xp: { type: Number, default: 0 },
    created_at: { type: Date, default: Date.now },

    // --- Rank System (Monthly) ---
    monthly_points: { type: Number, default: 0 },
    monthly_points_updated: { type: Date },
    rank: {
        type: String,
        enum: ['ghost', 'rookie', 'pistero', 'vip', 'immortal'],
        default: 'ghost'
    },

    // --- Badges (Permanent) ---
    badges: [{
        id: { type: String, required: true },
        name: { type: String, required: true },
        emoji: { type: String, required: true },
        earned_at: { type: Date, default: Date.now },
        description: { type: String }
    }],

    // --- Rank History ---
    rank_history: [{
        month: { type: String },
        rank: { type: String },
        points: { type: Number },
        badge_earned: { type: Boolean, default: false }
    }],

    // --- Hall of Fame ---
    hall_of_fame: { type: Boolean, default: false },
    bonus_multiplier: { type: Number, default: 1.0 }
});

module.exports = mongoose.model('User', UserSchema);
