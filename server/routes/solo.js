const express = require('express');
const router = express.Router();
const SoloSession = require('../models/SoloSession');
const User = require('../models/User');
const auth = require('../middleware/auth');
const { addMonthlyPoints } = require('../utils/rankUtils');

// POST /solo/start
router.post('/start', auth, async (req, res) => {
    try {
        const session = new SoloSession({
            user_id: req.user._id,
            started_at: new Date()
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
        const session = await SoloSession.findById(req.params.id);
        
        if (!session) return res.status(404).json({ error: 'Session not found' });
        if (session.user_id.toString() !== req.user._id) return res.status(403).json({ error: 'Not your session' });
        
        if (session.ended_at) return res.json(session);

        session.ended_at = new Date();
        session.points = points;
        session.duration_seconds = duration_seconds;
        session.avg_intensity = avg_intensity;
        
        await session.save();

        // --- Monthly Rank Points ---
        await addMonthlyPoints(User, req.user._id, points || 0);

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
