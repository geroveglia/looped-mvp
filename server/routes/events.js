const express = require('express');
const mongoose = require('mongoose'); // ObjectId y aggregations
const router = express.Router();
const Event = require('../models/Event');
const EventMember = require('../models/EventMember');
const DanceSession = require('../models/DanceSession');
const auth = require('../middleware/auth');
const { storeImage } = require('../utils/mediaStorage');
const { getEventStandings } = require('../utils/leaderboardCache');
const { positionOf } = require('../utils/leaderboardStandings');
const { eventAccess, viewEvent } = require('../utils/eventAccess');
const { summarizeSessions } = require('../utils/eventHistory');

const multer = require('multer');
const path = require('path');
const crypto = require('crypto');

// Configure Multer
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'uploads/');
    },
    filename: (req, file, cb) => {
        // Random suffix makes public URLs unguessable (uploads are served without auth)
        const rand = crypto.randomBytes(12).toString('hex');
        cb(null, 'event-' + rand + path.extname(file.originalname).toLowerCase());
    }
});
const upload = multer({ 
    storage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
    fileFilter: (req, file, cb) => {
        const allowedTypes = /jpeg|jpg|png|gif|webp/;
        const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
        const mimetype = allowedTypes.test(file.mimetype) || file.mimetype === 'application/octet-stream' || !file.mimetype;
        if (extname && mimetype) {
            cb(null, true);
        } else {
            cb(new Error('Only images (jpeg, jpg, png, gif, webp) are allowed!'));
        }
    }
});

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

        const finalVisibility = visibility === 'private' ? 'private' : 'public';

        // Validation — private events are invite-only, so location is optional
        if (!name || !starts_at || !genre) {
            return res.status(400).json({ error: 'Missing required fields' });
        }
        if (finalVisibility === 'public' && (!address || !city || !country)) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        // Validate Date (Must be future, with a small grace period to absorb
        // request latency / clock skew between client and server)
        const eventDate = new Date(starts_at);
        // Más ancho que el chequeo del cliente (5 min) para que un evento
        // válido al apretar "Crear" no se caiga por la latencia del request.
        const GRACE_PERIOD_MS = 15 * 60 * 1000;
        if (isNaN(eventDate.getTime()) || eventDate < new Date(Date.now() - GRACE_PERIOD_MS)) {
             return res.status(400).json({ error: 'Invalid or past date' });
        }

        // Validate Genre
        const validGenres = ['techno', 'house', 'reggaeton', 'trance', 'pop', 'hiphop', 'other'];
        if (!validGenres.includes(genre)) {
            return res.status(400).json({ error: 'Invalid genre' });
        }

        let invite_code = null;

        // Logic for private events
        if (finalVisibility === 'private') {
            // 6-char code from an unambiguous alphabet (no I/O/0/1), unique across events
            const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
            do {
                invite_code = Array.from(crypto.randomBytes(6), b => alphabet[b % alphabet.length]).join('');
            } while (await Event.exists({ invite_code }));
        }

        // Determine Icon/Image
        // If file uploaded, use its URL (Cloudinary when configured, local
        // /uploads otherwise). Else use provided iconText or default emoji.
        let iconValue = iconText || '🎵';
        if (req.file) {
            iconValue = await storeImage(req.file, 'events');
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
        // El _id del JWT es un string y aggregate() no castea: sin esto,
        // is_participating siempre da false y my_score siempre 0.
        const userId = new mongoose.Types.ObjectId(req.user._id);
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const skip = (page - 1) * limit;

        const events = await Event.aggregate([
            { 
                $match: { 
                    status: { $in: ['active', 'waiting'] },
                    visibility: 'public'
                } 
            },
            // Lookup participants count (people who left no longer count)
            {
                $lookup: {
                    from: 'eventmembers',
                    let: { event_id: '$_id' },
                    pipeline: [
                        { $match: { $expr: { $and: [
                            { $eq: ['$event_id', '$event_id'] },
                            { $eq: [{ $ifNull: ['$left_at', null] }, null] }
                        ] } } },
                        { $project: { user_id: 1 } }
                    ],
                    as: 'members'
                }
            },
            // Lookup active dancers (watching)
            {
                $lookup: {
                    from: 'dancesessions',
                    let: { event_id: '$_id' },
                    pipeline: [
                        { $match: { $expr: { $and: [{ $eq: ['$event_id', '$$event_id'] }, { $eq: ['$ended_at', null] }] } } },
                        {
                            $lookup: {
                                from: 'users',
                                localField: 'user_id',
                                foreignField: '_id',
                                as: 'userInfo'
                            }
                        },
                        { $unwind: '$userInfo' },
                        { $project: { avatar_url: '$userInfo.avatar_url' } }
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
                $addFields: {
                    active_dancers_avatars: {
                        $slice: ['$active_sessions.avatar_url', 3]
                    }
                }
            },
            {
                $project: {
                    members: 0,
                    all_sessions: 0,
                    leaderboard_pre: 0,
                    my_score: 0,
                    is_participating: 0
                }
            },
            {
                $project: {
                    active_sessions: 0
                }
            },
            { $sort: { created_at: -1 } },
            { $skip: skip },
            { $limit: limit }
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
        
        const wasWaiting = event.status === 'waiting';

        // Update
        event.status = status;
        await event.save();

        // Host started the party manually → notify members (no-op without Firebase)
        if (wasWaiting && status === 'active') {
            const { notifyEventStarted } = require('../utils/backgroundJobs');
            notifyEventStarted(event);
        }

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
        // ObjectId real: aggregate() no castea el string del JWT (ver GET /).
        const userId = new mongoose.Types.ObjectId(req.user._id);
        // Sin filtrar por left_at: esta lista es el historial del bailarín, y
        // una fiesta a la que fue sigue siendo una fiesta a la que fue aunque
        // después se haya ido. Cada evento viaja marcado con su left_at.
        const memberships = await EventMember.find({ user_id: userId });
        
        const eventIds = memberships.map(m => m.event_id);
        
        const events = await Event.aggregate([
            { $match: { _id: { $in: eventIds } } },
            // Participants count (people who left no longer count)
            {
                $lookup: {
                    from: 'eventmembers',
                    let: { event_id: '$_id' },
                    pipeline: [
                        { $match: { $expr: { $and: [
                            { $eq: ['$event_id', '$event_id'] },
                            { $eq: [{ $ifNull: ['$left_at', null] }, null] }
                        ] } } },
                        { $project: { _id: 1 } }
                    ],
                    as: 'members'
                }
            },
            // Active dancers
            {
                $lookup: {
                    from: 'dancesessions',
                    let: { event_id: '$_id' },
                    pipeline: [
                        { $match: { $expr: { $and: [{ $eq: ['$event_id', '$$event_id'] }, { $eq: ['$ended_at', null] }] } } },
                        {
                            $lookup: {
                                from: 'users',
                                localField: 'user_id',
                                foreignField: '_id',
                                as: 'userInfo'
                            }
                        },
                        { $unwind: '$userInfo' },
                        { $project: { avatar_url: '$userInfo.avatar_url' } }
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
                                $cond: [{ $eq: ['$this.user_id', userId] }, '$this.points', '$value']
                            }
                        }
                    },
                    my_sessions: {
                        $filter: {
                            input: '$all_sessions',
                            as: 's',
                            cond: { $eq: ['$s.user_id', userId] }
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
                                            cond: { $gt: ['$item.points', '$my_score'] }
                                        }
                                    }
                                },
                                1
                            ]
                        },
                        points: '$my_score',
                        // Lo justo para la tarjeta del historial. El desglose
                        // por sesión sale de GET /:id/my-stats, que además sabe
                        // medir una sesión abierta (sin duration_sec todavía).
                        sessions_count: { $size: '$my_sessions' },
                        dance_seconds: {
                            $sum: {
                                $map: {
                                    input: '$my_sessions',
                                    as: 's',
                                    in: { $ifNull: ['$s.duration_sec', 0] }
                                }
                            }
                        }
                    }
                }
            },
            {
                $addFields: {
                    active_dancers_avatars: {
                        $slice: ['$active_sessions.avatar_url', 3]
                    }
                }
            },
            {
                $project: {
                    members: 0,
                    all_sessions: 0,
                    my_sessions: 0,
                    leaderboard_pre: 0,
                    my_score: 0
                }
            },
            {
                $project: {
                    active_sessions: 0
                }
            },
            { $sort: { created_at: -1 } }
        ]);
        
        const eventsWithRole = events.map(event => {
            const membership = memberships.find(m => 
                m.event_id.toString() === event._id.toString()
            );
            const access = eventAccess(event, { membership, userId: req.user._id });
            return {
                ...viewEvent(event, access),
                my_role: membership?.role || 'member',
                joined_at: membership?.joined_at || null,
                left_at: membership?.left_at || null,
                // Bandera explícita para la UI: sigue en el historial, pero ya
                // no es "tu" fiesta en curso.
                i_left: Boolean(membership?.left_at)
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

        // Ya ser miembro no es un error: si alguien te reenvía el código de
        // una fiesta en la que ya estás (o sos el host), lo esperable es
        // entrar, no comerte un cartel rojo. Devolvemos el evento igual para
        // que la app navegue adentro.
        if (existing) {
            if (existing.left_at) {
                await EventMember.updateOne(
                    { _id: existing._id },
                    { $unset: { left_at: '' } }
                );
                return res.json({ message: 'Joined event', rejoined: true, event });
            }
            return res.json({
                message: 'Ya sos parte de este evento',
                already_member: true,
                event,
            });
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

        // Una fiesta privada es privada también para quien adivine el id: se
        // abre para el host y para quien alguna vez entró (aunque después se
        // haya ido, porque es parte de su historial). El invite_code sólo viaja
        // a quien sigue adentro — ver utils/eventAccess.
        const membership = await EventMember.findOne({
            event_id: event._id,
            user_id: req.user._id
        });
        const access = eventAccess(event, { membership, userId: req.user._id });
        if (!access.allowed) {
            return res.status(403).json({ error: 'NOT_A_MEMBER' });
        }

        res.json({
            ...viewEvent(event, access),
            my_role: membership?.role || null,
            joined_at: membership?.joined_at || null,
            left_at: membership?.left_at || null,
            i_left: Boolean(membership?.left_at)
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /events/:id/my-stats — lo que hizo el bailarín en esta fiesta.
// Una fiesta se baila en varias tandas (la app se abre y se cierra), así que
// "mis stats" es la suma de las sesiones más el puesto final en la tabla.
router.get('/:id/my-stats', auth, async (req, res) => {
    try {
        const event = await Event.findById(req.params.id);
        if (!event) return res.status(404).json({ error: 'Event not found' });

        const membership = await EventMember.findOne({
            event_id: event._id,
            user_id: req.user._id
        });
        const access = eventAccess(event, { membership, userId: req.user._id });
        if (!access.allowed) {
            return res.status(403).json({ error: 'NOT_A_MEMBER' });
        }

        const sessions = await DanceSession.find({
            event_id: event._id,
            user_id: req.user._id
        }).sort('started_at');

        const standings = await getEventStandings(String(event._id));
        const position = positionOf(standings, req.user._id);

        res.json({
            event_id: String(event._id),
            event_name: event.name,
            event_status: event.status,
            joined_at: membership?.joined_at || null,
            left_at: membership?.left_at || null,
            // El puesto de la tabla manda sobre la suma local: es el mismo
            // cálculo que ve el resto del ranking.
            rank: position.rank,
            total_dancers: standings.ranks.size,
            summary: summarizeSessions(sessions),
            sessions: sessions.map(s => ({
                _id: s._id,
                started_at: s.started_at,
                ended_at: s.ended_at,
                duration_sec: s.duration_sec,
                points: s.points || 0
            }))
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /events/:id/analytics — Premium Organizer Live Analytics
router.get('/:id/analytics', auth, async (req, res) => {
    try {
        const eventId = req.params.id;
        const event = await Event.findById(eventId);
        
        if (!event) return res.status(404).json({ error: 'Event not found' });
        
        // Host permission validation
        if (event.host_user_id.toString() !== req.user._id.toString()) {
            return res.status(403).json({ error: 'Access denied: Only the host can view analytics' });
        }

        const ObjectId = mongoose.Types.ObjectId;
        const eventObjId = new ObjectId(eventId);

        // 1. Total & Active Dancers
        const activeSessions = await DanceSession.find({ event_id: eventObjId, ended_at: null }).populate('user_id', 'username avatar_url level');
        const activeCount = activeSessions.length;
        
        const allSessions = await DanceSession.find({ event_id: eventObjId });
        const uniqueDancers = new Set(allSessions.map(s => s.user_id.toString()));
        const totalDancersCount = uniqueDancers.size;

        // 2. Sum of points and aggregate stats
        let totalPoints = 0;
        let suspiciousCount = 0;
        let totalActiveIntensity = 0;
        let activeIntensityCount = 0;
        
        allSessions.forEach(s => {
            totalPoints += s.points || 0;
            if (s.is_suspicious) suspiciousCount++;
        });

        activeSessions.forEach(s => {
            if (s.motion_stats && s.motion_stats instanceof Map && s.motion_stats.get('avg_intensity')) {
                totalActiveIntensity += parseFloat(s.motion_stats.get('avg_intensity'));
                activeIntensityCount++;
            } else if (s.motion_stats && s.motion_stats.avg_intensity) {
                totalActiveIntensity += parseFloat(s.motion_stats.avg_intensity);
                activeIntensityCount++;
            }
        });

        const avgActiveIntensity = activeIntensityCount > 0 ? (totalActiveIntensity / activeIntensityCount) : 0.0;

        // 3. Flagged Suspicious sessions
        const flaggedSessions = await DanceSession.find({ 
            event_id: eventObjId, 
            is_suspicious: true 
        }).populate('user_id', 'username avatar_url');

        res.json({
            event_id: eventId,
            name: event.name,
            status: event.status,
            goal_steps: event.goal_steps,
            total_dancers: totalDancersCount,
            active_dancers: activeCount,
            total_points: totalPoints,
            avg_intensity: parseFloat(avgActiveIntensity.toFixed(1)),
            suspicious_count: suspiciousCount,
            flagged: flaggedSessions.map(f => ({
                session_id: f._id,
                username: f.user_id?.username || 'Unknown',
                avatar_url: f.user_id?.avatar_url || '',
                points: f.points,
                suspicion_score: f.suspicion_score,
                ended: !!f.ended_at
            })),
            active_list: activeSessions.map(s => {
                let intensityVal = 0;
                if (s.motion_stats && s.motion_stats instanceof Map) {
                    intensityVal = s.motion_stats.get('avg_intensity') || 0;
                } else if (s.motion_stats) {
                    intensityVal = s.motion_stats.avg_intensity || 0;
                }
                return {
                    user_id: s.user_id?._id,
                    username: s.user_id?.username || 'Dancer',
                    avatar_url: s.user_id?.avatar_url || '',
                    level: s.user_id?.level || 1,
                    points: s.points,
                    intensity: intensityVal
                };
            })
        });

    } catch (err) {
        console.error("Analytics Error:", err);
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
        // Anotarse antes de que arranque es el caso normal: los eventos nacen
        // en 'waiting' y recién pasan a 'active' cuando llega starts_at.
        // Sólo los terminados se rechazan.
        if (event.status === 'ended') return res.status(400).json({ error: 'Event ended' });

        // Check if already member
        const existing = await EventMember.findOne({ event_id, user_id: req.user._id });
        if (existing) {
            // Coming back to a party they left: the row is still there (it is
            // their history), so revive it instead of tripping the unique index.
            if (existing.left_at) {
                await EventMember.updateOne(
                    { _id: existing._id },
                    { $unset: { left_at: '' } }
                );
                return res.json({ message: 'Joined event', rejoined: true });
            }
            return res.status(400).json({ error: 'Already joined' });
        }

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

        // 1. Stamp the membership instead of deleting it (idempotent).
        // Deleting it erased the party from the dancer's history along with
        // their place in it, even though their sessions and points survived.
        await EventMember.updateOne(
            { event_id: eventId, user_id: userId, left_at: null },
            { $set: { left_at: new Date() } }
        );

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

        // La tabla de una fiesta privada es tan privada como la fiesta.
        if (event.visibility === 'private') {
            const membership = await EventMember.findOne({ event_id: event._id, user_id: userId });
            const access = eventAccess(event, { membership, userId });
            if (!access.allowed) return res.status(403).json({ error: 'NOT_A_MEMBER' });
        }

        // 2. The table is identical for everyone at the event, so it is built
        // once per event and shared for a few seconds — see utils/leaderboardCache.
        // Only my_position below is specific to whoever is asking.
        // We only show people who have POINTS (danced). 0-point users are implicit at bottom?
        // For MVP, showing active dancers is better UX than showing empty list.
        const standings = await getEventStandings(eventId);

        res.json({
            event_id: eventId,
            // When the shared table was computed, not when this reply was sent:
            // that is the age the dancer's "updated Xs ago" should reflect.
            updated_at: new Date(standings.computedAt).toISOString(),
            leaderboard: standings.board,
            my_position: positionOf(standings, userId)
        });

    } catch (err) {
        console.error("Leaderboard error:", err);
        res.status(500).json({ error: err.message });
    }
});
module.exports = router;
