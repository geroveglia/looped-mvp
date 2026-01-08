import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/motion_scoring_service.dart';
import '../services/solo_session_manager.dart';
import '../ui/app_theme.dart';

class SoloDanceScreen extends StatefulWidget {
  const SoloDanceScreen({super.key});

  @override
  State<SoloDanceScreen> createState() => _SoloDanceScreenState();
}

class _SoloDanceScreenState extends State<SoloDanceScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _isStopping = false;

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

    _startSession();
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
    final motionService =
        Provider.of<MotionScoringService>(context, listen: false);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      motionService.pause();
    } else if (state == AppLifecycleState.resumed) {
      motionService.resume();
    }
  }

  Future<void> _startSession() async {
    final soloManager = Provider.of<SoloSessionManager>(context, listen: false);
    final success = await soloManager.startSession();
    if (success) {
      _pulseController.repeat(reverse: true);
      _ringController.repeat();
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _stopSession() async {
    if (_isStopping) return;
    setState(() => _isStopping = true);

    _pulseController.stop();
    _ringController.stop();

    final soloManager = Provider.of<SoloSessionManager>(context, listen: false);
    try {
      await soloManager.stopSession();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isStopping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final soloManager = Provider.of<SoloSessionManager>(context);
    final motionService = Provider.of<MotionScoringService>(context);

    final points = soloManager.points;
    final isDancing = motionService.isDancing;
    final timeStr = soloManager.formattedTime;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => _stopSession(),
        ),
        title: Text('Solo Dancing', style: AppTheme.titleSmall),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Center(
                  child: _buildCircularDisplay(points, isDancing, timeStr),
                ),
              ),
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
              _buildStopButton(),
              const SizedBox(height: AppTheme.spacingLg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularDisplay(int points, bool isDancing, String timeStr) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _ringController]),
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.03);

        return Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(260, 260),
                painter: _CircularProgressPainter(
                  progress: _ringController.value,
                  color: AppTheme.accent.withOpacity(0.2),
                  strokeWidth: 6,
                ),
              ),
              CustomPaint(
                size: const Size(230, 230),
                painter: _CircularProgressPainter(
                  progress: (points % 100) / 100,
                  color: AppTheme.accent,
                  strokeWidth: 10,
                ),
              ),
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDancing
                      ? AppTheme.accent.withOpacity(0.1)
                      : AppTheme.surface,
                  border: Border.all(
                    color: isDancing
                        ? AppTheme.accent.withOpacity(0.3)
                        : AppTheme.surfaceBorder,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(timeStr,
                        style: AppTheme.displayLarge.copyWith(fontSize: 40)),
                    const SizedBox(height: AppTheme.spacingXs),
                    Text(
                      isDancing ? 'DANCING' : 'READY',
                      style: AppTheme.labelMedium.copyWith(
                        color: isDancing
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

  Widget _buildStopButton() {
    return GestureDetector(
      onTap: _stopSession,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isStopping ? AppTheme.surfaceLight : AppTheme.error,
          boxShadow: [
            BoxShadow(
              color: AppTheme.error.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: _isStopping
            ? const CircularProgressIndicator(color: AppTheme.textPrimary)
            : const Icon(Icons.stop, size: 40, color: Colors.white),
      ),
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

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, 2 * math.pi * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) => true;
}
