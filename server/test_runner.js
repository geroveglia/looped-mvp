const assert = require('assert');
const { getUTCDayDifference, checkAndResetStreak, updateStreak } = require('./utils/streakUtils');

console.log('🚀 Running Node.js backend unit tests...');

let testsPassed = 0;
let testsFailed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(` ✅ PASS: ${name}`);
    testsPassed++;
  } catch (err) {
    console.error(` ❌ FAIL: ${name}`);
    console.error(err);
    testsFailed++;
  }
}

// Queued rather than run inline: an async fn passed to test() would return a
// promise the try/catch never sees, so a failing assertion would pass silently.
const asyncTests = [];
function asyncTest(name, fn) {
  asyncTests.push([name, fn]);
}

async function runAsyncTests() {
  for (const [name, fn] of asyncTests) {
    try {
      await fn();
      console.log(` ✅ PASS: ${name}`);
      testsPassed++;
    } catch (err) {
      console.error(` ❌ FAIL: ${name}`);
      console.error(err);
      testsFailed++;
    }
  }
}

// ----------------------------------------------------
// Streak Utilities Tests
// ----------------------------------------------------

test('getUTCDayDifference should return 0 for same day calendar dates', () => {
  const d1 = new Date('2026-05-28T10:00:00Z');
  const d2 = new Date('2026-05-28T18:00:00Z');
  const diff = getUTCDayDifference(d1, d2);
  assert.strictEqual(diff, 0);
});

test('getUTCDayDifference should return 1 for consecutive calendar days', () => {
  const d1 = new Date('2026-05-28T22:00:00Z');
  const d2 = new Date('2026-05-29T02:00:00Z'); // Just 4 hours later, but next calendar day in UTC
  const diff = getUTCDayDifference(d1, d2);
  assert.strictEqual(diff, 1);
});

test('getUTCDayDifference should return larger differences correctly', () => {
  const d1 = new Date('2026-05-20T12:00:00Z');
  const d2 = new Date('2026-05-28T12:00:00Z');
  const diff = getUTCDayDifference(d1, d2);
  assert.strictEqual(diff, 8);
});

test('checkAndResetStreak should reset streak if last active was 2 days ago', () => {
  const user = {
    streak: 5,
    last_active_date: new Date('2026-05-26T12:00:00Z') // 2 days ago relative to 2026-05-28
  };
  
  // Temporarily override Date.now in streak calculation logic or pass current dates
  // Since checkAndResetStreak uses new Date(), let's adjust last_active_date to be 2 days ago relative to now.
  const twoDaysAgo = new Date();
  twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);
  user.last_active_date = twoDaysAgo;

  const modified = checkAndResetStreak(user);
  assert.strictEqual(modified, true);
  assert.strictEqual(user.streak, 0);
});

test('checkAndResetStreak should NOT reset streak if last active was today', () => {
  const user = {
    streak: 5,
    last_active_date: new Date()
  };

  const modified = checkAndResetStreak(user);
  assert.strictEqual(modified, false);
  assert.strictEqual(user.streak, 5);
});

test('updateStreak should initialize streak to 1 for new users', () => {
  const user = {
    streak: 0,
    last_active_date: null
  };

  updateStreak(user);
  assert.strictEqual(user.streak, 1);
  assert.ok(user.last_active_date instanceof Date);
});

test('updateStreak should increment streak by 1 on consecutive calendar days', () => {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);

  const user = {
    streak: 3,
    last_active_date: yesterday
  };

  updateStreak(user);
  assert.strictEqual(user.streak, 4);
});

test('updateStreak should keep streak unchanged on same-day sessions', () => {
  const today = new Date();
  const user = {
    streak: 3,
    last_active_date: today
  };

  updateStreak(user);
  assert.strictEqual(user.streak, 3);
});

// ----------------------------------------------------
// Rate Limit Key Tests
// ----------------------------------------------------
// The party case: dozens of phones behind one venue WiFi or carrier NAT.
// Keying the limiter by IP made them all share a single budget, so the live
// leaderboard cut out for the whole room at once.

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-for-rate-limit-keys';
const jwt = require('jsonwebtoken');
const {
  requestKey,
  requestLimit,
  loginKey,
  AUTHED_LIMIT,
  ANON_LIMIT,
} = require('./utils/rateLimitKeys');

