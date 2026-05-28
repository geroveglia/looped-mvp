const express = require('express');
const router = express.Router();
const SoloSession = require('../models/SoloSession');
const User = require('../models/User');
const auth = require('../middleware/auth');
const { addMonthlyPoints } = require('../utils/rankUtils');
const { updateStreak } = require('../utils/streakUtils');

// POST /solo/start
router.post('/start', auth, async (req, res) => {
    try {
        const startedAt = req.body.started_at ? new Date(req.body.started_at) : new Date();
        const session = new SoloSession({
            user_id: req.user._id,
            started_at: startedAt
        });
        await session.save();
        res.json({ session_id: session._id });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST /solo/:id/finish
router.post('/:id/finish', auth, async (req, res) => {
    try {
        const { points, duration_seconds, avg_intensity } = req.body;
        
        const user = await User.findById(req.user._id);
        if (!user) return res.status(404).json({ error: 'User not found' });

        // Rate Limiting Cooldown (anti-spam)
        const cooldownMs = 3000;
        if (user.last_score_submission && (Date.now() - user.last_score_submission.getTime() < cooldownMs)) {
            return res.status(429).json({ error: 'SUBMISSION_COOLDOWN_ACTIVE' });
        }
        user.last_score_submission = new Date();

        const session = await SoloSession.findById(req.params.id);
        
        if (!session) return res.status(404).json({ error: 'Session not found' });
        if (session.user_id.toString() !== req.user._id) return res.status(403).json({ error: 'Not your session' });
        
        if (session.ended_at) return res.json(session);

        session.ended_at = new Date();
        session.points = points;
        session.duration_seconds = duration_seconds;
        session.avg_intensity = avg_intensity;
        
        await session.save();

        // --- Streak Logic ---
        updateStreak(user);

        // --- Monthly Rank Points ---
        // Pass pre-loaded user document to save in a single consolidated database save!
        await addMonthlyPoints(User, user, points || 0);

        res.json(session);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /solo/history
router.get('/history', auth, async (req, res) => {
    try {
        const sessions = await SoloSession.find({ user_id: req.user._id }).sort({ created_at: -1 });
        res.json(sessions);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
