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

console.log('\n--- TEST RUN SUMMARY ---');
console.log(` 🎉 Passed: ${testsPassed}`);
console.log(` 🛑 Failed: ${testsFailed}`);

if (testsFailed > 0) {
  process.exit(1);
} else {
  console.log(' ✅ All tests executed successfully!');
  process.exit(0);
}