function fakeReq({ token, ip = '190.0.0.1', body = {} } = {}) {
  return {
    ip,
    body,
    socket: { remoteAddress: ip },
    header: (name) =>
      name === 'Authorization' && token ? `Bearer ${token}` : undefined,
  };
}

function tokenFor(userId, options = {}) {
  return jwt.sign({ _id: userId }, process.env.JWT_SECRET, options);
}

test('requestKey buckets a signed-in dancer by their own id', () => {
  const req = fakeReq({ token: tokenFor('user-abc') });
  assert.strictEqual(requestKey(req), 'user:user-abc');
  assert.strictEqual(requestLimit(req), AUTHED_LIMIT);
});

test('requestKey gives two dancers on one IP separate buckets', () => {
  const shared = '200.5.5.5'; // one venue WiFi / carrier NAT address
  const first = fakeReq({ token: tokenFor('dancer-1'), ip: shared });
  const second = fakeReq({ token: tokenFor('dancer-2'), ip: shared });
  assert.notStrictEqual(requestKey(first), requestKey(second));
});

test('requestKey follows a dancer across networks', () => {
  const token = tokenFor('dancer-1');
  const onWifi = fakeReq({ token, ip: '200.5.5.5' });
  const onData = fakeReq({ token, ip: '181.9.9.9' });
  assert.strictEqual(requestKey(onWifi), requestKey(onData));
});

test('requestKey falls back to the IP bucket without a token', () => {
  const req = fakeReq({ ip: '190.0.0.7' });
  assert.strictEqual(requestKey(req), 'ip:190.0.0.7');
  assert.strictEqual(requestLimit(req), ANON_LIMIT);
});

test('requestKey refuses a forged token instead of minting a fresh bucket', () => {
  const forged = jwt.sign({ _id: 'attacker' }, 'not-the-real-secret');
  const req = fakeReq({ token: forged, ip: '190.0.0.9' });
  assert.strictEqual(requestKey(req), 'ip:190.0.0.9');
  assert.strictEqual(requestLimit(req), ANON_LIMIT);
});

test('requestKey treats an expired token as anonymous', () => {
  const stale = tokenFor('dancer-1', { expiresIn: '-1s' });
  const req = fakeReq({ token: stale, ip: '190.0.0.4' });
  assert.strictEqual(requestKey(req), 'ip:190.0.0.4');
});

test('requestKey collapses an IPv6 client to its /64', () => {
  const req = fakeReq({ ip: '2001:db8:85a3:1111:2222:3333:4444:5555' });
  assert.strictEqual(requestKey(req), 'ip:2001:db8:85a3:1111::/64');
});

test('requestKey resolves the identity once per request', () => {
  let headerReads = 0;
  const token = tokenFor('dancer-1');
  const req = {
    ip: '190.0.0.1',
    body: {},
    socket: {},
    header: (name) => {
      if (name === 'Authorization') headerReads++;
      return `Bearer ${token}`;
    },
  };
  requestKey(req);
  requestLimit(req);
  assert.strictEqual(headerReads, 1);
});

test('loginKey scopes attempts to the account, not just the venue', () => {
  const shared = '200.5.5.5';
  const ana = fakeReq({ ip: shared, body: { email: 'ana@looped.app' } });
  const beto = fakeReq({ ip: shared, body: { email: 'beto@looped.app' } });
  assert.notStrictEqual(loginKey(ana), loginKey(beto));
});

test('loginKey ignores case and padding in the account', () => {
  const a = fakeReq({ body: { email: '  Ana@Looped.app ' } });
  const b = fakeReq({ body: { email: 'ana@looped.app' } });
  assert.strictEqual(loginKey(a), loginKey(b));
});

