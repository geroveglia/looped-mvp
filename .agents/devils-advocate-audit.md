# 🔴 Devil's Advocate Audit — Looped MVP

**Audit Date:** 2026-05-28
**Auditor:** Devil's Advocate Agent
**Scope:** Full codebase review (Flutter frontend + Node.js/Express backend + MongoDB)
**Methodology:** Line-by-line source read of all server routes, models, utils, middleware, and all Flutter services/screens/managers.

---

## 1. 🔥 ANTIPRODUCTO_CHECK — How This App Becomes Hated

### Ways users will resent Looped:

| # | Hate Vector | Severity | Concrete Impact |
|---|------------|----------|-----------------|
| 1 | **Battery drain from hell** | **CRITICAL** | `MotionScoringService` subscribes to 3 sensor streams SIMULTANEOUSLY (`accelerometerEvents`, `userAccelerometerEvents`, `gyroscopeEvents`) at max frequency. Plus `Pedometer.stepCountStream`. Plus GPS (`geolocator`). A user at a 3-hour party will have a dead phone in 90 minutes. They will uninstall. |
| 2 | **Anti-cheat punishes real dancers** | **HIGH** | A dancer doing rapid footwork (avg_peak_interval < 180ms) gets flagged as cheater. Someone spinning on a dance floor (low gyro_magnitude < 0.3) gets penalized 60%. A user having fun at a techno party moves in repetitive patterns → flagged as "flat pattern." Real dancers will see mysteriously low scores and quit. |
| 3 | **Privacy nightmare** | **HIGH** | The app collects accelerometer, gyroscope, pedometer, AND GPS data. The `motion_stats` (including raw intensity history) is sent to the server and stored in MongoDB (`motion_stats: { type: Map, of: Mixed }`). This is a privacy time bomb. No privacy policy exists. No data deletion tool (the `delete-account` endpoint exists but only deletes from MongoDB — uploaded files remain on disk). |
| 4 | **Monthly rank reset demotivates** | **MEDIUM** | Users who grinded to "Pistero" (20k points) see their rank reset to "Ghost" every month. The bonus multiplier for ex-Immortals (1.2x) is small and opaque. Casual users will never escape "Ghost/Rookie" and will feel the system is rigged. |
| 5 | **Phone-in-pocket requirement** | **CRITICAL** | The UX assumes users dance with their phone in their pocket. Many clubs have dress codes where this isn't possible. Women's clothing often has no pockets. The app requires the screen to be ON and the app FOREGROUND to track (no background service). |
| 6 | **No offline event participation** | **HIGH** | At a party with bad WiFi (very common in clubs/basements), event sessions completely fail (`startSession` returns false). Only solo mode has offline fallback. The user is at a public event but cannot track because the API call failed. |
| 7 | **Instagram share is broken** | **MEDIUM** | `SocialShare.shareInstagramStory` is called with a hardcoded `appId: '123456789'` — this is obviously fake and will NOT work. The Instagram Stories integration will silently fail. Feature is a lie. |
| 8 | **Toxic competition without safeguards** | **LOW** | Leaderboards are purely quantitative (points = steps). There's no quality metric, no styling score, no peer voting. Users who literally run in place will outrank actual dancers. This incentivizes the WRONG behavior. |

---

## 2. 💔 DOLOR_ALIGNMENT — Feature-to-Problem Mapping

