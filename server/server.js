require("dotenv").config();
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const rateLimit = require("express-rate-limit");

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
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static('uploads'));

// Database Connection
const mongoURI = process.env.MONGO_URI || process.env.MONGODB_URI;
mongoose
  .connect(mongoURI)
  .then(() => console.log("MongoDB Connected"))
  .catch((err) => console.error("MongoDB Connection Error:", err));

// Routes (Placeholder for now)
app.get("/", (req, res) => {
  res.send("Looped Backend is running");
});

// Import Routes
const authRoutes = require("./routes/auth");
const eventRoutes = require("./routes/events");
const sessionRoutes = require("./routes/sessions");
const soloRoutes = require("./routes/solo");

// Apply Rate Limiters
app.use(globalLimiter);
app.use("/auth/login", authLimiter);
app.use("/auth/register", authLimiter);

app.use("/auth", authRoutes);
app.use("/events", eventRoutes);
app.use("/sessions", sessionRoutes);
app.use("/solo", soloRoutes);

// Start Server
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
});
