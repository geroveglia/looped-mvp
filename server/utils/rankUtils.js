/**
 * Rank System Utilities
 * Monthly ranks reset each month. Badges are permanent.
 */

const RANK_THRESHOLDS = [
  { rank: 'ghost',    min: 0,      name: 'El Fantasma',       emoji: '👻', color: '#6B7280', description: 'El que dice que va y cancela a último momento.' },
  { rank: 'rookie',   min: 5000,   name: 'Rookie de la Previa', emoji: '🛋️', color: '#39FF14', description: 'Sale, suma puntos, pero todavía le falta resistencia.' },
  { rank: 'pistero',  min: 20000,  name: 'Pistero',           emoji: '🔥', color: '#FF6B35', description: 'Constante. Activa multiplicadores y tiene buen PPS.' },
  { rank: 'vip',      min: 100000, name: 'Dueño del VIP',     emoji: '👑', color: '#FFD700', description: 'El alma de la fiesta. Sale jueves, viernes y sábado.' },
  { rank: 'immortal', min: null,   name: 'El Inmortal',       emoji: '⚡', color: '#FF00FF', description: 'La élite. Top 100 Global del Mes. Los que no duermen.' },
];

const BADGE_DEFINITIONS = {
  vampire:     { id: 'vampire',     name: 'El Vampiro',              emoji: '🦇', description: '+3 horas de movimiento después de las 3 AM.' },
  earthquake:  { id: 'earthquake',  name: 'Terremoto',               emoji: '🌪️', description: 'PPS máximo durante 10 minutos seguidos.' },
  manija:      { id: 'manija',      name: 'El Manija',               emoji: '🚀', description: 'Racha de 7 días consecutivos (lunes a lunes).' },
  globetrotter:{ id: 'globetrotter',name: 'Trotamundos',             emoji: '🌴', description: 'Eventos en 3 ciudades o países diferentes.' },
  weekend:     { id: 'weekend',     name: 'Superviviente del Finde',  emoji: '🧟', description: 'Triplete: viernes, sábado y domingo de la misma semana.' },
};

/**
 * Calculate rank based on monthly points.
 * "Immortal" requires being in Top 100 — handled separately.
 */
function calculateRank(monthlyPoints, isTop100 = false) {
  if (isTop100) return 'immortal';

  // Walk thresholds in reverse to find highest matching
  for (let i = RANK_THRESHOLDS.length - 2; i >= 0; i--) {
    if (monthlyPoints >= RANK_THRESHOLDS[i].min) {
      return RANK_THRESHOLDS[i].rank;
    }
  }
  return 'ghost';
}

/**
 * Get metadata for a rank.
 */
function getRankMeta(rank) {
  const found = RANK_THRESHOLDS.find(r => r.rank === rank);
  return found || RANK_THRESHOLDS[0];
}

/**
 * Get the next rank threshold info (for progress bars).
 */
function getNextRankInfo(currentRank, monthlyPoints) {
  const currentIdx = RANK_THRESHOLDS.findIndex(r => r.rank === currentRank);
  // If immortal or VIP (max before immortal), no "next" threshold
  if (currentIdx >= RANK_THRESHOLDS.length - 2) {
    // VIP → next is Immortal (Top 100 based, no fixed threshold)
    return { nextRank: 'immortal', pointsNeeded: null, progress: 1.0 };
  }

  const next = RANK_THRESHOLDS[currentIdx + 1];
  const current = RANK_THRESHOLDS[currentIdx];
  const range = next.min - current.min;
  const progress = Math.min(1.0, (monthlyPoints - current.min) / range);

  return {
    nextRank: next.rank,
    nextRankName: next.name,
    nextRankEmoji: next.emoji,
    pointsNeeded: next.min - monthlyPoints,
    progress: progress,
  };
}

/**
 * Check if we need to reset monthly points (new month).
 * If so, archive the old rank and reset.
 * Returns true if a reset happened.
 */
async function checkMonthReset(user) {
  const now = new Date();
  const lastUpdate = user.monthly_points_updated;

  if (!lastUpdate) {
    // First time — just set the date, no reset needed
    user.monthly_points_updated = now;
    return false;
  }

  const lastMonth = lastUpdate.getMonth();
  const lastYear = lastUpdate.getFullYear();
  const currentMonth = now.getMonth();
  const currentYear = now.getFullYear();

  if (lastMonth === currentMonth && lastYear === currentYear) {
    return false; // Same month, no reset
  }

  // --- Month changed! Archive and reset ---

  const monthNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
  const monthLabel = `${monthNames[lastMonth]} ${lastYear}`;

  const oldRank = user.rank || 'ghost';

  // Archive rank history
  if (!user.rank_history) user.rank_history = [];
  const historyEntry = {
    month: monthLabel,
    rank: oldRank,
    points: user.monthly_points || 0,
    badge_earned: false,
  };

  // VIP or Immortal survivors get commemorative badge
  if (oldRank === 'vip' || oldRank === 'immortal') {
    const survivorBadge = {
      id: `survivor_${lastYear}_${lastMonth}`,
      name: `Sobrevivió a ${monthLabel}`,
      emoji: oldRank === 'immortal' ? '⚡' : '👑',
      earned_at: now,
      description: `Terminó ${monthLabel} como ${getRankMeta(oldRank).name}.`,
    };

    if (!user.badges) user.badges = [];
    // Don't duplicate
    if (!user.badges.find(b => b.id === survivorBadge.id)) {
      user.badges.push(survivorBadge);
      historyEntry.badge_earned = true;
    }
  }

  // Immortal → Hall of Fame + bonus multiplier
  if (oldRank === 'immortal') {
    user.hall_of_fame = true;
    user.bonus_multiplier = 1.2; // 20% bonus to start next month
  } else {
    user.bonus_multiplier = 1.0;
  }

  user.rank_history.push(historyEntry);

  // Reset
  user.monthly_points = 0;
  user.rank = 'ghost';
  user.monthly_points_updated = now;

  return true;
}

/**
 * Add monthly points to a user and recalculate rank.
 * Call this after every session stop/finish.
 */
async function addMonthlyPoints(User, userId, points) {
  const user = await User.findById(userId);
  if (!user) return null;

  // Check month reset first
  await checkMonthReset(user);

  // Apply bonus multiplier (ex-Immortals)
  const effectivePoints = Math.round(points * (user.bonus_multiplier || 1.0));

  user.monthly_points = (user.monthly_points || 0) + effectivePoints;
  user.monthly_points_updated = new Date();

  // Recalculate rank (without Top 100 check — that's dynamic)
  user.rank = calculateRank(user.monthly_points);

  await user.save();

  return {
    monthly_points: user.monthly_points,
    rank: user.rank,
    effective_points: effectivePoints,
  };
}

module.exports = {
  RANK_THRESHOLDS,
  BADGE_DEFINITIONS,
  calculateRank,
  getRankMeta,
  getNextRankInfo,
  checkMonthReset,
  addMonthlyPoints,
};
