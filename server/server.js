require("dotenv").config();
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");

// Validate critical environmental variables
const requiredEnv = ["JWT_SECRET", "MONGO_URI"];
const missingEnv = requiredEnv.filter(key => {
  if (key === "MONGO_URI") {
    return !process.env.MONGO_URI && !process.env.MONGODB_URI;
  }
  return !process.env[key];
});

if (missingEnv.length > 0) {
  console.error(`🛑 CRITICAL CONFIG ERROR: Missing environmental variables: \${missingEnv.join(", ")}`);
  process.exit(1);
}

// Fix #6: Trust Railway's reverse proxy so rate limiting uses real client IPs
// Without this, all requests appear to come from the same proxy IP,
// causing one user's requests to count against everyone.
const app = express();
app.set("trust proxy", 1);

// Fix #5: Helmet — security headers (XSS, clickjacking, sniffing, etc.)
// crossOriginResourcePolicy relaxed so /uploads images load from other origins (Flutter web dev)
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" },
}));

// Limiters
// 1000/15min ≈ 1 req/s sustained: leaves room for live leaderboard polling
// (every 15s) plus event refresh (every 30s) during a multi-hour session.
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // limit each IP to 1000 requests per windowMs
  message: "Too many requests from this IP, please try again after 15 minutes",
  standardHeaders: true,
  legacyHeaders: false,
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10, // stricter limit for auth routes
  message: "Too many login attempts, please try again after 15 minutes",
  standardHeaders: true,
  legacyHeaders: false,
});

const PORT = process.env.PORT || 3000;

// Middleware
// Strict CORS configuration
const allowedOrigins = process.env.ALLOWED_ORIGINS 
  ? process.env.ALLOWED_ORIGINS.split(",") 
  : ["http://localhost:3000", "http://127.0.0.1:3000", "http://localhost:8080", "http://localhost"];

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (like mobile apps, Flutter webview, or curls)
    if (!origin) return callback(null, true);
    if (allowedOrigins.includes(origin) || process.env.NODE_ENV !== "production") {
      return callback(null, true);
    }
    return callback(new Error("CORS policy violation: " + origin), false);
  },
  credentials: true
}));

app.use(express.json());

// Uploads are served publicly: mobile image widgets (Image.network/NetworkImage)
// cannot attach the JWT header, so auth here broke every avatar/event image.
// Access control relies on unguessable filenames (crypto random suffix at upload).
app.use('/uploads', express.static('uploads', { maxAge: '7d', immutable: true }));

// Database Connection
const mongoURI = process.env.MONGO_URI || process.env.MONGODB_URI;
mongoose
  .connect(mongoURI)
  .then(() => console.log("MongoDB Connected"))
  .catch((err) => {
    console.error("🛑 MONGODB CONNECTION FAILURE:", err);
    process.exit(1); // Exit process with error
  });

// Fix #7: Health check endpoint — allows Railway/uptime monitors to verify the server is alive
app.get("/health", (req, res) => {
  const dbState = mongoose.connection.readyState;
  // 0=disconnected, 1=connected, 2=connecting, 3=disconnecting
  const dbStatus = dbState === 1 ? "connected" : "disconnected";
  res.status(dbState === 1 ? 200 : 503).json({
    status: dbState === 1 ? "ok" : "degraded",
    db: dbStatus,
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});

app.get("/", (req, res) => {
  res.json({ message: "Looped Backend is running", version: "1.0.0" });
});

// Import Routes
const authRoutes = require("./routes/auth");
const eventRoutes = require("./routes/events");
const sessionRoutes = require("./routes/sessions");
const soloRoutes = require("./routes/solo");
const socialRoutes = require("./routes/social");
const leaderboardRoutes = require("./routes/leaderboards");
const rankRoutes = require("./routes/ranks");

// Apply Rate Limiters
app.use(globalLimiter);
app.use("/auth/login", authLimiter);
app.use("/auth/register", authLimiter);

app.use("/auth", authRoutes);
app.use("/events", eventRoutes);
app.use("/sessions", sessionRoutes);
app.use("/solo", soloRoutes);
app.use("/social", socialRoutes);
app.use("/leaderboards", leaderboardRoutes);
app.use("/ranks", rankRoutes);

// Global error handler
app.use((err, req, res, next) => {
  if (err.name === 'MulterError') {
    return res.status(400).json({ error: `Upload error: ${err.message}` });
  } else if (err) {
    return res.status(err.status || 400).json({ error: err.message });
  }
  next();
});

// Start Server
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
});