test('loginKey falls back to the address when no account is sent', () => {
  const req = fakeReq({ ip: '190.0.0.2', body: {} });
  assert.strictEqual(loginKey(req), 'login:190.0.0.2');
});



// ----------------------------------------------------
// Leaderboard Standings Tests
// ----------------------------------------------------
// One aggregation now feeds the whole endpoint: the visible table, my points
// and my rank. These pin the arithmetic the three old aggregations produced.

const {
  buildStandings,
  positionOf,
} = require('./utils/leaderboardStandings');

// Grouped aggregation output: { _id: userId, points }, best first.
function totalsOf(...points) {
  return points.map((p, i) => ({ _id: `u${i}`, points: p }));
}

function usersFor(totals) {
  return totals.map((t) => ({
    _id: t._id,
    username: `dancer-${t._id}`,
    avatar_url: null,
  }));
}

function standingsOf(totals, { users, boardLimit } = {}) {
  return buildStandings({
    totals,
    users: users || usersFor(totals),
    boardLimit,
  });
}

test('buildStandings ranks the floor best first', () => {
  const standings = standingsOf(totalsOf(900, 500, 100));
  assert.strictEqual(standings.board.length, 3);
  assert.strictEqual(standings.board[0].points, 900);
  assert.strictEqual(standings.board[0].username, 'dancer-u0');
  assert.strictEqual(positionOf(standings, 'u0').rank, 1);
  assert.strictEqual(positionOf(standings, 'u2').rank, 3);
});

test('buildStandings gives tied dancers the same place', () => {
  // Competition ranking: 500, 500, 300 → 1st, 1st, 3rd.
  const standings = standingsOf(totalsOf(500, 500, 300));
  assert.strictEqual(positionOf(standings, 'u0').rank, 1);
  assert.strictEqual(positionOf(standings, 'u1').rank, 1);
  assert.strictEqual(positionOf(standings, 'u2').rank, 3);
});

test('buildStandings puts a dancer who has not scored behind everyone', () => {
  const standings = standingsOf(totalsOf(900, 500, 0));
  // Two dancers have points, so the next place is third.
  assert.strictEqual(standings.defaultRank, 3);
  assert.strictEqual(positionOf(standings, 'u2').rank, 3);
  // Someone who never started a session is not in the totals at all.
  assert.deepStrictEqual(positionOf(standings, 'nobody'), {
    rank: 3,
    points: 0,
  });
});

test('buildStandings caps the table but not the ranking', () => {
  // 60 dancers, a cut at 10: the ones below still get an honest position.
  const totals = totalsOf(...Array.from({ length: 60 }, (_, i) => 600 - i * 10));
  const standings = standingsOf(totals, { boardLimit: 10 });

  assert.strictEqual(standings.board.length, 10);
  assert.strictEqual(positionOf(standings, 'u59').rank, 60);
  assert.strictEqual(positionOf(standings, 'u59').points, 10);
});

test('buildStandings drops a dancer whose account is gone', () => {
  const totals = totalsOf(900, 500, 100);
  const users = usersFor(totals).filter((u) => u._id !== 'u1');
  const standings = standingsOf(totals, { users });

  // Off the visible table...
  assert.strictEqual(standings.board.length, 2);
  assert.ok(!standings.board.some((r) => r.user_id === 'u1'));
  // ...but still counted, so nobody below them silently gains a place.
  assert.strictEqual(positionOf(standings, 'u2').rank, 3);
});

test('buildStandings survives an event nobody has danced at yet', () => {
  const standings = standingsOf([]);
  assert.deepStrictEqual(standings.board, []);
  assert.strictEqual(positionOf(standings, 'u0').rank, 1);
});

// ----------------------------------------------------
// TTL Cache Tests
// ----------------------------------------------------

const { createTtlCache } = require('./utils/ttlCache');

/// A clock the test moves by hand — no sleeping to watch a TTL expire.
function fakeClock(start = 1000) {
  let t = start;
  return { now: () => t, advance: (ms) => (t += ms) };
}

