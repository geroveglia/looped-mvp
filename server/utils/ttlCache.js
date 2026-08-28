/// A tiny per-key cache for values that are expensive to compute and identical
/// for every caller.
///
/// The in-flight promise is stored, not just the settled value. That is the
/// part that matters under load: when sixty phones poll a cold key within the
/// same instant they all await one computation instead of starting sixty.
///
/// A rejected computation is evicted, so a failed query is never served as a
/// cached answer and the next caller retries.
function createTtlCache({ ttlMs, now = Date.now, maxEntries = 500 }) {
  const entries = new Map();

  function get(key, compute) {
    const k = String(key);
    const at = now();

    const hit = entries.get(k);
    if (hit && hit.expiresAt > at) return hit.value;

    // Counted from the start of the computation, so a slow query shortens its
    // own cache life rather than extending how stale an answer can get.
    const value = Promise.resolve()
      .then(compute)
      .catch((err) => {
        if (entries.get(k)?.value === value) entries.delete(k);
        throw err;
      });

    entries.set(k, { expiresAt: at + ttlMs, value });
    if (entries.size > maxEntries) prune(at);
    return value;
  }

  /// Drop expired keys — events end and their entries would otherwise linger.
  function prune(at = now()) {
    for (const [k, entry] of entries) {
      if (entry.expiresAt <= at) entries.delete(k);
    }
  }

  function invalidate(key) {
    entries.delete(String(key));
  }

  return { get, prune, invalidate, get size() {
    return entries.size;
  } };
}

module.exports = { createTtlCache };
