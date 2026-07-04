const express = require("express");
const router = express.Router();
const mongoose = require("mongoose");
const User = require("../models/User");
const DanceSession = require("../models/DanceSession");
const auth = require("../middleware/auth");

// Global Leaderboard (Top XP)
router.get("/global", auth, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const topUsers = await User.find({})
      .select("username avatar_url level xp rank monthly_points")
      .sort({ level: -1, xp: -1 })
      .skip(skip)
      .limit(limit);

    res.json(topUsers);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Event Leaderboard (Top points in specific event)
router.get("/event/:eventId", auth, async (req, res) => {
  try {
    const { eventId } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

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
      { $skip: skip },
      { $limit: limit },
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
const Friendship = require("../models/Friendship");

// Friends Leaderboard — top points for friends of the current user in a specific event
router.get("/event/:eventId/friends", auth, async (req, res) => {
  try {
    const { eventId } = req.params;
    const userId = req.user._id;

    // Get accepted friend IDs (both directions)
    const friendships = await Friendship.find({
      $or: [{ requester: userId }, { recipient: userId }],
      status: "accepted",
    });

    const friendIds = friendships.map((f) =>
      f.requester.toString() === userId.toString() ? f.recipient : f.requester
    );

    // Include the current user in their own friends leaderboard
    friendIds.push(userId);

    const leaderboard = await DanceSession.aggregate([
      {
        $match: {
          event_id: new mongoose.Types.ObjectId(eventId),
          user_id: { $in: friendIds },
        },
      },
      {
        $group: {
          _id: "$user_id",
          totalPoints: { $sum: "$points" },
          totalDuration: { $sum: "$duration_sec" },
        },
      },
      { $sort: { totalPoints: -1 } },
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
        // Same shape as /events/:id/leaderboard (user_id + points) so the app
        // model parses it; totalPoints kept for backwards compatibility.
        $project: {
          _id: 1,
          user_id: "$_id",
          points: "$totalPoints",
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
