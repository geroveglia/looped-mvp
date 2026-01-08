const express = require('express');
const router = express.Router();
const Event = require('../models/Event');
const EventMember = require('../models/EventMember');
const DanceSession = require('../models/DanceSession');
const auth = require('../middleware/auth');

// Create Event
router.post('/', auth, async (req, res) => {
    try {
        const { name, is_public, invite_code } = req.body;
        const newEvent = new Event({
            name,
            host_user_id: req.user._id,
            is_public: is_public !== undefined ? is_public : true,
            invite_code
        });
        const savedEvent = await newEvent.save();
        
        // Host automatically joins? Usually yes.
        await new EventMember({
            event_id: savedEvent._id,
            user_id: req.user._id
        }).save();

        res.json(savedEvent);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// List Events (All active public events)
router.get('/', auth, async (req, res) => {
    try {
        const events = await Event.find({ status: 'active', is_public: true }).sort('-created_at');
        res.json(events);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Join Event
router.post('/join', auth, async (req, res) => {
    try {
        const { event_id } = req.body;
        // Check if event exists
        const event = await Event.findById(event_id);
        if (!event) return res.status(404).json({ error: 'Event not found' });
        if (event.status !== 'active') return res.status(400).json({ error: 'Event ended' });

        // Check if already member
        const existing = await EventMember.findOne({ event_id, user_id: req.user._id });
        if (existing) return res.status(400).json({ error: 'Already joined' });

        const member = new EventMember({
            event_id,
            user_id: req.user._id
        });
        await member.save();
        res.json({ message: 'Joined event' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Leaderboard
router.get('/:id/leaderboard', auth, async (req, res) => {
    try {
        // Aggregate points per user for this event
        const leaderboard = await DanceSession.aggregate([
            { $match: { event_id: new mongoose.Types.ObjectId(req.params.id) } },
            { $group: { _id: '$user_id', totalPoints: { $sum: '$points' } } },
            { $sort: { totalPoints: -1 } },
            { $limit: 20 },
            { $lookup: { from: 'users', localField: '_id', foreignField: '_id', as: 'user' } },
            { $unwind: '$user' },
            { $project: { username: '$user.username', totalPoints: 1, avatar_url: '$user.avatar_url' } }
        ]);

        res.json(leaderboard);
    } catch (err) {
        // aggregate requires mongoose, import it
        console.error(err);
        res.status(500).json({ error: err.message });
    }
});
const mongoose = require('mongoose'); // Needed for ObjectId and aggregation

module.exports = router;
