/**
 * Streak Calculation Utilities
 * Handles calendar-day streak calculations in UTC to avoid time-zone dependent issues.
 */

/**
 * Calculates the difference in UTC calendar days between two dates.
 * Returns the rounded difference in days.
 */
function getUTCDayDifference(date1, date2) {
    if (!date1 || !date2) return null;
    const d1 = new Date(date1);
    const d2 = new Date(date2);
    
    const midnight1 = Date.UTC(d1.getUTCFullYear(), d1.getUTCMonth(), d1.getUTCDate());
    const midnight2 = Date.UTC(d2.getUTCFullYear(), d2.getUTCMonth(), d2.getUTCDate());
    
    const diffMs = midnight2 - midnight1;
    return Math.round(diffMs / (1000 * 60 * 60 * 24));
}

/**
 * Checks if the user's streak has broken (inactive for more than 1 calendar day).
 * Resets user.streak to 0 if so.
 * Returns true if the user model was modified and needs to be saved.
 */
function checkAndResetStreak(user) {
    if (!user) return false;
    
    if (!user.last_active_date) {
        if (user.streak !== 0) {
            user.streak = 0;
            return true;
        }
        return false;
    }
    
    const now = new Date();
    const diff = getUTCDayDifference(user.last_active_date, now);
    
    if (diff !== null && diff > 1) {
        user.streak = 0;
        // Keep user.last_active_date as is so we know when they were last active,
        // but we reset the streak counter to 0.
        return true;
    }
    
    return false;
}

/**
 * Updates the user's streak and last active date upon completing a dance session.
 * - First session ever or after a break: sets streak to 1.
 * - Session on consecutive day: increments streak.
 * - Session on same day: keeps streak unchanged.
 */
function updateStreak(user) {
    if (!user) return;
    
    const now = new Date();
    
    if (!user.last_active_date) {
        user.streak = 1;
    } else {
        const diff = getUTCDayDifference(user.last_active_date, now);
        
        if (diff === null || diff > 1 || diff < 0) {
            // Racha rota o anomalía de fecha: reiniciar racha en 1 hoy
            user.streak = 1;
        } else if (diff === 1) {
            // Día calendario consecutivo: incrementar racha
            user.streak = (user.streak || 0) + 1;
        }
        // Si diff === 0 (mismo día calendario), dejamos el streak tal como está.
    }
    
    user.last_active_date = now;
}

module.exports = {
    getUTCDayDifference,
    checkAndResetStreak,
    updateStreak
};