| Feature | Core Problem It Solves | Alignment | Verdict |
|---------|----------------------|-----------|---------|
| **Dance Tracking** | "How do I measure how much I danced?" | ✅ Strong | But uses pedometer (walking sensor) for dancing — fundamentally wrong sensor choice |
| **Anti-Cheat** | "How do we keep rankings fair?" | ⚠️ Weak | Heuristic rules are primitive and punish real dancers. No ML. No human review. No appeal. |
| **Global Leaderboard** | "How do I compare with everyone?" | ⚠️ Partial | Monthly reset destroys long-term progress. No weekly/daily granularity. Rankings lose meaning. |
| **Party Feed** | "What parties are happening?" | ⚠️ Weak | Just a list. No map view (in backlog). No filtering by music genre, no real-time attendance, no "friends going" indicator. |
| **Private Events** | "How do I compete with just friends?" | ✅ Good | Works, but invite code only. No QR code. No deep link. No "share with friends" button. Manual copy-paste. |
| **Instagram Sharing** | "How do I show off my session?" | ❌ Broken | Fake Instagram appId. Will not work in production. The screenshot + share sheet is nice UX but the delivery mechanism is non-functional. |
| **Social (Friends/Feed)** | "How do I see what friends are doing?" | ⚠️ Weak | Feed only shows completed sessions. No "friend is dancing NOW" real-time status. No challenges, no direct competition. Just a scrolling list. |
| **Rank Progression** | "How do I feel progression over time?" | ⚠️ Partial | Monthly reset is punitive. Badges exist in code but have NO automatic awarding logic — the `award-badge` endpoint is manual/admin-only. Users never earn badges organically. |

**Core Problem Statement Check:** "Making dancing competitive and social" — the "competitive" part works (points, leaderboards), but the "social" part is anemic (feed-only, no challenges, no groups, no real-time presence, no event chat). The app is 70% competitive tracker, 30% social network.

---

## 3. 🔬 ASSUMPTION_AUDIT — Unvalidated Beliefs

| # | Assumption | Status | Risk | Evidence Against |
|---|-----------|--------|------|------------------|
| 1 | **"Users will keep the app open and screen on while dancing"** | ❌ UNVALIDATED | CRITICAL | People dance with phones in pockets/bags. Screen-on means accidental touches, battery drain, and security risk if someone else picks up phone. No background service implemented. Android `ForegroundService` is the standard for fitness tracking — not used. |
| 2 | **"Pedometer data = dance intensity"** | ❌ FALSIFIED BY DESIGN | HIGH | Pedometers count WALKING steps (heel strike patterns). Dancing involves shuffling, spinning, jumping, swaying — movements pedometers DON'T detect well. The `addPoints(deltaSteps)` on step count conflates walking and dancing. Someone pacing around the club scores more than someone doing complex footwork in place. |
| 3 | **"Accelerometer + gyroscope anti-cheat works reliably"** | ❌ UNVALIDATED | HIGH | The anti-cheat thresholds (`threshold=2.5`, `cooldownMs=300`, `avg_peak_interval_ms < 180`) appear to be arbitrary constants with zero calibration data. No testing against real dance data. No false-positive rate analysis. `v3_enabled` is hardcoded `true` — meaning this was iterated on but never validated. |
| 4 | **"Users will invite friends"** | ❌ UNVALIDATED | MEDIUM | The invite mechanism is a 6-character alphanumeric code. No deep linking, no share intent, no QR code. Users must manually communicate codes. At a loud party, this is impractical. |
| 5 | **"Monthly ranking drives retention"** | ⚠️ UNTESTED | MEDIUM | Monthly reset in fitness apps typically REDUCES retention for all but the most competitive users. Casual users see progress wiped and disengage. Strava doesn't reset your stats monthly — it gives you year-over-year comparisons. |
| 6 | **"Users will accept all sensor permissions"** | ❌ DANGEROUS | HIGH | Android 13+ requires runtime permission for `ACTIVITY_RECOGNITION`. The code requests it, but if denied, falls back to `_usePedometerFallback = true` with a crude `0.82` multiplier. iOS requires HealthKit permissions which aren't even handled. |
| 7 | **"Solo sessions are compelling without event context"** | ⚠️ UNTESTED | MEDIUM | Solo mode exists but provides less value than event mode (no leaderboard to compete against). It's basically a pedometer with a score. The "Personal Best" card in SoloDanceScreen is a static placeholder. |
| 8 | **"Express 5 is production-ready"** | ❌ KNOWN RISK | HIGH | Express 5.2.1 is installed. Express 5 had breaking changes and is still considered unstable by many. Using alpha-level framework for a production API is a conscious risk with no mitigation noted. |

