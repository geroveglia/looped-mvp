const express = require('express');
const router = express.Router();
const DanceSession = require('../models/DanceSession');
const auth = require('../middleware/auth');

// Start Session
router.post('/start', auth, async (req, res) => {
    try {
        const { event_id } = req.body;
        // Logic: just create a session record? Or simple start marker? 
        // For MVP, maybe we create the record when we stop? 
        // Or create it now with "started_at" and null "ended_at".
        const session = new DanceSession({
            event_id,
            user_id: req.user._id,
            started_at: new Date()
        });
        await session.save();
        res.json({ session_id: session._id });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Stop Session (Update with points)
router.post('/stop', auth, async (req, res) => {
    try {
        const { session_id, points, duration_sec } = req.body;
        
        const session = await DanceSession.findById(session_id);
        if (!session) return res.status(404).json({ error: 'Session not found' });
        if (session.user_id.toString() !== req.user._id) return res.status(403).json({ error: 'Not your session' });

        session.ended_at = new Date();
        session.points = points;
        session.duration_sec = duration_sec;
        await session.save();

        res.json(session);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
