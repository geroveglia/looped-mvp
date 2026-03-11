const express = require("express");
const router = express.Router();
const User = require("../models/User");
const Friendship = require("../models/Friendship");
const DanceSession = require("../models/DanceSession");
const SoloSession = require("../models/SoloSession");
const auth = require("../middleware/auth");

// Search Users
router.get("/search", auth, async (req, res) => {
  try {
    const { q } = req.query;
    if (!q) return res.json([]);

    const users = await User.find({
      username: { $regex: q, $options: "i" },
      _id: { $ne: req.user._id },
    })
      .select("username avatar_url level xp")
      .limit(10);

    res.json(users);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Follow User (or accept)
router.post("/follow/:id", auth, async (req, res) => {
  try {
    const recipientId = req.params.id;
    const requesterId = req.user._id;

    if (recipientId === requesterId.toString()) {
      return res.status(400).json({ error: "Cannot follow yourself" });
    }

    // Check if friendship already exists
    let friendship = await Friendship.findOne({
      $or: [
        { requester: requesterId, recipient: recipientId },
        { requester: recipientId, recipient: requesterId },
      ],
    });

    if (!friendship) {
      // Create new request
      friendship = new Friendship({
        requester: requesterId,
        recipient: recipientId,
        status: "accepted", // For Looped, let's make it a simple "follow" (auto-accepted for now)
      });
      await friendship.save();
    } else {
      // If already exists, maybe it was rejected or pending?
      // In follow system, if it exists, maybe unfollow? Let's implement toggle for simplicity.
      await Friendship.deleteOne({ _id: friendship._id });
      return res.json({ status: "unfollowed" });
    }

    res.json({ status: "followed", friendship });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get Friends
router.get("/friends", auth, async (req, res) => {
  try {
    const friendships = await Friendship.find({
      $or: [{ requester: req.user._id }, { recipient: req.user._id }],
      status: "accepted",
    }).populate("requester recipient", "username avatar_url level xp");

    // Filter out self from results
    const friends = friendships.map((f) => {
      return f.requester._id.toString() === req.user._id.toString()
        ? f.recipient
        : f.requester;
    });

    res.json(friends);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get Activity Feed
router.get("/feed", auth, async (req, res) => {
  try {
    const userId = req.user._id;

    // 1. Get friends
    const friendships = await Friendship.find({
      $or: [{ requester: userId }, { recipient: userId }],
      status: "accepted",
    });

    const friendIds = friendships.map((f) => {
      return f.requester.toString() === userId.toString()
        ? f.recipient
        : f.requester;
    });

    // Include self in feed
    friendIds.push(userId);

    // 2. Fetch Sessions from friends and self
    const [danceSessions, soloSessions] = await Promise.all([
      DanceSession.find({ user_id: { $in: friendIds } })
        .populate("user_id", "username avatar_url level")
        .populate("event_id", "name icon")
        .sort("-started_at")
        .limit(15),
      SoloSession.find({ user_id: { $in: friendIds } })
        .populate("user_id", "username avatar_url level")
        .sort("-started_at")
        .limit(15),
    ]);

    // 3. Merge, add type, and sort
    let feed = [
      ...danceSessions.map((s) => ({ ...s.toObject(), feed_type: "dance" })),
      ...soloSessions.map((s) => ({ ...s.toObject(), feed_type: "solo" })),
    ];

    feed.sort((a, b) => new Date(b.started_at) - new Date(a.started_at));
    
    // Limit total feed items
    feed = feed.slice(0, 20);

    res.json(feed);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
