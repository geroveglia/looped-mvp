import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dance_session_manager.dart';
import '../ui/app_theme.dart';
import 'session_stats_screen.dart';

class LiveDanceScreen extends StatefulWidget {
  final String eventId;

  const LiveDanceScreen({super.key, required this.eventId});

  @override
  State<LiveDanceScreen> createState() => _LiveDanceScreenState();
}

class _LiveDanceScreenState extends State<LiveDanceScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreSession();
    Future.microtask(() {
      if (mounted) {
        Provider.of<DanceSessionManager>(context, listen: false)
            .isOnDanceScreen = true;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final manager = Provider.of<DanceSessionManager>(context, listen: false);
    manager.isOnDanceScreen = false;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Rely on global manager for pause logic
    final manager = Provider.of<DanceSessionManager>(context, listen: false);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      manager.pauseSession();
    }
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
                eventName: eventName ?? 'Event Session',
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
                  color: Colors.grey,
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
                const Text('LIVE',
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
                  color: Color(0xFF1E1E1E), shape: BoxShape.circle),
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
                      backgroundColor: const Color(0xFF131313),
                      valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('STEPS',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      Text(
                        manager.steps.toString().replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.trending_up,
                              color: AppTheme.accent, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${(manager.steps / 100).clamp(0, 100).toStringAsFixed(0)}% OF GOAL',
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
                      Row(
                        children: [
                          Expanded(
                              child: _buildNewStatCard(
                                  'CALORIES',
                                  manager.calories.toString(),
                                  Icons.local_fire_department,
                                  'KCAL')),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _buildNewStatCard('TIME',
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
                                  'INTENSITY',
                                  isHighIntensity ? 'HIGH' : 'LOW',
                                  Icons.bolt,
                                  '',
                                  isIntensity: true)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Active Ranking Card
                      Container(
                        width: double.infinity,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF121212),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: const Stack(
                          children: [
                            // Faded right side image mock
                            Positioned(
                              right: -20,
                              top: 0,
                              bottom: 0,
                              child: Opacity(
                                opacity: 0.3,
                                child: Icon(Icons.directions_run,
                                    color: AppTheme.accent, size: 120),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('ACTIVE RANKING',
                                      style: TextStyle(
                                          color: AppTheme.accent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1)),
                                  SizedBox(height: 4),
                                  Text('#12 in Global Daily Challenge',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Sticky Button at bottom
              SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _stopSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.stop_circle, color: Colors.black),
                    label: const Text('FINISH SESSION',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  )),
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
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.grey,
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
                      color: Colors.grey,
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
}