---

## 4. 💀 FAILURE_MODES — What Breaks When

### Scenario A: MongoDB is Down
- **Impact:** Complete application failure. Zero graceful degradation. Express just hangs waiting for connection.
- **Current handling:** `mongoose.connect(mongoURI).then(...).catch(...)` — catches the error but only logs it. Server starts anyway. Every API call that hits MongoDB will throw unhandled promise rejections.
- **Severity:** **CRITICAL**
- **Fix needed:** Health check endpoint, circuit breaker, graceful shutdown, retry logic, read-only cache fallback.

### Scenario B: Pedometer Permission Denied
- **Impact:** `_usePedometerFallback = true` kicks in. Steps are calculated as `(points * 0.82).round()`. `0.82` is MAGIC NUMBER with no calibration. Points come from `MotionScoringService` which detects "beats" from accelerometer threshold crossings — NOT steps.
- **Result:** User sees "steps" count that has NOTHING to do with actual steps. It's accelerometer spikes × 0.82. Misleading UI.
- **Severity:** **MEDIUM**

### Scenario C: User at Party with No Internet
- **Event sessions:** `startSession()` calls `/sessions/start` → API fails → returns `false`. User CANNOT track at the event. Period.
- **Solo sessions:** Starts offline with `pending_` ID. Finishes offline, saves to SharedPreferences. Syncs when back online. **This only works for solo mode.**
- **Impact:** At real-world parties where cell service is spotty (basements, crowded venues, rural areas), the core value proposition (event competition) fails.
- **Severity:** **CRITICAL**

### Scenario D: Two Users Claim Same Session Score
- **Impact:** `POST /sessions/stop` only checks `session.ended_at` for idempotency. If two different users somehow use the same session_id (unlikely but possible via race conditions or client bugs), the second call would update ANOTHER user's session.
- **Current protection:** `session.user_id.toString() !== req.user._id` check — this works for cross-user session stealing but doesn't prevent two parallel stops.
- **More likely exploit:** User opens two devices, starts session on both, dances once, stops both sessions. Gets double points. No device binding.
- **Severity:** **MEDIUM**

### Scenario E: Anti-Cheat Falsely Flags a Real Dancer
- **Impact chain:**
  1. Dancer moves rapidly at a techno party (180+ BPM footwork)
  2. `avg_peak_interval_ms < 180` → +50 suspicion points
  3. Dancer does repetitive shuffling → `variance < 0.01` → +20 suspicion points
  4. Dancer stays in one spot (low gyro) → `avg_gyro_magnitude < 0.3` → +60 suspicion points
  5. Total: 130 points → `isSuspicious = true` (threshold > 40)
  6. Server marks session as suspicious. Points are still counted but the `suspicion_score`/`is_suspicious` flag exists.
  
- **What the user experiences:** The penalty multipliers applied CLIENT-SIDE in `_penaltyMultiplier` (0.8, 0.9, 0.5) reduce points BEFORE they're sent to the server. So the user sees LOWER points in real-time and has no idea why. The `motion_stats` (including `suspicion_score`) are sent to server — but the user sees nothing in the UI about being flagged.
- **No appeal mechanism exists.**
- **Severity:** **HIGH**

### Scenario F: JWT_SECRET Missing from .env
- **Impact:** `jwt.sign()` and `jwt.verify()` called with `undefined` secret. Every token verification succeeds trivially (or fails silently depending on library version). Entire auth system collapses.
- **Current handling:** None. `process.env.JWT_SECRET` is used without a startup check.
- **Severity:** **CRITICAL**

---

## 5. 📈 SCALABILITY — What Breaks at Scale

### At 10,000 Concurrent Users

