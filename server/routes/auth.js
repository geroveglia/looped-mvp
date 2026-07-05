const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const auth = require('../middleware/auth');
const { checkMonthReset, getRankMeta, getNextRankInfo } = require('../utils/rankUtils');
const { checkAndResetStreak } = require('../utils/streakUtils');
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

        const token = jwt.sign({ _id: user._id }, process.env.JWT_SECRET, { expiresIn: '7d' });
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

        const token = jwt.sign({ _id: user._id }, process.env.JWT_SECRET, { expiresIn: '7d' });
        res.json({ token, user: { id: user._id, username: user.username, email: user.email } });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Me
router.get('/me', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user._id).select('-password_hash');

        // Auto month-reset if needed
        const didReset = await checkMonthReset(user);
        if (didReset) await user.save();

        // Auto streak-reset if needed
        const didStreakReset = checkAndResetStreak(user);
        if (didStreakReset) await user.save();
        
        // Calculate Progress
        const level = user.level || 1;
        const xp = user.xp || 0;
        const xpToNext = 1000 * level;
        const progress = Math.min(1.0, Math.max(0.0, xp / xpToNext));

        // Rank data
        const rank = user.rank || 'ghost';
        const rankMeta = getRankMeta(rank);

        res.json({
            user_id: user._id,
            username: user.username,
            avatar_url: user.avatar_url,
            level: level,
            xp: xp,
            xp_to_next: xpToNext,
            xp_progress: progress,
            email: user.email,
            rank: rank,
            rank_meta: {
                name: rankMeta.name,
                emoji: rankMeta.emoji,
                color: rankMeta.color,
                description: rankMeta.description,
            },
            monthly_points: user.monthly_points || 0,
            badges: user.badges || [],
            streak: user.streak || 0,
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

const multer = require('multer');
const path = require('path');
const crypto = require('crypto');

// Configure Multer for avatar uploads
const avatarStorage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'uploads/');
    },
    filename: (req, file, cb) => {
        // Random suffix makes public URLs unguessable (uploads are served without auth)
        const rand = crypto.randomBytes(12).toString('hex');
        cb(null, 'avatar-' + rand + path.extname(file.originalname).toLowerCase());
    }
});
const avatarUpload = multer({ 
    storage: avatarStorage,
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

const { storeImage } = require('../utils/mediaStorage');

// Upload Avatar
router.post('/avatar', [auth, avatarUpload.single('avatar')], async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        // Cloudinary when configured (survives redeploys), local /uploads otherwise
        const avatarUrl = await storeImage(req.file, 'avatars');

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

        // 6. Build last-7-days activity map: { 'YYYY-MM-DD': totalSeconds }
        // Used by the profile Weekly Activity widget to show real data
        const sevenDaysAgo = new Date();
        sevenDaysAgo.setUTCDate(sevenDaysAgo.getUTCDate() - 6);
        sevenDaysAgo.setUTCHours(0, 0, 0, 0);

        const toDateKey = (date) => {
            const d = new Date(date);
            return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
        };

        // Initialize all 7 days with 0
        const weekly_sessions = {};
        for (let i = 0; i < 7; i++) {
            const d = new Date(sevenDaysAgo);
            d.setUTCDate(d.getUTCDate() + i);
            weekly_sessions[toDateKey(d)] = 0;
        }

        // Accumulate solo sessions in the last 7 days
        soloSessions.forEach(session => {
            const key = toDateKey(session.created_at || session.createdAt);
            if (key in weekly_sessions) {
                weekly_sessions[key] += session.duration_seconds || 0;
            }
        });

        // Accumulate event dance sessions in the last 7 days
        danceSessions.forEach(session => {
            const key = toDateKey(session.created_at || session.createdAt);
            if (key in weekly_sessions) {
                weekly_sessions[key] += session.duration_sec || 0;
            }
        });

        res.json({
            ...stats,
            derived: {
                steps: totalSteps,
                km: parseFloat(totalKm.toFixed(2)),
                calories: Math.round(totalCalories)
            },
            weekly_sessions
        });

    } catch (err) {
        console.error("Stats Error:", err);
        res.status(500).json({ error: err.message });
    }
});

