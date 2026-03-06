import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dance_session_manager.dart';
import '../ui/app_theme.dart';
import 'session_stats_screen.dart';

class SoloDanceScreen extends StatefulWidget {
  const SoloDanceScreen({super.key});

  @override
  State<SoloDanceScreen> createState() => _SoloDanceScreenState();
}

class _SoloDanceScreenState extends State<SoloDanceScreen>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final manager = Provider.of<DanceSessionManager>(context, listen: false);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      manager.pauseSession();
    }
  }

  Future<void> _startSession() async {
    final manager = Provider.of<DanceSessionManager>(context, listen: false);
    if (!manager.isDancing) {
      final success = await manager.startSession(type: SessionType.solo);
      if (!success) {
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  void _explicitStop() async {
    final manager = Provider.of<DanceSessionManager>(context, listen: false);
    final stats = await manager.stopSession();

    if (mounted) {
      if (stats != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SessionStatsScreen(
              stats: stats,
              eventName: 'Solo Session',
            ),
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<DanceSessionManager>(context);
    final isPaused = manager.isPaused;
    final timeStr = manager.formattedTime;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Solo Session',
          style: AppTheme.titleMedium.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.music_note, color: Colors.white, size: 20),
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings, color: Colors.white, size: 20),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Large Timer
            Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.w400,
                letterSpacing: 2,
              ),
            ),
            const Text(
              'DURATION',
              style: TextStyle(
                color: AppTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            
            // Stats Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.8,
                  children: [
                    _buildStatCard(
                      icon: Icons.map,
                      label: 'DISTANCE',
                      value: manager.distanceKm.toStringAsFixed(2),
                      unit: 'km',
                    ),
                    _buildStatCard(
                      icon: Icons.speed,
                      label: 'SPEED',
                      value: manager.speedKmh.toStringAsFixed(1),
                      unit: 'km/h',
                    ),
                    _buildStatCard(
                      icon: Icons.directions_run,
                      label: 'STEPS',
                      value: manager.steps.toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},'),
                      unit: 'steps',
                      isHighlighted: true,
                    ),
                    _buildStatCard(
                      icon: Icons.timer,
                      label: 'PACE',
                      value: manager.pace,
                      unit: 'min/km',
                    ),
                    _buildStatCard(
                      icon: Icons.terrain,
                      label: 'ELEVATION',
                      value: manager.elevation.toString(),
                      unit: 'm',
                    ),
                    _buildStatCard(
                      icon: Icons.local_fire_department,
                      label: 'CALORIES',
                      value: manager.calories.toString(),
                      unit: 'kcal',
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Controls
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildControlButton(
                      label: isPaused ? 'RESUME' : 'PAUSE',
                      onPressed: () {
                        if (isPaused) {
                          manager.resumeSession();
                        } else {
                          manager.pauseSession();
                        }
                      },
                      color: const Color(0xFF1A1A1A),
                      textColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildControlButton(
                      label: 'FINISH',
                      onPressed: _explicitStop,
                      color: const Color(0xFFFF4433),
                      textColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: isHighlighted
            ? Border.all(color: AppTheme.accent.withOpacity(0.5), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: isHighlighted ? AppTheme.accent : Colors.white60, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isHighlighted ? AppTheme.accent : Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
    required Color textColor,
  }) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