| Break Point | Why |
|-------------|-----|
| **MongoDB connection pool exhaustion** | No connection pool configuration. Mongoose default is 100 connections. At 10k users, each API request needs a DB connection. Connection queue will overflow, requests will timeout. |
| **Leaderboard aggregation kills CPU** | `GET /events` runs 5 `$lookup` stages, 2 `$reduce` operations in-memory, and a custom `$addFields` rank calculator — PER REQUEST. At 10k users refreshing the event feed every 30s, MongoDB will melt. |
| **Global leaderboard full scan** | `User.find({}).sort({ level: -1, xp: -1 }).skip(skip).limit(limit)` — no index on `level`+`xp` compound. MongoDB does a collection scan + in-memory sort for EVERY request. |
| **File upload collision** | `multer` writes to `uploads/` with `Date.now()` timestamps. At high concurrency, two requests within the same millisecond create filename collisions. |
| **Rate limiting memory store** | `express-rate-limit` stores IP counters in memory. Server restart = all rate limits reset. Behind a reverse proxy (Railway), all requests appear from same IP → ONE user hitting the limit blocks EVERYONE. |
| **No request timeouts** | Express routes have no timeout. A slow MongoDB query (e.g., the `/events` aggregation) will hold the event loop indefinitely. Node.js single-threaded = all other requests queue up. |

### At 100,000 Concurrent Users

Everything above PLUS:

| Break Point | Why |
|-------------|-----|
| **Event list aggregation becomes impossible** | The 5-stage `$lookup` with nested `$reduce` creates O(n × m × k) complexity where n=events, m=sessions, k=users. At 100k users across thousands of events, this aggregation will never return. |
| **No horizontal scaling strategy** | Sessions/events rely on MongoDB connection directly. No message queue, no read replicas, no sharding configuration. Railway deployment is single-instance. |
| **Image serving from Express** | Every avatar/event image is served by Express `static` middleware. No CDN, no cache headers, no image optimization. 100k users × avatar requests = Express becomes an image server, not an API. |
| **SharedPreferences as state store** | Frontend uses `SharedPreferences` for auth tokens, session state, pending sync queue. This is synchronous disk I/O on the UI thread. At scale, this causes jank. |
| **SoloSession sync storms** | Every 15 seconds, `SoloSessionManager._syncTimer` fires `syncPendingSessions()`. With many users returning online simultaneously (e.g., all leaving the same party), this creates a thundering herd of sync requests. |

---

## 6. 💰 COST — Hidden Costs

### Infrastructure Costs

| Item | Monthly Estimate | Notes |
|------|-----------------|-------|
| **MongoDB Atlas (M0 free tier)** | $0 → then $57+/mo | Free tier: 512MB storage, shared RAM, 100 max connections. This app stores motion_stats, session data, uploaded images. 512MB will fill within weeks of real usage. Atlas M10 (2GB RAM, 10GB storage) starts at $57/mo. |
| **Railway (hobby)** | $0 → then $20+/mo | Railway free tier has 500 hours/month and $5 credit. One always-on service burns 720 hours/month. You'll pay ~$5-20/mo for basic hosting. |
| **Image storage** | Unbounded growth | Every avatar upload and event image is stored on Railway's ephemeral disk. No cleanup. No object storage. Railway's disk is NOT persistent across deploys. Images WILL be lost on redeploy. |
| **Google Sign-In** | $0 | Free, but requires Google Cloud project with OAuth consent screen configured. |
| **Push Notifications (future)** | $0 | FCM is free, but Backlog item implies it's not yet implemented. |

### User-Facing Costs

| Cost | Impact |
|------|--------|
| **Battery drain** | 3 sensor streams + GPS + pedometer + screen on = phone dead in 1-2 hours of party use. This is the #1 reason users will uninstall after first use. |
| **Mobile data** | Uploading motion_stats JSON (including intensity history arrays) on every session stop. At crowded events, this could be hundreds of KB per user. Not huge but adds up. |
| **Storage** | `motion_stats` Map stored as Mixed type in MongoDB. No size limits. A long session's intensity_history array could be hundreds of entries. No trimming. |

