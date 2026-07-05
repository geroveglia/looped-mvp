const express = require("express");
const router = express.Router();
const User = require("../models/User");
const Friendship = require("../models/Friendship");
const DanceSession = require("../models/DanceSession");
const SoloSession = require("../models/SoloSession");
const Block = require("../models/Block");
const Report = require("../models/Report");
const auth = require("../middleware/auth");
const { pushToUsers } = require("../utils/push");

/** IDs of users with a block in either direction relative to userId. */
async function getBlockedIds(userId) {
  const blocks = await Block.find({
    $or: [{ blocker: userId }, { blocked: userId }],
  });
  return blocks.map((b) =>
    b.blocker.toString() === userId.toString() ? b.blocked : b.blocker
  );
}

// Search Users
router.get("/search", auth, async (req, res) => {
  try {
    const { q } = req.query;
    if (!q) return res.json([]);

    // Escape regex metacharacters: raw user input like "(((" would crash the
    // query (500) and unescaped patterns open the door to ReDoS.
    const escaped = String(q).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

    // Hide users with a block in either direction
    const blockedIds = await getBlockedIds(req.user._id);

    const users = await User.find({
      username: { $regex: escaped, $options: "i" },
      _id: { $ne: req.user._id, $nin: blockedIds },
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

    // Blocks (either direction) prevent friend requests
    const blockExists = await Block.findOne({
      $or: [
        { blocker: requesterId, blocked: recipientId },
        { blocker: recipientId, blocked: requesterId },
      ],
    });
    if (blockExists) {
      return res.status(403).json({ error: "BLOCKED" });
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

      // Fire-and-forget push (no-op if Firebase isn't configured)
      User.findById(requesterId).select("username").then((u) =>
        pushToUsers([recipientId], {
          title: "Nueva solicitud de amistad 🕺",
          body: `${u?.username || "Alguien"} quiere ser tu amigo en Looped`,
        })
      ).catch(() => {});

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

          User.findById(requesterId).select("username").then((u) =>
            pushToUsers([friendship.requester], {
              title: "¡Solicitud aceptada! 🎉",
              body: `${u?.username || "Alguien"} aceptó tu solicitud — ya son amigos`,
            })
          ).catch(() => {});

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

      User.findById(req.user._id).select("username").then((u) =>
        pushToUsers([friendship.requester], {
          title: "¡Solicitud aceptada! 🎉",
          body: `${u?.username || "Alguien"} aceptó tu solicitud — ya son amigos`,
        })
      ).catch(() => {});

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

// Block / Unblock a user (toggle).
// Blocking also removes any friendship or pending request between the two.
router.post("/block/:id", auth, async (req, res) => {
  try {
    const targetId = req.params.id;
    const userId = req.user._id;

    if (targetId === userId.toString()) {
      return res.status(400).json({ error: "Cannot block yourself" });
    }

    const existing = await Block.findOne({ blocker: userId, blocked: targetId });
    if (existing) {
      await Block.deleteOne({ _id: existing._id });
      return res.json({ status: "unblocked" });
    }

    await new Block({ blocker: userId, blocked: targetId }).save();
    await Friendship.deleteMany({
      $or: [
        { requester: userId, recipient: targetId },
        { requester: targetId, recipient: userId },
      ],
    });

    res.json({ status: "blocked" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Report a user (stored for manual review — store UGC requirement)
router.post("/report", auth, async (req, res) => {
  try {
    const { reported_id, reason, details } = req.body;
    if (!reported_id) {
      return res.status(400).json({ error: "reported_id required" });
    }
    if (reported_id === req.user._id.toString()) {
      return res.status(400).json({ error: "Cannot report yourself" });
    }

    const validReasons = ["spam", "abuse", "cheating", "inappropriate", "other"];
    await new Report({
      reporter: req.user._id,
      reported: reported_id,
      reason: validReasons.includes(reason) ? reason : "other",
      details: typeof details === "string" ? details.slice(0, 500) : undefined,
    }).save();

    res.json({ message: "Report submitted. Thank you for keeping Looped safe." });
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
