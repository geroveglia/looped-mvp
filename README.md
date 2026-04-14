# 🎵 Looped

**Looped** is a mobile app that turns dancing into a social competition. Track how much you dance at parties, compete with friends, climb the global ranking, and share your sessions on Instagram.

---

## 📱 Features

- **Dance Tracking** — Uses the phone's built-in pedometer to measure your movement on the dance floor in real time.
- **Anti-cheat System** — Smart detection to ensure rankings stay fair and movement is genuine.
- **Global Party Ranking** — Every party has its own leaderboard. See who danced the most across all events.
- **Party Feed** — Browse all active and upcoming parties from the main menu.
- **Private Events** — Create or join private competitions with friends.
- **Instagram Sharing** — Share your dance session summary directly to Instagram Stories when you finish.
- **Social Competition** — Challenge your friends and see where you rank.

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|------------|
| Mobile Frontend | Flutter (Dart) |
| Backend | Node.js (REST API) |
| Database | MongoDB |
| Deployment | Railway |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Node.js](https://nodejs.org/) (v18+)
- [MongoDB](https://www.mongodb.com/) instance (local or Atlas)

### Clone the repository

```bash
git clone https://github.com/geroveglia/looped-mvp.git
cd looped-mvp
```

### Backend setup

```bash
cd server
npm install
```

Create a `.env` file in `/server`:

```env
MONGODB_URI=your_mongodb_connection_string
PORT=3000
```

```bash
npm start
```

### Flutter app setup

```bash
cd frontend
flutter pub get
flutter run
```

---

## 📁 Project Structure

```
looped-mvp/
├── frontend/       # Flutter mobile app
├── server/         # Node.js REST API
├── nixpacks.toml   # Railway deployment config
└── railway.json    # Railway settings
```

---

## 🗺️ Roadmap

- [ ] Push notifications for events
- [ ] In-app friend requests
- [ ] DJ/organizer dashboard
- [ ] iOS & Android store release

---

## 👤 Author

**Geronimo Veglia** — [@geroveglia](https://github.com/geroveglia) · [LinkedIn](https://linkedin.com/in/geronimo-veglia-78a77a189)