---

## 7. 🔒 SECURITY — Vulnerabilities

### Critical Vulnerabilities

| # | Vulnerability | Location | Impact |
|---|--------------|----------|--------|
| **SEC-1** | **JWT tokens never expire** | `server/routes/auth.js` lines 62, 111 | `jwt.sign({ _id: user._id }, process.env.JWT_SECRET)` — no `expiresIn` option. Tokens are valid FOREVER. A leaked token grants permanent access. |
| **SEC-2** | **CORS allows all origins** | `server/server.js` line 31 | `app.use(cors())` — any website can make authenticated API calls using the user's cookies/bearer token. CSRF is trivial. |
| **SEC-3** | **Password reset code logged to console** | `server/routes/auth.js` lines 254-258 | `console.log('[PASSWORD RESET] Code: ${code}')` — the 6-digit reset code is PRINTED to Railway logs. Anyone with log access (Railway admins, team members, potential log leaks) can reset any password. |
| **SEC-4** | **Google Client ID hardcoded in source** | `frontend/lib/config.dart` line 13 | `71666521444-lkcv3d737qu8oqbg17md5cjf99d5o29v.apps.googleusercontent.com` — this is in the public GitHub repo. While client IDs are technically public in OAuth, it's poor practice and means the app is tied to a specific Google Cloud project that might not be yours. |
| **SEC-5** | **JWT_SECRET has no startup validation** | `server/middleware/auth.js` | `jwt.verify(token, process.env.JWT_SECRET)` — if JWT_SECRET is undefined, verification may pass trivially. Server should crash on startup if this is missing. |

### High Vulnerabilities

| # | Vulnerability | Location | Impact |
|---|--------------|----------|--------|
| **SEC-6** | **No input validation anywhere** | All routes | Acknowledged in BACKLOG.md. No Joi/Zod. `req.body` properties are used directly. Mongoose provides some type coercion but no business rule validation. Event creation accepts arbitrary `venue_name`, `address`, `city`, `country` with no sanitization. |
| **SEC-7** | **Rate limiting bypass via proxy** | `server/server.js` | Railway runs behind a reverse proxy. `express-rate-limit` sees only the proxy IP. ALL users share the 100 req/15min global limit. One heavy user hits the cap and blocks everyone. No `trust proxy` setting. |
| **SEC-8** | **Unrestricted file upload** | `server/routes/auth.js`, `server/routes/events.js` | Multer accepts any file type, any size. No virus scanning, no MIME type validation. An attacker can upload executable files, oversized files, or malicious content to `/uploads/`. |
| **SEC-9** | **Static file serving exposes all uploads** | `server/server.js` line 33 | `app.use('/uploads', express.static('uploads'))` — no authentication required to access ANY uploaded file. To view anyone's avatar, just guess the URL pattern. |
| **SEC-10** | **No rate limit on score submission** | `server/routes/sessions.js`, `server/routes/solo.js` | While there's a 3000ms cooldown, there's no global per-user rate limit on starting/stopping sessions. A script could create thousands of sessions. |
| **SEC-11** | **No Helmet.js security headers** | `server/server.js` | No X-Frame-Options, no Content-Security-Policy, no X-XSS-Protection, no HSTS. The API is vulnerable to basic web attacks. |

### Medium Vulnerabilities

| # | Vulnerability | Impact |
|---|--------------|--------|
| **SEC-12** | Password has no minimum strength requirement | `abc123` is a valid password |
| **SEC-13** | No email verification on registration | Fake emails work fine |
| **SEC-14** | `User.delete-account` leaves files on disk | GDPR violation (right to erasure) |
| **SEC-15** | `Friendship` model stores rejected requests forever | Privacy concern, no data cleanup |
| **SEC-16** | Error messages expose internal details: `res.status(500).json({ error: err.message })` | Stack traces can leak to clients |

---

## 8. 🔄 ALTERNATIVES — What Wasn't Considered

### Architecture Alternatives

