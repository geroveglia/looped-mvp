const express = require('express');
const router = express.Router();
const SoloSession = require('../models/SoloSession');
const User = require('../models/User');
const auth = require('../middleware/auth');
const { addMonthlyPoints } = require('../utils/rankUtils');
const { updateStreak } = require('../utils/streakUtils');

// Max points per second a human can plausibly generate (client cap is 8/s).
const MAX_POINTS_PER_SEC = 8;
// Margin for client/server clock skew when capping durations.
const CLOCK_SKEW_SEC = 120;
// Oldest accepted client-supplied start (matches the app's 12h restore cutoff).
const MAX_SESSION_AGE_MS = 12 * 60 * 60 * 1000;

// POST /solo/start
router.post('/start', auth, async (req, res) => {
    try {
        // started_at is client-supplied for offline sync; clamp it so a forged
        // past timestamp can't inflate the temporal points cap at /finish.
        const now = new Date();
        let startedAt = req.body.started_at ? new Date(req.body.started_at) : now;
        if (isNaN(startedAt.getTime()) || startedAt > now) startedAt = now;
        const oldest = new Date(now.getTime() - MAX_SESSION_AGE_MS);
        if (startedAt < oldest) startedAt = oldest;

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

        // --- Server-side sanity validation ---
        // Solo points feed the GLOBAL monthly ranking, so they get the same
        // caps as event sessions: sane non-negative ints, duration bounded by
        // real elapsed time, points bounded by human-possible rate.
        let cleanPoints = Math.floor(Number(points));
        let cleanDuration = Math.floor(Number(duration_seconds));
        if (!Number.isFinite(cleanPoints) || cleanPoints < 0) cleanPoints = 0;
        if (!Number.isFinite(cleanDuration) || cleanDuration < 0) cleanDuration = 0;

        const elapsedSec = Math.max(0,
            Math.ceil((Date.now() - session.started_at.getTime()) / 1000)) + CLOCK_SKEW_SEC;
        if (cleanDuration > elapsedSec) cleanDuration = elapsedSec;

        const maxPoints = cleanDuration * MAX_POINTS_PER_SEC;
        if (cleanPoints > maxPoints) cleanPoints = maxPoints;

        let cleanIntensity = Number(avg_intensity);
        if (!Number.isFinite(cleanIntensity) || cleanIntensity < 0) cleanIntensity = 0;

        session.ended_at = new Date();
        session.points = cleanPoints;
        session.duration_seconds = cleanDuration;
        session.avg_intensity = cleanIntensity;

        await session.save();

        // --- Streak Logic ---
        updateStreak(user);

        // --- Monthly Rank Points ---
        // Pass pre-loaded user document to save in a single consolidated database save!
        await addMonthlyPoints(User, user, cleanPoints);

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
