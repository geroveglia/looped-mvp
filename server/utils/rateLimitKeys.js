const jwt = require("jsonwebtoken");

// Budgets per 15-minute window.
// A dancer at a live event spends ~7 req/min (leaderboard poll every 15s,
// event refresh every 30s, session heartbeat every 60s) ≈ 105 per window, so
// AUTHED_LIMIT leaves roughly 5x headroom for moving around the app.
const AUTHED_LIMIT = 600;
// Anonymous traffic is only login/register/health, and it is the one bucket a
// whole venue still shares — enough for a crowd arriving at once, tight enough
// to bound credential stuffing from a single address.
const ANON_LIMIT = 120;
// Attempts against one account from one address before we say no.
const LOGIN_LIMIT = 30;

/// IPv6 clients get a whole range to themselves, so limiting an exact address
/// is pointless — collapse to the /64 the way express-rate-limit's own
/// ipKeyGenerator does (not exported in 7.5.x, hence the local copy).
function normalizeIp(req) {
  const raw = req.ip || req.socket?.remoteAddress || "unknown";
  if (!raw.includes(":")) return raw;
  return raw.split(":").slice(0, 4).join(":") + "::/64";
}

/// The app-wide limiter is mounted before any route, so the auth middleware
/// has not run yet and req.user does not exist — the token gets verified here
/// instead. Verifying rather than decoding is the point: a forged token would
/// otherwise mint a fresh bucket on every request and evade the limit outright.
function tokenUserId(req) {
  const header =
    typeof req.header === "function" ? req.header("Authorization") : null;
  const token = header ? header.replace("Bearer ", "") : null;
  if (!token) return null;

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    return payload && payload._id ? String(payload._id) : null;
  } catch (err) {
    // Expired or tampered with: this request falls back to the IP bucket.
    return null;
  }
}

/// Who this request counts against, memoized so the key and the budget don't
/// each verify the same token.
function identity(req) {
  if (req._rateLimitIdentity) return req._rateLimitIdentity;

  const userId = tokenUserId(req);
  const resolved = userId
    ? { userId, key: `user:${userId}` }
    : { userId: null, key: `ip:${normalizeIp(req)}` };

  req._rateLimitIdentity = resolved;
  return resolved;
}

/// Key for the app-wide limiter. Per user whenever we can tell who is asking:
/// at a party the whole crowd shares one venue WiFi or carrier NAT address, so
/// an IP bucket runs out exactly when the most people are dancing and takes
/// the live leaderboard down with it.
function requestKey(req) {
  return identity(req).key;
}

/// Budget for this request: a known user gets their own generous allowance,
/// anonymous traffic shares the venue's.
function requestLimit(req) {
  return identity(req).userId ? AUTHED_LIMIT : ANON_LIMIT;
}

/// Key for login and register. There is no identity to trust yet, so this
/// stays tied to the address, but scoped to the account being tried: a crowd
/// signing in from one venue must not spend each other's attempts, while a
/// single account is still protected from being guessed at. Rotating accounts
/// from one address remains bounded by the anonymous budget above.
function loginKey(req) {
  const account = String(req.body?.email || req.body?.username || "")
    .trim()
    .toLowerCase();
  const ip = normalizeIp(req);
  return account ? `login:${ip}:${account}` : `login:${ip}`;
}

module.exports = {
  requestKey,
  requestLimit,
  loginKey,
  normalizeIp,
  AUTHED_LIMIT,
  ANON_LIMIT,
  LOGIN_LIMIT,
};
