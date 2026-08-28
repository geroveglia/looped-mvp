import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/leaderboard_model.dart';
import '../models/live_standings.dart';
import '../services/auth_service.dart';
import '../services/dance_session_manager.dart';
import '../services/leaderboard_service.dart';
import '../ui/app_theme.dart';
import '../ui/animations/animated_counter.dart';
import 'session_stats_screen.dart';

class LiveDanceScreen extends StatefulWidget {
  final String eventId;

  const LiveDanceScreen({super.key, required this.eventId});

  @override
  State<LiveDanceScreen> createState() => _LiveDanceScreenState();
}

class _LiveDanceScreenState extends State<LiveDanceScreen> {
  // NOTE: the session deliberately keeps running when the app is backgrounded
  // or the screen is locked — that's the core party use case (phone in pocket).
  // The pedometer keeps counting; MotionScoringService pauses only the
  // battery-hungry accel/gyro streams via its own lifecycle observer, and
  // elapsed time is wall-clock based so it survives background freezes.
  DanceSessionManager? _manager;

  // Needed to pick my own row out of the standings.
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _restoreSession();
    Future.microtask(() {
      if (mounted) {
        Provider.of<DanceSessionManager>(context, listen: false)
            .isOnDanceScreen = true;
        // The event detail screen underneath is normally already polling this
        // event; ensurePolling() joins that timer instead of opening a second
        // one. Deliberately never stopped here — the screen below owns it.
        Provider.of<LeaderboardService>(context, listen: false)
            .ensurePolling(widget.eventId);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _manager = Provider.of<DanceSessionManager>(context, listen: false);
    _myUserId = Provider.of<AuthService>(context, listen: false).userId;
  }

  @override
  void dispose() {
    _manager?.isOnDanceScreen = false;
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final manager = Provider.of<DanceSessionManager>(context, listen: false);
    if (!manager.isDancing) {
      await manager.restoreFromStorage();
    }
  }

  Future<void> _stopSession() async {
    final manager = Provider.of<DanceSessionManager>(context, listen: false);
    final eventName = manager.eventName;

    // User stops via UI.
    try {
      final stats = await manager.stopSession();
      if (mounted) {
        if (stats != null) {
          final finalStats = Map<String, dynamic>.from(stats)
            ..addAll({
              'steps': manager.steps,
              'distanceKm': manager.distanceKm,
              'speedKmh': manager.speedKmh,
              'pace': manager.pace,
              'elevation': manager.elevation,
              'calories': manager.calories,
            });

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SessionStatsScreen(
                stats: finalStats,
                eventName: eventName ?? 'Evento',
              ),
            ),
          );
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error stopping: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<DanceSessionManager>(context);
    final isPaused = manager.isPaused;

    // Derived stats for demo (or use values from manager if available)
    final bpm = 70 + (manager.points ~/ 20).clamp(0, 80);
    final isHighIntensity = bpm > 110;

    return Scaffold(
      backgroundColor: Colors.black, // Pure black background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Column(
          children: [
            Text(
              (manager.eventName ?? 'HIP HOP FREESTYLE').toUpperCase(),
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppTheme.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text('EN VIVO',
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                  color: AppTheme.surfaceLight, shape: BoxShape.circle),
              child: Icon(isPaused ? Icons.play_arrow : Icons.pause,
                  color: Colors.white, size: 16),
            ),
            onPressed: () {
              if (isPaused) {
                manager.resumeSession();
              } else {
                manager.pauseSession();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Circular Progress steps
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer subtle glow
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.15),
                          blurRadius: 40,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: CircularProgressIndicator(
                      value: manager.steps / 10000, // mock goal 10k
                      strokeWidth: 16,
                      backgroundColor: AppTheme.surface,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('PASOS',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      AnimatedCounter(
                        value: manager.steps,
                        format: (n) => n.toString().replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (manager.isCalibratingSteps)
                        const Text(
                          'CALIBRANDO SENSOR…',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.trending_up,
                                color: AppTheme.accent, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${(manager.steps / 100).clamp(0, 100).toStringAsFixed(0)}% DEL OBJETIVO',
                              style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Equalizer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 4,
                    height: [16.0, 24.0, 32.0, 24.0, 16.0][index],
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // Stats Grid
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Live standings first: the whole point of dancing at a
                      // party is watching yourself climb while it happens, so
                      // this must not sit below the fold behind the stat grid.
                      _buildLiveLeaderboard(manager),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: _buildNewStatCard(
                                  'CALORÍAS',
                                  manager.calories.toString(),
                                  Icons.local_fire_department,
                                  'KCAL')),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _buildNewStatCard('TIEMPO',
                                  manager.formattedTime, Icons.timer, '')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: _buildNewStatCard(
                                  'BPM', bpm.toString(), Icons.favorite, '',
                                  isBpm: true)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _buildNewStatCard(
                                  'INTENSIDAD',
                                  isHighIntensity ? 'ALTA' : 'BAJA',
                                  Icons.bolt,
                                  '',
                                  isIntensity: true)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Sticky Button at bottom
              CtaButton(
                label: 'TERMINAR SESIÓN',
                icon: Icons.stop_circle,
                danger: true,
                height: 60,
                onPressed: _stopSession,
              ),
              const SizedBox(height: 16), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewStatCard(
      String label, String value, IconData icon, String unit,
      {bool isBpm = false, bool isIntensity = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.textSecondary, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (isIntensity)
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Text(
                  value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ],
              if (isBpm) ...[
                const SizedBox(width: 6),
                const Icon(Icons.favorite, color: AppTheme.accent, size: 14),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Live standings, inside the dance screen. Rivals' points move once per
  /// poll (15s) and mine ship on the heartbeat (60s), so this reads as a
  /// scoreboard that ticks, not a real-time feed — enough to race someone.
  Widget _buildLiveLeaderboard(DanceSessionManager manager) {
    final lbService = Provider.of<LeaderboardService>(context);
    final data = lbService.currentData;

    if (data == null) {
      return _buildLeaderboardShell(
        children: [
          Text(
            lbService.error != null
                ? 'RANKING NO DISPONIBLE'
                : 'CARGANDO POSICIONES…',
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1),
          ),
        ],
      );
    }

    final standings = LiveStandings.from(
      data: data,
      localPoints: manager.points,
      myUserId: _myUserId,
    );
    final board = standings.board;

    if (standings.isEmpty) {
      return _buildLeaderboardShell(
        children: const [
          Text('PRIMERO EN LA PISTA',
              style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          SizedBox(height: 6),
          Text('Esperando a que otros empiecen a bailar',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      );
    }

    final myIndex = standings.myIndex;
    final freshness = _freshnessLabel(lbService.lastUpdatedAt);

    final rows = <Widget>[];
    int? previous;
    for (final i in standings.visibleRowIndexes) {
      if (previous != null && i > previous + 1) {
        rows.add(const Padding(
          padding: EdgeInsets.only(top: 6, left: 10),
          child: Text('⋯',
              style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ));
      }
      rows.add(_buildStandingRow(i + 1, board[i], i == myIndex));
      previous = i;
    }

    return _buildLeaderboardShell(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('#${standings.myRank}',
                style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('DE ${board.length} EN LA PISTA',
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ),
            if (freshness.isNotEmpty)
              Text(freshness,
                  style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _gapLabel(standings),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: standings.amLeading
                  ? AppTheme.accent
                  : AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ...rows,
      ],
    );
  }

  String _gapLabel(LiveStandings standings) {
    if (standings.amLeading) return 'VAS PRIMERO — NO AFLOJES';
    final diff = standings.pointsToAhead;
    if (diff == null) return 'SEGUÍ BAILANDO PARA SUBIR';
    return 'A ${_formatPoints(diff)} PTS DE '
        '${standings.ahead!.username.toUpperCase()}';
  }

  Widget _buildLeaderboardShell({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events, color: AppTheme.accent, size: 14),
              SizedBox(width: 8),
              Text('RANKING EN VIVO',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStandingRow(int position, LeaderboardEntry entry, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppTheme.accent.withOpacity(0.10) : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? AppTheme.accent.withOpacity(0.5)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('$position',
                style: TextStyle(
                    color:
                        position <= 3 ? AppTheme.accent : AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(
              isMe ? '${entry.username} · VOS' : entry.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: isMe ? Colors.white : AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: isMe ? FontWeight.bold : FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Text(_formatPoints(entry.points),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          const Text('PTS',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }


  String _freshnessLabel(DateTime? updatedAt) {
    if (updatedAt == null) return '';
    final seconds = DateTime.now().difference(updatedAt).inSeconds;
    if (seconds < 20) return 'AHORA';
    if (seconds < 60) return 'HACE ${seconds}S';
    return 'HACE ${seconds ~/ 60}MIN';
  }

  String _formatPoints(int value) {
    return value.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}