| Current Approach | Better Alternative | Why It Matters |
|-----------------|-------------------|----------------|
| **Polling for leaderboard updates** | **WebSocket/SSE** for real-time updates | Dancing is real-time. A leaderboard that updates every 30s (poll interval) is boring. WebSocket would make it feel alive. `socket.io` adds 2 dependencies. |
| **Pedometer for dance tracking** | **Accelerometer ML model** (on-device TensorFlow Lite) | Pedometers detect walking. Dancing is fundamentally different. A simple TFLite pose classifier would be far more accurate and harder to cheat. |
| **Heuristic anti-cheat** | **Peer verification** (BLE nearby devices cross-validate movement patterns) or **video capture sampling** | The current system can't distinguish between a dancer and someone shaking their phone. Peer BLE verification ("was someone near me moving similarly?") would be hard to fake. |
| **Local disk file uploads** | **S3/R2/Cloudinary object storage** | Railway's disk is ephemeral. Uploaded images WILL be lost on redeploy. |
| **In-memory rate limiting** | **Redis for rate limiting + session store** | Server restart = all limits reset. Redis solves persistence AND provides a cache layer for leaderboard data. |
| **Monthly rank reset** | **Rolling 30-day window or seasonal resets** | Monthly reset on the 1st is arbitrary. A rolling window is always "last 30 days" and feels fairer. Or quarterly seasons with cosmetic rewards. |
| **Screen-on foreground tracking** | **Android Foreground Service + iOS Background Modes** | The app is useless if the phone is in a pocket with the screen off. This is how every fitness app (Strava, Nike Run Club) works. |
| **No real-time friend activity** | **Presence system** (online/offline/dancing status) | "My friend is dancing at X event RIGHT NOW" would drive engagement. Currently, the feed only shows COMPLETED sessions. |
| **Code-based event invites** | **Deep links + QR codes** | At a party, no one wants to type a 6-char code. A QR code on the DJ booth or a deep link `looped://event/abc123` shared via WhatsApp is frictionless. |

### Feature Alternatives

