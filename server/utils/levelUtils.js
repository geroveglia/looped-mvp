/**
 * Curva de niveles.
 *
 * Única fuente de verdad: antes la fórmula estaba repetida en el cierre de
 * sesión, en /auth/me y en la pantalla de perfil, que es exactamente como
 * terminan desincronizadas.
 */

/**
 * XP necesario para pasar del nivel dado al siguiente.
 *
 * El primer nivel es barato a propósito. Con 1000 XP hacían falta unos 8
 * minutos de baile sostenido para ver la primera subida, o sea que la
 * primera recompensa no llegaba en la primera salida. Del 2 en adelante la
 * curva queda como estaba.
 */
function xpForLevel(level) {
    const lvl = Number(level) || 1;
    return lvl <= 1 ? 300 : 1000 * lvl;
}

module.exports = { xpForLevel };
