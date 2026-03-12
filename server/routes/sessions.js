const express = require("express");
const router = express.Router();
const DanceSession = require("../models/DanceSession");
const auth = require("../middleware/auth");

const Event = require("../models/Event");

// Start Session
router.post("/start", auth, async (req, res) => {
  try {
    const { event_id } = req.body;

    // Validate Event Status
    const event = await Event.findById(event_id);
    if (!event) return res.status(404).json({ error: "Event not found" });

    if (event.status !== "active") {
      return res.status(409).json({ error: "EVENT_NOT_ACTIVE" });
    }

    const session = new DanceSession({
      event_id,
      user_id: req.user._id,
      started_at: new Date(),
    });
    await session.save();
    res.json({ session_id: session._id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const User = require("../models/User");
const { addMonthlyPoints } = require("../utils/rankUtils");

// ...

// Stop Session (Update with points)
router.post("/stop", auth, async (req, res) => {
  try {
    const { session_id, points, duration_sec } = req.body;

    const session = await DanceSession.findById(session_id);
    if (!session) return res.status(404).json({ error: "Session not found" });
    if (session.user_id.toString() !== req.user._id)
      return res.status(403).json({ error: "Not your session" });

    // Idempotency: if already ended, just return success
    if (session.ended_at) {
      return res.json(session);
    }

    const { motion_stats } = req.body;

    // Calculate Suspicion Score
    let suspicionScore = 0;
    let isSuspicious = false;

    if (motion_stats) {
      // Rule 1: Flat Pattern (Mechanical?)
      if (motion_stats.flat_pattern_seconds > 10) suspicionScore += 30; // High penalty

      // Rule 2: Inhuman Rhythm (too fast)
      if (
        motion_stats.avg_peak_interval_ms < 180 &&
        motion_stats.avg_peak_interval_ms > 0
      )
        suspicionScore += 50;

      // Rule 3: Low Variance (Machine-like)
      if (motion_stats.variance < 0.01 && motion_stats.total_samples > 100)
        suspicionScore += 20;

      // Rule 4 (V3): Rotational Entropy Check
      // Real dancing always involves rotation. Shaking doesn't.
      if (motion_stats.v3_enabled) {
        if (motion_stats.avg_gyro_magnitude < 0.3 && points > 100) {
            suspicionScore += 60; // Flag very strongly
        }
      }

      if (suspicionScore > 40) isSuspicious = true;
    }

    session.ended_at = new Date();
    session.points = points;
    session.duration_sec = duration_sec;
    session.motion_stats = motion_stats;
    session.suspicion_score = suspicionScore;
    session.is_suspicious = isSuspicious;

    await session.save();

    // --- XP & Level Logic ---
    const user = await User.findById(req.user._id);
    user.xp = (user.xp || 0) + points; // 1 point = 1 XP

    let levelUp = false;
    let newLevel = user.level || 1;

    // Loop for multi-level gain
    while (true) {
      const xpNeeded = 1000 * newLevel;
      if (user.xp >= xpNeeded) {
        user.xp -= xpNeeded; // Reset XP or keep calculating? Prompt says: "xp >= xp_acumulado... subir nivel".
        // Usually RPGs do cumulative or reset.
        // Prompt example: "Nivel 1 -> 1000 XP".
        // If I have 1200 XP at level 1:
        // Level Up -> Level 2. XP becomes 200 (1200 - 1000).
        // Required for Level 2->3 is 2000. 200 < 2000. Stop.
        newLevel++;
        levelUp = true;
        user.xp = user.xp - xpNeeded; // Deduct cost
      } else {
        break;
      }
    }

    user.level = newLevel;
    await user.save();

    // --- Monthly Rank Points ---
    const rankResult = await addMonthlyPoints(User, req.user._id, points);

    res.json({
      ...session.toObject(),
      points, // explicit return
      total_xp: user.xp,
      level: user.level,
      level_up: levelUp,
      new_level: levelUp ? user.level : undefined,
      rank: rankResult?.rank,
      monthly_points: rankResult?.monthly_points,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get My Sessions for Event
router.get("/my", auth, async (req, res) => {
  try {
    const { event_id } = req.query;
    // If event_id is provided, filter by it. Else return all? Focus on event_id for now.
    const query = { user_id: req.user._id };
    if (event_id) {
      query.event_id = event_id;
    }

    const sessions = await DanceSession.find(query).sort("-started_at");
    res.json(sessions);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