| Missing Feature | Value | Effort |
|----------------|-------|--------|
| **Dance Challenges** ("First to 1000 points wins") | High — creates urgency and social interaction | Medium |
| **Event Chat** (temporary chat room per event) | High — social glue during events | Medium |
| **Music Integration** (Spotify/Apple Music API to detect what's playing) | High — "danced 500 points to Daft Punk" is shareable | High |
| **Daily/Weekly goals** (not just monthly) | Medium — smaller dopamine hits | Low |
| **Team events** (2v2 or group vs group) | High — viral growth mechanic | High |
| **Ghost mode** (compete against your own past sessions) | Medium — practice mode, always available | Low |

---

## 9. 📝 MEMORY_CONSISTENCY — Documentation & Technical Debt

### What's Documented

✅ BACKLOG.md — Well-structured with priorities and agent assignments. Technical debt section exists.
✅ AGENTS.md — Clear agent roles and conventions. Good for AI-assisted development.
✅ README.md — Basic project overview, setup instructions, roadmap.
✅ Code comments — Some inline comments (e.g., anti-cheat rules are explained).
✅ Rank/badge definitions in `rankUtils.js` — Well-commented with Spanish descriptions.
✅ Streak utilities — Well-tested with `test_runner.js`.

### What's Missing

| Gap | Severity | Notes |
|-----|----------|-------|
| **No API documentation** | HIGH | No Swagger/OpenAPI. No Postman collection. No endpoint reference. A new developer (or agent) has to read ALL route files to understand the API. |
| **No .env.example** | CRITICAL | New developers don't know which env vars are required. README mentions `MONGODB_URI` and `PORT` but not `JWT_SECRET`, `GOOGLE_CLIENT_ID`. |
| **No database schema documentation** | MEDIUM | Mongoose models exist but no ERD, no relationship diagram, no index documentation, no migration strategy. |
| **No deployment runbook** | HIGH | How to deploy? Which Railway commands? How to set env vars in Railway? How to scale? No instructions. |
| **No CHANGELOG** | LOW | No version history. Can't track what changed between iterations. |
| **No logging framework** | MEDIUM | `console.log` and `console.error` only. No structured logging, no log levels, no request ID tracing, no error aggregation. Debugging production issues will be painful. |
| **No monitoring/alerting** | HIGH | No health check endpoint (`GET /` returns a static string — not useful). No error tracking (Sentry). No performance monitoring. |
| **No data retention policy** | MEDIUM | Sessions, events, and motion_stats accumulate forever. No TTL indexes. No archival strategy. MongoDB will grow unbounded. |

### Acknowledged Technical Debt (from BACKLOG.md)

| Item | Current Status | Risk if Ignored |
|------|---------------|-----------------|
| Input validation (Joi/Zod) | Not started | HIGH — already seeing unvalidated inputs in production code |
| Consistent error responses | Not started | MEDIUM — error format varies across routes |
| String localization | Not started | LOW — all UI strings are hardcoded (mostly English+Spanish mix) |
| Constants file | Not started | LOW — colors/sizes/URLs scattered |
| Structured logger | Not started | MEDIUM — will slow debugging |
| API documentation (Swagger) | Not started | MEDIUM — will slow onboarding |

### Express 5 Risk — NOT in Backlog

`package.json` shows `"express": "^5.2.1"`. Express 5.x is a major rewrite with breaking changes. The `.listen()` signature changed, middleware error handling changed. This was a deliberate choice but carries ongoing risk of API instability and ecosystem incompatibility (some middleware packages don't support Express 5). This risk is undocumented.

---

## 10. 🎯 FOUNDER_ALIGNMENT — Is This Gero's Path?

### Evidence of Alignment

✅ **Passion project DNA:** The rank names in Spanish ("El Fantasma", "Pistero", "Dueño del VIP"), badge concepts ("El Manija", "Superviviente del Finde"), and party-focused theme clearly come from someone who lives the culture. This is authentic.

✅ **MVP is functional:** Working auth (email + Google), event CRUD, session tracking, leaderboards, solo mode, social features. More complete than most side projects.

✅ **Personal branding:** README lists Geronimo Veglia with GitHub and LinkedIn. The project is publicly associated with its creator.

✅ **Fun over formality:** The emoji-based rank system, hydration reminders, Instagram sharing — this isn't a boring enterprise app. It has personality.

### Concerns

| Concern | Severity | Question to Answer |
|---------|----------|-------------------|
| **Is this solving a real problem?** | CRITICAL | Have you talked to 20+ people who go to parties and said "I wish I could compete on how much I dance"? Or is this a solution looking for a problem? |
| **Who is the target user?** | HIGH | The app seems targeted at Argentinian/Spanish-speaking young adults who go to electronic music events. Is this market large enough? Is this a global app or local? The code has Spanish rank names but English API messages. |
| **No monetization strategy** | HIGH | No ads, no subscriptions, no IAP, no premium features. The `is_paid_public` field exists in Event model but has zero payment integration. Is this a portfolio project or a business? |
| **No competitive analysis** | MEDIUM | Apps like Strava (fitness), Whoop (recovery), StepBet (gambling), and various dance challenge apps exist. Has any competitive landscape research been done? |
| **No user testing** | CRITICAL | Zero evidence of user testing. The anti-cheat thresholds, the pedometer-as-dance-tracker concept, the screen-on requirement — none of these have been validated with real users at real parties. |
| **No analytics** | MEDIUM | Without analytics, you can't measure retention, engagement, or feature usage. You're building blind. |
| **Scope creep risk** | MEDIUM | The backlog includes DJ dashboard, push notifications, map view, iOS release, etc. Without validation of the core hypothesis, expanding features is premature. |

### The Hard Question

**Is this a portfolio project or a startup?**

- If **portfolio:** Ship it, fix the Instagram sharing, put it on your resume, move on. Don't worry about scalability.
- If **startup:** Stop writing code. Validate the hypothesis FIRST. Get 50 people to use it at ONE party. Watch them. Ask them if they'd come back. The answer will tell you if any of this matters.

Right now, the code quality and feature depth suggest "serious hobby project" — more than a portfolio piece, less than a validated startup. The key decision is: **commit to validation or accept this as a learning project.**

---

## 🔢 RISK HEAT MAP

| Risk | Likelihood | Impact | Priority |
|------|-----------|--------|----------|
| Battery drain → churn | Near certain | CRITICAL | **1** |
| MongoDB down → total outage | Possible | CRITICAL | **2** |
| JWT_SECRET missing → auth collapse | Possible | CRITICAL | **2** |
| Anti-cheat false positives | Near certain | HIGH | **3** |
| No offline event tracking | Certain (at many venues) | HIGH | **4** |
| CORS open → CSRF | Possible | HIGH | **5** |
| Instagram sharing broken | Certain | MEDIUM | **6** |
| Frontend-only → no background tracking | Certain | HIGH | **7** |
| Rate limiting broken behind proxy | Near certain (Railway) | MEDIUM | **8** |
| Leaderboard aggregation won't scale | Probable at >1k users | MEDIUM | **9** |
| Reset code in console logs | Certain | HIGH | **10** |

---

## ✅ IMMEDIATE ACTIONS (Before Showing Anyone)

1. **Set JWT expiry:** Add `expiresIn: '7d'` to all `jwt.sign()` calls
2. **Restrict CORS:** Change `cors()` to `cors({ origin: ['looped-dance.com', 'localhost'] })`
3. **Die on startup if JWT_SECRET missing:** `if (!process.env.JWT_SECRET) { console.error('FATAL: JWT_SECRET not set'); process.exit(1); }`
4. **Remove password reset logging:** Delete the `console.log` block showing codes
5. **Add `.env.example`:** Document ALL required environment variables
6. **Fix Instagram appId:** Either implement real Instagram Basic Display API or remove the feature
7. **Add rate limiting on score endpoints:** `/sessions/stop`, `/solo/:id/finish`
8. **Add Helmet.js:** `npm install helmet && app.use(helmet())`
9. **Add MongoDB connection health check:** `GET /health` that checks `mongoose.connection.readyState`
10. **Fix trust proxy for rate limiting:** `app.set('trust proxy', 1)` for Railway

---

## 📊 SCORE SUMMARY

| Category | Grade | Notes |
|----------|-------|-------|
| Code Quality | B | Clean structure, good naming, consistent patterns. Some functions are too long (events route is 400+ lines). |
| Architecture | B- | REST is fine. Express is well-org'd. Flutter Provider pattern works. Missing: caching layer, background services, real-time comms. |
| Security | D+ | Critical gaps: JWT no expiry, open CORS, password reset code logged, no input validation, no security headers. |
| Scalability | D | MongoDB aggregation per-request, no caching, no indexes, no read replicas, in-memory rate limits. Breaks hard at 1k concurrent. |
| User Experience | C+ | Nice dark theme UI. But: requires phone out, screen on, battery drain, anti-cheat penalizes silently, Instagram doesn't work. |
| Market Validation | F | Zero evidence. No user testing, no competitive analysis, no analytics. Core hypothesis unvalidated. |
| Production Readiness | D- | No monitoring, no logging framework, ephemeral file storage, unstable Express version, no deployment docs. |
| Documentation | C | Good agent docs and backlog. Missing API docs, env vars, deployment runbook, database schema. |

**Overall Grade: C-**

The idea has genuine personality and the execution is solid for an MVP. But the technical foundations (security, scalability, offline reliability) are too weak for production, and the product foundations (user testing, market validation, core assumptions) are completely absent. Fix the security criticals NOW, then test with real users at ONE party before building anything else.

---

*Generated by Devil's Advocate agent. No diplomacy. Just truth.* 🔥