asyncTest('ttlCache serves one computation to a burst of callers', async () => {
  const clock = fakeClock();
  const cache = createTtlCache({ ttlMs: 8000, now: clock.now });

  let runs = 0;
  const compute = async () => {
    runs++;
    await new Promise((r) => setImmediate(r)); // a real query takes a turn
    return 'board';
  };

  // Sixty phones polling a cold entry in the same instant.
  const answers = await Promise.all(
    Array.from({ length: 60 }, () => cache.get('event-1', compute))
  );

  assert.strictEqual(runs, 1);
  assert.ok(answers.every((a) => a === 'board'));
});

asyncTest('ttlCache reuses the answer inside the window', async () => {
  const clock = fakeClock();
  const cache = createTtlCache({ ttlMs: 8000, now: clock.now });

  let runs = 0;
  const compute = async () => ++runs;

  assert.strictEqual(await cache.get('event-1', compute), 1);
  clock.advance(7999);
  assert.strictEqual(await cache.get('event-1', compute), 1);
  assert.strictEqual(runs, 1);
});

asyncTest('ttlCache recomputes once the window closes', async () => {
  const clock = fakeClock();
  const cache = createTtlCache({ ttlMs: 8000, now: clock.now });

  let runs = 0;
  const compute = async () => ++runs;

  await cache.get('event-1', compute);
  clock.advance(8001);
  assert.strictEqual(await cache.get('event-1', compute), 2);
});

asyncTest('ttlCache keeps events apart', async () => {
  const clock = fakeClock();
  const cache = createTtlCache({ ttlMs: 8000, now: clock.now });

  assert.strictEqual(await cache.get('event-1', async () => 'a'), 'a');
  assert.strictEqual(await cache.get('event-2', async () => 'b'), 'b');
});

asyncTest('ttlCache never serves a failed query as an answer', async () => {
  const clock = fakeClock();
  const cache = createTtlCache({ ttlMs: 8000, now: clock.now });

  let attempts = 0;
  const flaky = async () => {
    attempts++;
    if (attempts === 1) throw new Error('mongo hiccup');
    return 'board';
  };

  await assert.rejects(() => cache.get('event-1', flaky), /mongo hiccup/);
  // Same instant, no TTL elapsed: the next caller must retry, not be handed
  // the rejection again.
  assert.strictEqual(await cache.get('event-1', flaky), 'board');
  assert.strictEqual(attempts, 2);
});

asyncTest('ttlCache drops entries for events that ended', async () => {
  const clock = fakeClock();
  const cache = createTtlCache({ ttlMs: 8000, now: clock.now });

  await cache.get('event-1', async () => 'a');
  await cache.get('event-2', async () => 'b');
  assert.strictEqual(cache.size, 2);

  clock.advance(8001);
  cache.prune();
  assert.strictEqual(cache.size, 0);
});

// ----------------------------------------------------
// Event access & history tests
// ----------------------------------------------------

const { eventAccess, viewEvent } = require('./utils/eventAccess');
const { summarizeSessions, sessionSeconds } = require('./utils/eventHistory');

const HOST = 'host-1';
const GUEST = 'guest-1';
const STRANGER = 'stranger-1';

function privateEvent() {
  return { host_user_id: HOST, visibility: 'private', invite_code: 'ABC123', name: 'Sótano' };
}
function publicEvent() {
  return { host_user_id: HOST, visibility: 'public', name: 'Plaza' };
}

test('a stranger cannot open a private event they were never invited to', () => {
  const access = eventAccess(privateEvent(), { membership: null, userId: STRANGER });
  assert.strictEqual(access.allowed, false);
});

test('any signed-in dancer can open a public event', () => {
  const access = eventAccess(publicEvent(), { membership: null, userId: STRANGER });
  assert.strictEqual(access.allowed, true);
});

test('the host can open their own private event without a membership row', () => {
  const access = eventAccess(privateEvent(), { membership: null, userId: HOST });
  assert.strictEqual(access.allowed, true);
  assert.strictEqual(access.canSeeInviteCode, true);
});

