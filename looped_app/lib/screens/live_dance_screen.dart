import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/motion_scoring_service.dart';
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
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _restoreSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _ringController.dispose();
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
    // Manager handles restoration globally usually, but if we opened this screen specifically...
    // Actually, manager.restoreFromStorage() is called at app start or we can call it here.
    // If the manager is already dancing, we just sync UI.
    // If not, we might be starting fresh or restoring.
    final manager = Provider.of<DanceSessionManager>(context, listen: false);
    if (!manager.isDancing) {
      await manager.restoreFromStorage();
    }

    if (manager.isDancing) {
      _pulseController.repeat(reverse: true);
      _ringController.repeat();
    }
  }

  Future<void> _startSession() async {
    final manager = Provider.of<DanceSessionManager>(context, listen: false);
    if (manager.isDancing) return;

    final success = await manager.startSession(
        type: SessionType.event,
        eventId: widget.eventId,
        eventName: 'Event' // We could fetch name if needed
        );

    if (success) {
      _pulseController.repeat(reverse: true);
      _ringController.repeat();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to start session")));
      }
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
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SessionStatsScreen(
                stats: stats,
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
    final motionService = Provider.of<MotionScoringService>(context);

    final points = manager.points;
    final isDancing = manager
        .isDancing; // We show dancing state even if paused, but maybe visually distinct?
    final isPaused = manager.isPaused;
    final timeStr = manager.formattedTime;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(), // Just leave screen
        ),
        title: const Text('Dancing', style: AppTheme.titleSmall),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            children: [
              // Main circular display
              Expanded(
                flex: 3,
                child: Center(
                  child: _buildCircularDisplay(
                      points, isDancing, isPaused, timeStr),
                ),
              ),

              // Stats cards
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: AppTheme.cardDecoration,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                        'POINTS', points.toString(), AppTheme.accent),
                    Container(
                        width: 1, height: 40, color: AppTheme.surfaceBorder),
                    _buildStatItem('TIME', timeStr, AppTheme.warning),
                    Container(
                        width: 1, height: 40, color: AppTheme.surfaceBorder),
                    _buildStatItem(
                        'PPS',
                        motionService.currentPointsPerSec.toStringAsFixed(1),
                        AppTheme.info),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingXl),

              // Control button
              isDancing ? _buildControlButtons(manager) : _buildStartButton(),

              const SizedBox(height: AppTheme.spacingLg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularDisplay(
      int points, bool isDancing, bool isPaused, String timeStr) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _ringController]),
      builder: (context, child) {
        final scale = (isDancing && !isPaused)
            ? 1.0 + (_pulseController.value * 0.03)
            : 1.0;

        return Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring
              CustomPaint(
                size: const Size(260, 260),
                painter: _CircularProgressPainter(
                  progress:
                      (isDancing && !isPaused) ? _ringController.value : 0,
                  color: AppTheme.accent.withOpacity(0.2),
                  strokeWidth: 6,
                ),
              ),

              // Progress ring
              CustomPaint(
                size: const Size(230, 230),
                painter: _CircularProgressPainter(
                  progress: (points % 100) / 100,
                  color: AppTheme.accent,
                  strokeWidth: 10,
                ),
              ),

              // Center content
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDancing && !isPaused)
                      ? AppTheme.accent.withOpacity(0.1)
                      : AppTheme.surface,
                  border: Border.all(
                    color: (isDancing && !isPaused)
                        ? AppTheme.accent.withOpacity(0.3)
                        : AppTheme.surfaceBorder,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      timeStr,
                      style: AppTheme.displayLarge.copyWith(fontSize: 40),
                    ),
                    const SizedBox(height: AppTheme.spacingXs),
                    Text(
                      isDancing ? (isPaused ? 'PAUSED' : 'DANCING') : 'READY',
                      style: AppTheme.labelMedium.copyWith(
                        color: (isDancing && !isPaused)
                            ? AppTheme.accent
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppTheme.titleLarge.copyWith(color: color)),
        const SizedBox(height: AppTheme.spacingXs),
        Text(label, style: AppTheme.labelSmall),
      ],
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: _startSession,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.accent,
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child:
            const Icon(Icons.play_arrow, size: 40, color: AppTheme.background),
      ),
    );
  }

  Widget _buildControlButtons(DanceSessionManager manager) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Play/Pause
        GestureDetector(
          onTap: () {
            if (manager.isPaused) {
              manager.resumeSession();
            } else {
              manager.pauseSession();
            }
          },
          child: Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surfaceLight,
              border: Border.all(color: AppTheme.accent),
            ),
            child: Icon(manager.isPaused ? Icons.play_arrow : Icons.pause,
                size: 40, color: AppTheme.accent),
          ),
        ),

        // Stop
        GestureDetector(
          onTap: _stopSession,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.error,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.error.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.stop, size: 40, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
