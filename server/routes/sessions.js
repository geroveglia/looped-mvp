const express = require("express");
const router = express.Router();
const DanceSession = require("../models/DanceSession");
const EventMember = require("../models/EventMember");
const auth = require("../middleware/auth");

const Event = require("../models/Event");

// Max points per second a human can plausibly generate.
// Mirrors MotionScoringService.pointsPerSecondCap on the client.
const MAX_POINTS_PER_SEC = 8;
// Margin for client/server clock skew when capping durations.
const CLOCK_SKEW_SEC = 120;

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

    // Membership: private events require having joined via invite code.
    // Public events auto-join (normal flow joins first; this covers offline sync).
    let membership = await EventMember.findOne({ event_id, user_id: req.user._id });
    if (!membership) {
      if (event.visibility === "private") {
        return res.status(403).json({ error: "NOT_A_MEMBER" });
      }
      try {
        membership = await new EventMember({ event_id, user_id: req.user._id }).save();
      } catch (e) {
        // Unique-index race with a concurrent join — membership exists, continue.
      }
    }

    // started_at is client-supplied for offline sync; clamp it so a forged
    // past timestamp can't inflate the temporal points cap at /stop.
    const now = new Date();
    let startedAt = req.body.started_at ? new Date(req.body.started_at) : now;
    if (isNaN(startedAt.getTime()) || startedAt > now) startedAt = now;
    if (event.starts_at && startedAt < event.starts_at) startedAt = event.starts_at;

    const session = new DanceSession({
      event_id,
      user_id: req.user._id,
      started_at: startedAt,
    });
    await session.save();
    res.json({ session_id: session._id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const User = require("../models/User");
const { addMonthlyPoints } = require("../utils/rankUtils");
const { updateStreak } = require("../utils/streakUtils");

// Heartbeat: the client reports its CUMULATIVE points every ~60s while dancing.
// - Makes the event leaderboard live (open sessions carry real points).
// - Keeps the session from being closed by the stale-session sweep.
// - Caps totals server-side, so a forged final /stop can't exceed what was
//   plausibly accumulated.
router.post("/heartbeat", auth, async (req, res) => {
  try {
    const { session_id, points } = req.body;

    const session = await DanceSession.findById(session_id);
    if (!session) return res.status(404).json({ error: "Session not found" });
    if (session.user_id.toString() !== req.user._id)
      return res.status(403).json({ error: "Not your session" });
    if (session.ended_at && !session.auto_closed)
      return res.status(409).json({ error: "SESSION_ENDED" });

    let cumulative = Math.floor(Number(points));
    if (!Number.isFinite(cumulative) || cumulative < 0) {
      cumulative = session.points || 0;
    }

    // Same physical/temporal cap as /stop
    const elapsedSec =
      Math.max(0, Math.ceil((Date.now() - session.started_at.getTime()) / 1000)) +
      CLOCK_SKEW_SEC;
    const maxPoints = elapsedSec * MAX_POINTS_PER_SEC;
    if (cumulative > maxPoints) cumulative = maxPoints;

    // Monotonic: a heartbeat can only raise the running total
    if (cumulative > (session.points || 0)) session.points = cumulative;
    session.last_heartbeat_at = new Date();
    // If the sweep had closed it (e.g. app frozen a while), revive it
    if (session.auto_closed) {
      session.auto_closed = false;
      session.ended_at = null;
      session.duration_sec = undefined;
    }
    await session.save();

    res.json({ ok: true, points: session.points });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Stop Session (Update with points)
router.post("/stop", auth, async (req, res) => {
  try {
    const { session_id, points, duration_sec } = req.body;

    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ error: "User not found" });

    // Rate Limiting Cooldown (anti-spam)
    const cooldownMs = 3000;
    if (user.last_score_submission && (Date.now() - user.last_score_submission.getTime() < cooldownMs)) {
      return res.status(429).json({ error: "SUBMISSION_COOLDOWN_ACTIVE" });
    }
    user.last_score_submission = new Date();

    const session = await DanceSession.findById(session_id);
    if (!session) return res.status(404).json({ error: "Session not found" });
    if (session.user_id.toString() !== req.user._id)
      return res.status(403).json({ error: "Not your session" });

    // Idempotency: if already ended by an explicit stop, just return success.
    // Sessions closed by the stale sweep (auto_closed) can still be finalized:
    // the phone may have been frozen with the screen off and is now reporting
    // its real totals.
    if (session.ended_at && !session.auto_closed) {
      return res.json(session);
    }

    const { motion_stats } = req.body;

    // --- Server-side sanity validation ---
    // points/duration are client-reported: coerce to sane non-negative ints.
    let cleanPoints = Math.floor(Number(points));
    let cleanDuration = Math.floor(Number(duration_sec));
    if (!Number.isFinite(cleanPoints) || cleanPoints < 0) cleanPoints = 0;
    if (!Number.isFinite(cleanDuration) || cleanDuration < 0) cleanDuration = 0;

    // Temporal cap: the session can't have lasted longer than the real time
    // elapsed since the server registered its start (plus clock-skew margin).
    const elapsedSec =
      Math.max(0, Math.ceil((Date.now() - session.started_at.getTime()) / 1000)) +
      CLOCK_SKEW_SEC;
    if (cleanDuration > elapsedSec) cleanDuration = elapsedSec;

    // Calculate Suspicion Score
    let suspicionScore = 0;
    let isSuspicious = false;

    // Physical cap: nobody sustains more than MAX_POINTS_PER_SEC. Reported
    // totals above it are cut down and flag the session on their own
    // (threshold is > 40).
    const maxPoints = cleanDuration * MAX_POINTS_PER_SEC;
    if (cleanPoints > maxPoints) {
      suspicionScore += 50;
      cleanPoints = maxPoints;
    }

    if (motion_stats) {
      const isChaoticHuman = motion_stats.variance > 0.05;

      // Rule 1: Flat Pattern (Mechanical?)
      if (motion_stats.flat_pattern_seconds > 10) suspicionScore += 30; // High penalty

      // Rule 2: Inhuman Rhythm (too fast) - Adjusted from 180ms to 140ms
      if (
        motion_stats.avg_peak_interval_ms < 140 &&
        motion_stats.avg_peak_interval_ms > 0
      ) {
        if (!isChaoticHuman) {
          suspicionScore += 50;
        } else {
          suspicionScore += 10; // Heavily discount for human chaotic movement
        }
      }

      // Rule 3: Low Variance (Machine-like)
      if (motion_stats.variance < 0.01 && motion_stats.total_samples > 100) {
        if (!isChaoticHuman) {
          suspicionScore += 20;
        }
      }

      // Rule 4 (V3): Rotational Entropy Check
      // Real dancing always involves rotation. Shaking doesn't.
      // Lowered avg_gyro_magnitude threshold from 0.3 to 0.15 to avoid false flags
      if (motion_stats.v3_enabled) {
        if (motion_stats.avg_gyro_magnitude < 0.15 && cleanPoints > 100) {
            suspicionScore += 60; // Flag very strongly
        }
      }
    }

    if (suspicionScore > 40) isSuspicious = true;

    session.ended_at = new Date();
    session.points = cleanPoints;
    session.duration_sec = cleanDuration;
    session.motion_stats = motion_stats;
    session.suspicion_score = suspicionScore;
    session.is_suspicious = isSuspicious;
    session.auto_closed = false;

    await session.save();

    // --- XP & Level Logic ---
    user.xp = (user.xp || 0) + cleanPoints; // 1 point = 1 XP

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
      } else {
        break;
      }
    }

    user.level = newLevel;
    
    // --- Streak Logic ---
    updateStreak(user);

    // --- Monthly Rank Points ---
    // Pass pre-loaded user document to save in a single consolidated database save!
    const rankResult = await addMonthlyPoints(User, user, cleanPoints);

    res.json({
      ...session.toObject(),
      points: cleanPoints, // explicit return (post-validation)
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
