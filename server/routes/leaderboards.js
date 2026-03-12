const express = require("express");
const router = express.Router();
const mongoose = require("mongoose");
const User = require("../models/User");
const DanceSession = require("../models/DanceSession");
const auth = require("../middleware/auth");

// Global Leaderboard (Top XP)
router.get("/global", auth, async (req, res) => {
  try {
    const topUsers = await User.find({})
      .select("username avatar_url level xp rank monthly_points")
      .sort({ level: -1, xp: -1 })
      .limit(20);

    res.json(topUsers);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Event Leaderboard (Top points in specific event)
router.get("/event/:eventId", auth, async (req, res) => {
  try {
    const { eventId } = req.params;

    // Aggregate sessions by user_id for this event
    const leaderboard = await DanceSession.aggregate([
      { $match: { event_id: new mongoose.Types.ObjectId(eventId) } },
      {
        $group: {
          _id: "$user_id",
          totalPoints: { $sum: "$points" },
          totalDuration: { $sum: "$duration_sec" },
        },
      },
      { $sort: { totalPoints: -1 } },
      { $limit: 20 },
      {
        $lookup: {
          from: "users",
          localField: "_id",
          foreignField: "_id",
          as: "userInfo",
        },
      },
      { $unwind: "$userInfo" },
      {
        $project: {
          _id: 1,
          totalPoints: 1,
          totalDuration: 1,
          username: "$userInfo.username",
          avatar_url: "$userInfo.avatar_url",
          level: "$userInfo.level",
          rank: "$userInfo.rank",
        },
      },
    ]);

    res.json(leaderboard);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
