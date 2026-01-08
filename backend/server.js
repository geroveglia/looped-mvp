require("dotenv").config();
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");

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

app.use("/auth", authRoutes);
app.use("/events", eventRoutes);
app.use("/sessions", sessionRoutes);
app.use("/solo", soloRoutes);

// Start Server
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
});
