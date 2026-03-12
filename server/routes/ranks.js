const express = require('express');
const router = express.Router();
const User = require('../models/User');
const auth = require('../middleware/auth');
const {
  getRankMeta,
  getNextRankInfo,
  checkMonthReset,
  BADGE_DEFINITIONS,
} = require('../utils/rankUtils');

// GET /ranks/me — Current rank, monthly points, progress, badges
router.get('/me', auth, async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ error: 'User not found' });

    // Auto-reset if month changed
    const didReset = await checkMonthReset(user);
    if (didReset) await user.save();

    // Check Top 100 status for potential Immortal
    const top100 = await User.find({
      monthly_points: { $gt: 0 }
    })
      .sort({ monthly_points: -1 })
      .limit(100)
      .select('_id');

    const top100Ids = top100.map(u => u._id.toString());
    const isTop100 = top100Ids.includes(user._id.toString());
    const top100Position = isTop100 ? top100Ids.indexOf(user._id.toString()) + 1 : null;

    // If user qualifies for Immortal rank, update
    let effectiveRank = user.rank || 'ghost';
    if (isTop100 && (user.monthly_points || 0) >= 100000) {
      effectiveRank = 'immortal';
    }

    const rankMeta = getRankMeta(effectiveRank);
    const nextRank = getNextRankInfo(effectiveRank, user.monthly_points || 0);

    res.json({
      rank: effectiveRank,
      rank_meta: {
        name: rankMeta.name,
        emoji: rankMeta.emoji,
        color: rankMeta.color,
        description: rankMeta.description,
      },
      monthly_points: user.monthly_points || 0,
      next_rank: nextRank,
      top100_position: top100Position,
      is_top100: isTop100,
      badges: user.badges || [],
      rank_history: user.rank_history || [],
      hall_of_fame: user.hall_of_fame || false,
      bonus_multiplier: user.bonus_multiplier || 1.0,
    });
  } catch (err) {
    console.error('Ranks /me error:', err);
    res.status(500).json({ error: err.message });
  }
});

// GET /ranks/top100 — Monthly leaderboard (Immortal candidates)
router.get('/top100', auth, async (req, res) => {
  try {
    const top100 = await User.find({
      monthly_points: { $gt: 0 }
    })
      .sort({ monthly_points: -1 })
      .limit(100)
      .select('username avatar_url monthly_points rank badges hall_of_fame');

    const result = top100.map((u, idx) => ({
      position: idx + 1,
      user_id: u._id,
      username: u.username,
      avatar_url: u.avatar_url,
      monthly_points: u.monthly_points,
      rank: idx < 100 && u.monthly_points >= 100000 ? 'immortal' : (u.rank || 'ghost'),
      hall_of_fame: u.hall_of_fame || false,
    }));

    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /ranks/hall-of-fame — Historic hall of fame
router.get('/hall-of-fame', auth, async (req, res) => {
  try {
    const legends = await User.find({ hall_of_fame: true })
      .select('username avatar_url rank_history badges')
      .limit(50);

    res.json(legends);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /ranks/award-badge — Admin/internal badge granting
router.post('/award-badge', auth, async (req, res) => {
  try {
    const { user_id, badge_id } = req.body;

    // Validate badge exists
    const badgeDef = BADGE_DEFINITIONS[badge_id];
    if (!badgeDef) return res.status(400).json({ error: 'Invalid badge_id' });

    const targetUser = await User.findById(user_id || req.user._id);
    if (!targetUser) return res.status(404).json({ error: 'User not found' });

    // Check if already earned
    if (!targetUser.badges) targetUser.badges = [];
    if (targetUser.badges.find(b => b.id === badge_id)) {
      return res.status(409).json({ error: 'Badge already earned' });
    }

    targetUser.badges.push({
      id: badgeDef.id,
      name: badgeDef.name,
      emoji: badgeDef.emoji,
      earned_at: new Date(),
      description: badgeDef.description,
    });

    await targetUser.save();

    res.json({ message: 'Badge awarded', badge: badgeDef });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
