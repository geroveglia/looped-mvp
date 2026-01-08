const express = require('express');
const router = express.Router();
const Event = require('../models/Event');
const EventMember = require('../models/EventMember');
const DanceSession = require('../models/DanceSession');
const auth = require('../middleware/auth');

const multer = require('multer');
const path = require('path');

// Configure Multer
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'uploads/');
    },
    filename: (req, file, cb) => {
        cb(null, 'event-' + Date.now() + path.extname(file.originalname));
    }
});
const upload = multer({ storage });

// Create Event
router.post('/', [auth, upload.single('image')], async (req, res) => {
    try {
        const { 
            name, 
            starts_at, 
            ends_at, 
            genre, 
            venue_name, 
            address, 
            city, 
            country, 
            visibility, 
            is_paid_public,
            icon: iconText // If user sends emoji text
        } = req.body;

        // Validation
        if (!name || !starts_at || !genre || !address || !city || !country) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        // Validate Date (Must be future)
        const eventDate = new Date(starts_at);
        if (isNaN(eventDate.getTime()) || eventDate < new Date()) {
             return res.status(400).json({ error: 'Invalid or past date' });
        }

        // Validate Genre
        const validGenres = ['techno', 'house', 'reggaeton', 'trance', 'pop', 'hiphop', 'other'];
        if (!validGenres.includes(genre)) {
            return res.status(400).json({ error: 'Invalid genre' });
        }

        let invite_code = null;
        let finalVisibility = visibility || 'public';

        // Logic for private events
        if (finalVisibility === 'private') {
            // Generate 6-char code
            invite_code = Math.random().toString(36).substring(2, 8).toUpperCase();
        }

        // Determine Icon/Image
        // If file uploaded, use path. Else use provided iconText or default.
        let iconValue = iconText || '🎵';
        if (req.file) {
            // Store relative path. 
            // NOTE: In production, use full URL or ensure client knows base URL.
            // For MVP, we'll store '/uploads/filename'
            iconValue = `/uploads/${req.file.filename}`;
        }

        const newEvent = new Event({
            name,
            host_user_id: req.user._id,
            starts_at: eventDate,
            ends_at: ends_at ? new Date(ends_at) : null,
            genre,
            venue_name,
            address,
            city,
            country,
            visibility: finalVisibility,
            invite_code,
            is_paid_public: is_paid_public === 'true' || is_paid_public === true, // Handle string 'true' from multipart
            icon: iconValue,
            status: 'waiting'
        });

        const savedEvent = await newEvent.save();
        
        // Host automatically joins with role 'host'
        await new EventMember({
            event_id: savedEvent._id,
            user_id: req.user._id,
            role: 'host'
        }).save();

        res.json(savedEvent);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// List Events (Active or Waiting, public)
router.get('/', auth, async (req, res) => {
    try {
        const events = await Event.find({ 
            status: { $in: ['active', 'waiting'] },
            $or: [
                { visibility: 'public' },
                { is_public: true } 
            ]
        }).sort('-created_at');
        res.json(events);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Update Event Status
router.patch('/:id/status', auth, async (req, res) => {
    try {
        const { status } = req.body;
        const event = await Event.findById(req.params.id);
        
        if (!event) return res.status(404).json({ error: 'Event not found' });
        
        // Check host permission
        if (event.host_user_id.toString() !== req.user._id.toString()) {
             return res.status(403).json({ error: 'Only host can change status' });
        }

        // Validate status
        if (!['waiting', 'active', 'ended'].includes(status)) {
            return res.status(400).json({ error: 'Invalid status' });
        }

        // State machine checks
        if (event.status === 'ended') {
            return res.status(400).json({ error: 'Cannot change status of ended event' });
        }
        
        // Update
        event.status = status;
        await event.save();

        res.json({
            event_id: event._id,
            status: event.status,
            updated_at: new Date()
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Get My Events (where user is member/host) - MUST BE BEFORE /:id
router.get('/my', auth, async (req, res) => {
    try {
        const memberships = await EventMember.find({ 
            user_id: req.user._id,
            left_at: null
        });
        
        const eventIds = memberships.map(m => m.event_id);
        
        const events = await Event.find({ 
            _id: { $in: eventIds }
        }).sort('-created_at');
        
        const eventsWithRole = events.map(event => {
            const membership = memberships.find(m => 
                m.event_id.toString() === event._id.toString()
            );
            return {
                ...event.toObject(),
                my_role: membership?.role || 'member'
            };
        });
        
        res.json(eventsWithRole);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Join Private Event by Code - MUST BE BEFORE /:id
router.post('/join-by-code', auth, async (req, res) => {
    try {
        const { invite_code } = req.body;
        
        if (!invite_code) {
            return res.status(400).json({ error: 'Invite code required' });
        }
        
        const event = await Event.findOne({ 
            invite_code: invite_code.toUpperCase(),
            visibility: 'private'
        });
        
        if (!event) {
            return res.status(404).json({ error: 'Invalid invite code' });
        }
        
        if (event.status === 'ended') {
            return res.status(400).json({ error: 'Event has ended' });
        }
        
        const existing = await EventMember.findOne({ 
            event_id: event._id, 
            user_id: req.user._id 
        });
        
        if (existing) {
            return res.status(400).json({ error: 'Already joined this event' });
        }
        
        const member = new EventMember({
            event_id: event._id,
            user_id: req.user._id,
            role: 'member'
        });
        await member.save();
        
        res.json({ 
            message: 'Joined event',
            event: event
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Get Single Event
router.get('/:id', auth, async (req, res) => {
    try {
        const event = await Event.findById(req.params.id);
        if (!event) return res.status(404).json({ error: 'Event not found' });
        res.json(event);
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

// Leave Event
router.post('/:id/leave', auth, async (req, res) => {
    try {
        const eventId = req.params.id;
        const userId = req.user._id;

        // 1. Remove from EventMember (idempotent)
        await EventMember.deleteOne({ event_id: eventId, user_id: userId });

        // 2. Find any active session (no ended_at) and close it
        const activeSession = await DanceSession.findOne({
            event_id: eventId,
            user_id: userId,
            ended_at: null
        });

        if (activeSession) {
            activeSession.ended_at = new Date();
            activeSession.points = activeSession.points || 0; // Preserve any existing points
            await activeSession.save();
        }

        res.json({ left: true, event_id: eventId });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Leaderboard
router.get('/:id/leaderboard', auth, async (req, res) => {
    try {
        const eventId = req.params.id;
        const userId = req.user._id;

        // 1. Get Event to ensure it exists
        const event = await Event.findById(eventId);
        if (!event) return res.status(404).json({ error: 'Event not found' });

        const ObjectId = mongoose.Types.ObjectId;
        const eventObjId = new ObjectId(eventId);
        const userObjId = new ObjectId(userId);

        // 2. Get my total points
        const myStats = await DanceSession.aggregate([
            { $match: { event_id: eventObjId, user_id: userObjId } },
            { $group: { _id: '$user_id', total: { $sum: '$points' } } }
        ]);
        const myPoints = myStats.length > 0 ? myStats[0].total : 0;

        // 3. Get Leaderboard List (Top 50)
        // We only show people who have POINTS (danced). 0-point users are implicit at bottom?
        // Prompt says "Lista de usuarios participantes". 
        // For MVP, showing active dancers is better UX than showing empty list.
        const leaderboardList = await DanceSession.aggregate([
            { $match: { event_id: eventObjId } },
            { $group: { _id: '$user_id', points: { $sum: '$points' } } },
            { $sort: { points: -1 } },
            { $limit: 50 },
            { $lookup: { from: 'users', localField: '_id', foreignField: '_id', as: 'u' } },
            { $unwind: '$u' },
            { $project: { 
                user_id: '$_id', 
                username: '$u.username', 
                avatar_url: '$u.avatar_url', 
                points: 1,
                _id: 0 
            }}
        ]);

        // 4. Calculate My Rank
        // Rank = count of users with MORE points than me + 1
        // (If I have 0, I am tied with others, but let's say rank is after all positives)
        // This aggregation counts distinct users with totalPoints > myPoints
        const rankStats = await DanceSession.aggregate([
            { $match: { event_id: eventObjId } },
            { $group: { _id: '$user_id', total: { $sum: '$points' } } },
            { $match: { total: { $gt: myPoints } } },
            { $count: "better_than_me" }
        ]);
        const betterThanMe = rankStats.length > 0 ? rankStats[0].better_than_me : 0;
        const myRank = betterThanMe + 1;

        res.json({
            event_id: eventId,
            updated_at: new Date().toISOString(),
            leaderboard: leaderboardList,
            my_position: {
                rank: myRank,
                points: myPoints
            }
        });

    } catch (err) {
        console.error("Leaderboard error:", err);
        res.status(500).json({ error: err.message });
    }
});
const mongoose = require('mongoose'); // Needed for ObjectId and aggregation

module.exports = router;
