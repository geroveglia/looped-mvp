require("dotenv").config();
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
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

// Limiters
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
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

const app = express();
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
app.use('/uploads', express.static('uploads'));

// Database Connection
const mongoURI = process.env.MONGO_URI || process.env.MONGODB_URI;
mongoose
  .connect(mongoURI)
  .then(() => console.log("MongoDB Connected"))
  .catch((err) => {
    console.error("🛑 MONGODB CONNECTION FAILURE:", err);
    process.exit(1); // Exit process with error
  });

// Routes (Placeholder for now)
app.get("/", (req, res) => {
  res.send("Looped Backend is running");
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

// Start Server
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
});