// Register an FCM device token for push notifications.
// Idempotent ($addToSet); tokens of uninstalled apps are pruned on send.
router.put('/fcm-token', auth, async (req, res) => {
    try {
        const { token } = req.body;
        if (!token || typeof token !== 'string' || token.length > 4096) {
            return res.status(400).json({ error: 'token required' });
        }
        await User.findByIdAndUpdate(req.user._id, {
            $addToSet: { fcm_tokens: token }
        });
        res.json({ ok: true });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Update Profile
router.patch('/update', auth, async (req, res) => {
    try {
        const { username } = req.body;
        if (!username) return res.status(400).json({ error: 'Username is required' });
        
        const existing = await User.findOne({ username });
        if (existing && existing._id.toString() !== req.user._id.toString()) {
            return res.status(400).json({ error: 'Username already taken' });
        }

        const user = await User.findByIdAndUpdate(req.user._id, { username }, { new: true });
        res.json({ message: 'Profile updated', username: user.username });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Delete Account (Cascading deletion to prevent orphans)
router.delete('/delete-account', auth, async (req, res) => {
    try {
        const userId = req.user._id;
        
        const DanceSession = require('../models/DanceSession');
        const SoloSession = require('../models/SoloSession');
        const Event = require('../models/Event');
        const EventMember = require('../models/EventMember');
        const Friendship = require('../models/Friendship');

        // 1. Delete all dance and solo sessions
        await DanceSession.deleteMany({ user_id: userId });
        await SoloSession.deleteMany({ user_id: userId });

        // 2. Delete event memberships
        await EventMember.deleteMany({ user_id: userId });

        // 3. Delete friendships and friend requests
        await Friendship.deleteMany({
            $or: [{ requester: userId }, { recipient: userId }]
        });

        // 4. Cascade delete hosted events and their member lists
        const hostedEvents = await Event.find({ host_user_id: userId });
        const hostedEventIds = hostedEvents.map(e => e._id);
        
        await EventMember.deleteMany({ event_id: { $in: hostedEventIds } });
        await Event.deleteMany({ host_user_id: userId });

        // 5. Delete user profile itself
        await User.findByIdAndDelete(userId);

        res.json({ message: 'Account permanently deleted' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

const { isConfigured: mailerConfigured, sendMail, passwordResetEmail } = require('../utils/mailer');

// Forgot Password (Request Code)
router.post('/forgot-password', async (req, res) => {
    try {
        const { email } = req.body;
        if (!email) return res.status(400).json({ error: 'Email is required' });

        // Generic success message below regardless of whether the user exists,
        // so this endpoint can't be used to enumerate registered emails.
        const genericResponse = { message: 'If the email is registered, a reset code has been sent' };

        const user = await User.findOne({ email });
        if (!user) return res.json(genericResponse);

        // Cooldown check: 60 seconds between password reset requests
        const dbUser = await User.findById(user._id);
        const storedExpires = dbUser.get('reset_password_expires');
        if (storedExpires) {
            const timePassed = 3600000 - (new Date(storedExpires).getTime() - Date.now());
            if (timePassed < 60000 && timePassed > 0) {
                const waitSeconds = Math.ceil((60000 - timePassed) / 1000);
                return res.status(429).json({ error: `Please wait ${waitSeconds} seconds before requesting another code` });
            }
        }

        // Generate 6-digit code
        const code = Math.floor(100000 + Math.random() * 900000).toString();
        
        // Hash code using Node's crypto module (OWASP Compliant)
        const crypto = require('crypto');
        const hashedCode = crypto.createHash('sha256').update(code).digest('hex');
        
        // Save temporary codes to user object
        await User.findByIdAndUpdate(user._id, {
            $set: {
                reset_password_code: hashedCode,
                reset_password_expires: Date.now() + 3600000 // 1 hour
            }
        });

        // Deliver the code by email when a provider is configured (RESEND_API_KEY).
        if (mailerConfigured()) {
            const { subject, html } = passwordResetEmail(code);
            const sent = await sendMail({ to: email, subject, html });
            if (!sent) console.error(`[auth] Could not email reset code to ${email}`);
        } else if (process.env.NODE_ENV !== 'production') {
            // Local dev without a mail provider: log it. Never in production.
            console.log(`[DEV] Password reset code for ${email}: ${code}`);
        } else {
            console.error('[auth] RESEND_API_KEY not set — reset codes cannot be delivered in production');
        }

        res.json(genericResponse);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Reset Password (Verify Code & Update)
router.post('/reset-password', async (req, res) => {
    try {
        const { email, code, newPassword } = req.body;
        
        if (!email || !code || !newPassword) {
            return res.status(400).json({ error: 'All fields (email, code, newPassword) are required' });
        }

        const user = await User.findOne({ email });
        if (!user) return res.status(404).json({ error: 'User not found' });

        // Fetch stored values
        const dbUser = await User.findById(user._id);
        const storedCode = dbUser.get('reset_password_code');
        const storedExpires = dbUser.get('reset_password_expires');

        // Hash incoming code for matching the DB secure hash
        const crypto = require('crypto');
        const hashedIncomingCode = crypto.createHash('sha256').update(code).digest('hex');

        if (!storedCode || storedCode !== hashedIncomingCode) {
            return res.status(400).json({ error: 'Invalid reset code' });
        }

        if (!storedExpires || new Date(storedExpires) < new Date()) {
            return res.status(400).json({ error: 'Reset code has expired' });
        }

        // Update password
        const salt = await bcrypt.genSalt(10);
        const password_hash = await bcrypt.hash(newPassword, salt);

        await User.findByIdAndUpdate(user._id, {
            $set: { password_hash: password_hash },
            $unset: { reset_password_code: "", reset_password_expires: "" }
        });

        res.json({ message: 'Password updated successfully' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;

