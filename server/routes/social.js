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

    // Escape regex metacharacters: raw user input like "(((" would crash the
    // query (500) and unescaped patterns open the door to ReDoS.
    const escaped = String(q).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

    const users = await User.find({
      username: { $regex: escaped, $options: "i" },
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
// Send / Toggle Friend Request
router.post("/follow/:id", auth, async (req, res) => {
  try {
    const recipientId = req.params.id;
    const requesterId = req.user._id;

    if (recipientId === requesterId.toString()) {
      return res.status(400).json({ error: "Cannot add yourself as a friend" });
    }

    // Check if friendship already exists
    let friendship = await Friendship.findOne({
      $or: [
        { requester: requesterId, recipient: recipientId },
        { requester: recipientId, recipient: requesterId },
      ],
    });

    if (!friendship) {
      // Create new PENDING request
      friendship = new Friendship({
        requester: requesterId,
        recipient: recipientId,
        status: "pending",
      });
      await friendship.save();
      return res.json({ status: "requested", friendship });
    } else {
      // If it exists:
      // Case 1: Already accepted -> Unfriend (Delete)
      if (friendship.status === "accepted") {
        await Friendship.deleteOne({ _id: friendship._id });
        return res.json({ status: "unfollowed" });
      }
      // Case 2: Pending request
      if (friendship.status === "pending") {
        // If current user was the requester -> Cancel request
        if (friendship.requester.toString() === requesterId.toString()) {
          await Friendship.deleteOne({ _id: friendship._id });
          return res.json({ status: "cancelled" });
        } else {
          // If current user was the recipient -> Accept request
          friendship.status = "accepted";
          await friendship.save();
          return res.json({ status: "accepted", friendship });
        }
      }
      // Case 3: Rejected request -> Allow resending request
      if (friendship.status === "rejected") {
        friendship.status = "pending";
        friendship.requester = requesterId;
        friendship.recipient = recipientId;
        await friendship.save();
        return res.json({ status: "requested", friendship });
      }
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /social/requests/pending — Get all incoming pending friend requests
router.get("/requests/pending", auth, async (req, res) => {
  try {
    const requests = await Friendship.find({
      recipient: req.user._id,
      status: "pending",
    }).populate("requester", "username avatar_url level xp");

    // Return the populated requesters
    const incomingRequests = requests.map(r => ({
      friendship_id: r._id,
      requester: r.requester,
      created_at: r.created_at,
    }));

    res.json(incomingRequests);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /social/requests/respond — Accept or reject a friend request
router.post("/requests/respond", auth, async (req, res) => {
  try {
    const { requesterId, action } = req.body; // action: 'accept' or 'reject'
    if (!requesterId || !action) {
      return res.status(400).json({ error: "requesterId and action ('accept'/'reject') required" });
    }

    const friendship = await Friendship.findOne({
      requester: requesterId,
      recipient: req.user._id,
      status: "pending"
    });

    if (!friendship) {
      return res.status(404).json({ error: "Pending friend request not found" });
    }

    if (action === "accept") {
      friendship.status = "accepted";
      await friendship.save();
      return res.json({ status: "accepted", friendship });
    } else if (action === "reject") {
      await Friendship.deleteOne({ _id: friendship._id });
      return res.json({ status: "rejected" });
    } else {
      return res.status(400).json({ error: "Invalid action. Use 'accept' or 'reject'" });
    }
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
