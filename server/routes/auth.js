const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const auth = require('../middleware/auth');
const { OAuth2Client } = require('google-auth-library');
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// Google Login
router.post('/google', async (req, res) => {
    try {
        const { idToken, accessToken } = req.body;
        if (!idToken && !accessToken) return res.status(400).json({ error: 'idToken or accessToken required (DEBUG V2)' });

        let email, googleId, name, picture;

        if (idToken) {
            // Verify ID Token
            const ticket = await client.verifyIdToken({
                idToken,
                audience: process.env.GOOGLE_CLIENT_ID,
            });
            const payload = ticket.getPayload();
            email = payload.email;
            googleId = payload.sub;
            name = payload.name;
            picture = payload.picture;
        } else {
            // Verify Access Token (Fallback for Web)
            // Use axios or fetch to get user info from Google
            const axios = require('axios');
            const response = await axios.get(`https://www.googleapis.com/oauth2/v3/userinfo?access_token=${accessToken}`);
            email = response.data.email;
            googleId = response.data.sub;
            name = response.data.name;
            picture = response.data.picture;
        }

        if (!email) throw new Error("Could not retrieve email from Google");

        let user = await User.findOne({ email });

        if (!user) {
            const randomPass = await bcrypt.hash(Math.random().toString(36), 10);
            user = new User({
                email,
                username: (name ? name.split(' ')[0] : 'User') + Math.floor(Math.random() * 1000),
                password_hash: randomPass,
                avatar_url: picture
            });
            await user.save();
        }

        const token = jwt.sign({ _id: user._id }, process.env.JWT_SECRET);
        res.json({ token, user: { id: user._id, username: user.username, email: user.email } });

    } catch (err) {
        console.error("Google Auth Error:", err);
        res.status(400).json({ error: 'Auth failed: ' + (err.response?.data?.error_description || err.message) });
    }
});

// Register
router.post('/register', async (req, res) => {
    try {
        const { email, password, username } = req.body;
        
        // Simple validation
        if (!email || !password || !username) {
            return res.status(400).json({ error: 'All fields required' });
        }

        const existingUser = await User.findOne({ email });
        if (existingUser) return res.status(400).json({ error: 'Email already exists' });

        const salt = await bcrypt.genSalt(10);
        const password_hash = await bcrypt.hash(password, salt);

        const newUser = new User({
            email,
            password_hash,
            username
        });

        const savedUser = await newUser.save();
        res.json({ message: 'User registered', userId: savedUser._id });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Login
router.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        const user = await User.findOne({ email });
        if (!user) return res.status(400).json({ error: 'User not found' });

        const validPass = await bcrypt.compare(password, user.password_hash);
        if (!validPass) return res.status(400).json({ error: 'Invalid password' });

        const token = jwt.sign({ _id: user._id }, process.env.JWT_SECRET);
        res.json({ token, user: { id: user._id, username: user.username, email: user.email } });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Me
router.get('/me', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user._id).select('-password_hash');
        
        // Calculate Progress
        const level = user.level || 1;
        const xp = user.xp || 0;
        const xpToNext = 1000 * level; // Metric from prompt
        const progress = Math.min(1.0, Math.max(0.0, xp / xpToNext));

        res.json({
            user_id: user._id,
            username: user.username,
            avatar_url: user.avatar_url,
            level: level,
            xp: xp,
            xp_to_next: xpToNext,
            xp_progress: progress,
            email: user.email 
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

const multer = require('multer');
const path = require('path');

// Configure Multer for avatar uploads
const avatarStorage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'uploads/');
    },
    filename: (req, file, cb) => {
        cb(null, 'avatar-' + req.user._id + '-' + Date.now() + path.extname(file.originalname));
    }
});
const avatarUpload = multer({ storage: avatarStorage });

// Upload Avatar
router.post('/avatar', [auth, avatarUpload.single('avatar')], async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        const avatarUrl = `/uploads/${req.file.filename}`;
        
        await User.findByIdAndUpdate(req.user._id, { avatar_url: avatarUrl });
        
        res.json({ 
            message: 'Avatar updated',
            avatar_url: avatarUrl
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

const DanceSession = require('../models/DanceSession');
const SoloSession = require('../models/SoloSession');
const Event = require('../models/Event');

// GET /stats - Aggregate User Stats
router.get('/stats', auth, async (req, res) => {
    try {
        const userId = req.user._id;

        // 1. Fetch all sessions
        const danceSessions = await DanceSession.find({ user_id: userId }).populate('event_id');
        const soloSessions = await SoloSession.find({ user_id: userId });

        // 2. Initialize Accumulators
        let stats = {
            total_seconds: 0,
            total_points: 0,
            
            solo: { seconds: 0, points: 0 },
            private: { seconds: 0, points: 0 },
            public: { seconds: 0, points: 0 }
        };

        // 3. Process Solo Sessions
        soloSessions.forEach(session => {
            const sec = session.duration_seconds || 0;
            const pts = session.points || 0;
            
            stats.solo.seconds += sec;
            stats.solo.points += pts;
            
            stats.total_seconds += sec;
            stats.total_points += pts;
        });

        // 4. Process Event Sessions (Public/Private)
        danceSessions.forEach(session => {
            const sec = session.duration_sec || 0;
            const pts = session.points || 0;
            
            stats.total_seconds += sec;
            stats.total_points += pts;

            if (session.event_id && session.event_id.visibility === 'private') {
                stats.private.seconds += sec;
                stats.private.points += pts;
            } else {
                // Default to public if event missing (unlikely) or public
                stats.public.seconds += sec;
                stats.public.points += pts;
            }
        });

        // 5. Calculate Derived Metrics
        // Steps = points (1:1 mapping for MVP)
        // Distance: 0.7m per step => km
        // Calories: 0.04 kcal per step
        const totalSteps = stats.total_points;
        const totalKm = (totalSteps * 0.7) / 1000;
        const totalCalories = totalSteps * 0.04;

        res.json({
            ...stats,
            derived: {
                steps: totalSteps,
                km: parseFloat(totalKm.toFixed(2)),
                calories: Math.round(totalCalories)
            }
        });

    } catch (err) {
        console.error("Stats Error:", err);
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
