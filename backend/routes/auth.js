const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const auth = require('../middleware/auth');

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

module.exports = router;
