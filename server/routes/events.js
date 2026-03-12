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
            organizer,
            goal_steps,
            icon: iconText, // If user sends emoji text
            latitude,
            longitude,
            radius
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

        // Location Point
        let location = { type: 'Point', coordinates: [0, 0] };
        if (latitude && longitude) {
            location.coordinates = [parseFloat(longitude), parseFloat(latitude)];
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
            location,
            geofence_radius: radius ? parseInt(radius) : 500,
            visibility: finalVisibility,
            invite_code,
            is_paid_public: is_paid_public === 'true' || is_paid_public === true, // Handle string 'true' from multipart
            organizer: organizer || 'Looped',
            goal_steps: goal_steps ? parseInt(goal_steps) : 10000,
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
        const userId = req.user._id;

        const events = await Event.aggregate([
            { 
                $match: { 
                    status: { $in: ['active', 'waiting'] },
                    visibility: 'public'
                } 
            },
            // Lookup participants count
            {
                $lookup: {
                    from: 'eventmembers',
                    localField: '_id',
                    foreignField: 'event_id',
                    as: 'members'
                }
            },
            // Lookup active dancers (watching)
            {
                $lookup: {
                    from: 'dancesessions',
                    let: { event_id: '$_id' },
                    pipeline: [
                        { $match: { $expr: { $and: [{ $eq: ['$event_id', '$$event_id'] }, { $eq: ['$ended_at', null] }] } } }
                    ],
                    as: 'active_sessions'
                }
            },
            // Lookup ALL user points for this event to calculate rank
            {
                $lookup: {
                    from: 'dancesessions',
                    localField: '_id',
                    foreignField: 'event_id',
                    as: 'all_sessions'
                }
            },
            {
                $addFields: {
                    participants_count: { $size: '$members' },
                    active_dancers_count: { $size: '$active_sessions' },
                    // Calculate leaderboard in memory for this event to find rank
                    leaderboard_pre: {
                        $reduce: {
                            input: '$all_sessions',
                            initialValue: [],
                            in: {
                                $let: {
                                    vars: {
                                        idx: { $indexOfArray: ['$$value.user_id', '$$this.user_id'] }
                                    },
                                    in: {
                                        $cond: [
                                            { $eq: ['$$idx', -1] },
                                            { $concatArrays: ['$$value', [{ user_id: '$$this.user_id', points: '$$this.points' }]] },
                                            {
                                                $map: {
                                                    input: '$$value',
                                                    as: 'v',
                                                    in: {
                                                        $cond: [
                                                            { $eq: ['$$v.user_id', '$$this.user_id'] },
                                                            { user_id: '$$v.user_id', points: { $add: ['$$v.points', '$$this.points'] } },
                                                            '$$v'
                                                        ]
                                                    }
                                                }
                                            }
                                        ]
                                    }
                                }
                            }
                        }
                    }
                }
            },
            {
                $addFields: {
                    my_score: {
                        $reduce: {
                            input: '$leaderboard_pre',
                            initialValue: 0,
                            in: {
                                $cond: [{ $eq: ['$$this.user_id', userId] }, '$$this.points', '$$value']
                            }
                        }
                    },
                    is_participating: {
                        $in: [userId, '$members.user_id']
                    }
                }
            },
            {
                $addFields: {
                    user_stats: {
                        rank: {
                            $cond: [
                                '$is_participating',
                                {
                                    $add: [
                                        {
                                            $size: {
                                                $filter: {
                                                    input: '$leaderboard_pre',
                                                    as: 'item',
                                                    cond: { $gt: ['$$item.points', '$my_score'] }
                                                }
                                            }
                                        },
                                        1
                                    ]
                                },
                                null
                            ]
                        },
                        points: '$my_score'
                    }
                }
            },
            {
                $project: {
                    members: 0,
                    active_sessions: 0,
                    all_sessions: 0,
                    leaderboard_pre: 0,
                    my_score: 0,
                    is_participating: 0
                }
            },
            { $sort: { created_at: -1 } }
        ]);
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
        const userId = req.user._id;
        const memberships = await EventMember.find({ 
            user_id: userId,
            left_at: null
        });
        
        const eventIds = memberships.map(m => m.event_id);
        
        const events = await Event.aggregate([
            { $match: { _id: { $in: eventIds } } },
            // Participants count
            {
                $lookup: {
                    from: 'eventmembers',
                    localField: '_id',
                    foreignField: 'event_id',
                    as: 'members'
                }
            },
            // Active dancers
            {
                $lookup: {
                    from: 'dancesessions',
                    let: { event_id: '$_id' },
                    pipeline: [
                        { $match: { $expr: { $and: [{ $eq: ['$event_id', '$$event_id'] }, { $eq: ['$ended_at', null] }] } } }
                    ],
                    as: 'active_sessions'
                }
            },
            // All sessions for rank
            {
                $lookup: {
                    from: 'dancesessions',
                    localField: '_id',
                    foreignField: 'event_id',
                    as: 'all_sessions'
                }
            },
            {
                $addFields: {
                    participants_count: { $size: '$members' },
                    active_dancers_count: { $size: '$active_sessions' },
                    leaderboard_pre: {
                        $reduce: {
                            input: '$all_sessions',
                            initialValue: [],
                            in: {
                                $let: {
                                    vars: {
                                        idx: { $indexOfArray: ['$$value.user_id', '$$this.user_id'] }
                                    },
                                    in: {
                                        $cond: [
                                            { $eq: ['$$idx', -1] },
                                            { $concatArrays: ['$$value', [{ user_id: '$$this.user_id', points: '$$this.points' }]] },
                                            {
                                                $map: {
                                                    input: '$$value',
                                                    as: 'v',
                                                    in: {
                                                        $cond: [
                                                            { $eq: ['$$v.user_id', '$$this.user_id'] },
                                                            { user_id: '$$v.user_id', points: { $add: ['$$v.points', '$$this.points'] } },
                                                            '$$v'
                                                        ]
                                                    }
                                                }
                                            }
                                        ]
                                    }
                                }
                            }
                        }
                    }
                }
            },
            {
                $addFields: {
                    my_score: {
                        $reduce: {
                            input: '$leaderboard_pre',
                            initialValue: 0,
                            in: {
                                $cond: [{ $eq: ['$$this.user_id', userId] }, '$$this.points', '$$value']
                            }
                        }
                    }
                }
            },
            {
                $addFields: {
                    user_stats: {
                        rank: {
                            $add: [
                                {
                                    $size: {
                                        $filter: {
                                            input: '$leaderboard_pre',
                                            as: 'item',
                                            cond: { $gt: ['$$item.points', '$my_score'] }
                                        }
                                    }
                                },
                                1
                            ]
                        },
                        points: '$my_score'
                    }
                }
            },
            {
                $project: {
                    members: 0,
                    active_sessions: 0,
                    all_sessions: 0,
                    leaderboard_pre: 0,
                    my_score: 0
                }
            },
            { $sort: { created_at: -1 } }
        ]);
        
        const eventsWithRole = events.map(event => {
            const membership = memberships.find(m => 
                m.event_id.toString() === event._id.toString()
            );
            return {
                ...event,
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
