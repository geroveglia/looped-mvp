import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/my_event_stats.dart';
import '../services/event_service.dart';
import 'app_theme.dart';

/// "¿Qué hice yo en esta fiesta?" — the answer, for one event.
///
/// It lives in a sheet rather than a screen because it is always opened *from*
/// an event that is already on screen: the detail page and the final podium
/// both hang it off the party the dancer is already looking at.
Future<void> showMyEventStatsSheet(
  BuildContext context, {
  required String eventId,
  required String eventName,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => MyEventStatsSheet(eventId: eventId, eventName: eventName),
  );
}

class MyEventStatsSheet extends StatefulWidget {
  final String eventId;
  final String eventName;

  const MyEventStatsSheet({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<MyEventStatsSheet> createState() => _MyEventStatsSheetState();
}

class _MyEventStatsSheetState extends State<MyEventStatsSheet> {
  late Future<MyEventStats> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<MyEventStats> _load() =>
      Provider.of<EventService>(context, listen: false)
          .getMyEventStats(widget.eventId);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Tus stats',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(widget.eventName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<MyEventStats>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent));
                }
                if (snapshot.hasError) {
                  return _buildError('${snapshot.error}');
                }
                final stats = snapshot.data!;
                if (stats.neverDanced) return _buildNeverDanced(stats);
                return _buildStats(stats);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: AppTheme.textTertiary, size: 48),
          const SizedBox(height: AppTheme.spacingMd),
          Text(message, textAlign: TextAlign.center, style: AppTheme.bodySmall),
          const SizedBox(height: AppTheme.spacingMd),
          TextButton(
            onPressed: () => setState(() => _future = _load()),
            child: const Text('Reintentar',
                style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildNeverDanced(MyEventStats stats) {
    final joined = stats.joinedAt;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🕺', style: TextStyle(fontSize: 48)),
          const SizedBox(height: AppTheme.spacingMd),
          const Text('Te anotaste, pero no llegaste a bailar',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          if (joined != null) ...[
            const SizedBox(height: AppTheme.spacingSm),
            Text('Entraste el ${DateFormat('d MMM y').format(joined)}',
                style: AppTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildStats(MyEventStats stats) {
    final summary = stats.summary;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // The three numbers that answer the question on their own.
        Row(
          children: [
            Expanded(
              child: _bigStat(
                label: 'TU PUESTO',
                value: '#${stats.rank}',
                hint:
                    stats.totalDancers > 0 ? 'de ${stats.totalDancers}' : null,
                highlight: stats.isPodium,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigStat(
                label: 'PUNTOS',
                value: _thousands(summary.points),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigStat(
                label: 'BAILADO',
                value: formatDanceTime(summary.danceSeconds),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (summary.isDancing)
          _banner(Icons.bolt, 'Tenés una sesión abierta ahora mismo',
              AppTheme.accent),
        if (stats.leftAt != null)
          _banner(
              Icons.logout,
              'Saliste el ${DateFormat('d MMM y • HH:mm').format(stats.leftAt!)}',
              AppTheme.textSecondary),
        const SizedBox(height: 8),
        _detailRow('Sesiones', '${summary.sessionsCount}'),
        _detailRow(
            'Mejor sesión', '${_thousands(summary.bestSessionPoints)} pts'),
        if (summary.firstDancedAt != null)
          _detailRow('Primera vez',
              DateFormat('d MMM y • HH:mm').format(summary.firstDancedAt!)),
        if (summary.lastDancedAt != null && summary.sessionsCount > 1)
          _detailRow('Última vez',
              DateFormat('d MMM y • HH:mm').format(summary.lastDancedAt!)),
        const SizedBox(height: 24),
        const Text('TUS SESIONES',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const SizedBox(height: 12),
        ...stats.sessions.map(_sessionTile),
      ],
    );
  }

  Widget _bigStat({
    required String label,
    required String value,
    String? hint,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? AppTheme.accent.withOpacity(0.4)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(value,
                style: TextStyle(
                    color: highlight ? AppTheme.accent : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint,
                style:
                    const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
          ],
        ],
      ),
    );
  }

  Widget _banner(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _sessionTile(EventSession session) {
    final started = session.startedAt;
    // An open session has no duration yet — say so instead of printing "0m".
    final duration = session.isOpen
        ? 'en curso'
        : formatDanceTime(session.durationSec ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(session.isOpen ? Icons.bolt : Icons.music_note,
              color: session.isOpen ? AppTheme.accent : AppTheme.textSecondary,
              size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  started != null
                      ? DateFormat('d MMM • HH:mm').format(started)
                      : 'Sesión',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(duration, style: AppTheme.bodySmall),
              ],
            ),
          ),
          Text('${_thousands(session.points)} pts',
              style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _thousands(int value) => value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}