test('someone who left a private party can still look back at it', () => {
  const membership = { role: 'member', left_at: new Date('2026-08-01T04:00:00Z') };
  const access = eventAccess(privateEvent(), { membership, userId: GUEST });
  assert.strictEqual(access.allowed, true);
  assert.strictEqual(access.isActiveMember, false);
});

test('but they can no longer hand out the invite code', () => {
  const membership = { role: 'member', left_at: new Date('2026-08-01T04:00:00Z') };
  const access = eventAccess(privateEvent(), { membership, userId: GUEST });
  assert.strictEqual(access.canSeeInviteCode, false);
  assert.strictEqual(viewEvent(privateEvent(), access).invite_code, undefined);
});

test('a member still inside keeps the code so they can invite friends', () => {
  const access = eventAccess(privateEvent(), { membership: { role: 'member' }, userId: GUEST });
  assert.strictEqual(access.canSeeInviteCode, true);
  assert.strictEqual(viewEvent(privateEvent(), access).invite_code, 'ABC123');
});

test('viewEvent does not mutate the document it redacts', () => {
  const event = privateEvent();
  const access = eventAccess(event, { membership: null, userId: HOST });
  viewEvent(event, { ...access, canSeeInviteCode: false });
  assert.strictEqual(event.invite_code, 'ABC123');
});

test('summarizeSessions adds up the tandas of one party', () => {
  const summary = summarizeSessions([
    { points: 400, duration_sec: 600, started_at: '2026-08-01T02:00:00Z', ended_at: '2026-08-01T02:10:00Z' },
    { points: 950, duration_sec: 1200, started_at: '2026-08-01T03:00:00Z', ended_at: '2026-08-01T03:20:00Z' },
  ]);

  assert.strictEqual(summary.sessions_count, 2);
  assert.strictEqual(summary.points, 1350);
  assert.strictEqual(summary.dance_seconds, 1800);
  assert.strictEqual(summary.best_session_points, 950);
  assert.strictEqual(summary.is_dancing, false);
  assert.strictEqual(summary.first_danced_at.toISOString(), '2026-08-01T02:00:00.000Z');
  assert.strictEqual(summary.last_danced_at.toISOString(), '2026-08-01T03:00:00.000Z');
});

test('summarizeSessions returns zeroes for a party the dancer never danced at', () => {
  const summary = summarizeSessions([]);
  assert.strictEqual(summary.sessions_count, 0);
  assert.strictEqual(summary.points, 0);
  assert.strictEqual(summary.dance_seconds, 0);
  assert.strictEqual(summary.first_danced_at, null);
});

test('an open session counts up to now and flags the dancer as on the floor', () => {
  const now = new Date('2026-08-01T02:05:00Z');
  const summary = summarizeSessions(
    [{ points: 120, started_at: '2026-08-01T02:00:00Z' }],
    { now }
  );

  assert.strictEqual(summary.dance_seconds, 300);
  assert.strictEqual(summary.is_dancing, true);
});

test('a session the sweep closed without a duration is measured from the clock', () => {
  const seconds = sessionSeconds(
    { started_at: '2026-08-01T02:00:00Z', ended_at: '2026-08-01T02:07:30Z', auto_closed: true },
    new Date('2026-08-01T05:00:00Z')
  );
  assert.strictEqual(seconds, 450);
});

test('summarizeSessions ignores negative points instead of subtracting them', () => {
  const summary = summarizeSessions([
    { points: 500, duration_sec: 60, started_at: '2026-08-01T02:00:00Z', ended_at: '2026-08-01T02:01:00Z' },
    { points: -900, duration_sec: 60, started_at: '2026-08-01T02:02:00Z', ended_at: '2026-08-01T02:03:00Z' },
  ]);
  assert.strictEqual(summary.points, 500);
});

runAsyncTests().then(() => {
  console.log('\n--- TEST RUN SUMMARY ---');
  console.log(` 🎉 Passed: ${testsPassed}`);
  console.log(` 🛑 Failed: ${testsFailed}`);

  if (testsFailed > 0) {
    process.exit(1);
  } else {
    console.log(' ✅ All tests executed successfully!');
    process.exit(0);
  }
});
