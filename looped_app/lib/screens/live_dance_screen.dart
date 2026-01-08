import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/event_service.dart';
import '../services/motion_scoring_service.dart';
import '../services/dance_session_manager.dart';
import '../ui/app_theme.dart';

class LiveDanceScreen extends StatefulWidget {
  final String eventId;

  const LiveDanceScreen({super.key, required this.eventId});

  @override
  State<LiveDanceScreen> createState() => _LiveDanceScreenState();
}

class _LiveDanceScreenState extends State<LiveDanceScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  String? _sessionId;
  int _seconds = 0;
  Timer? _timer;
  bool _isStopping = false;
  bool _isActive = false;

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
    try {
      final motionService =
          Provider.of<MotionScoringService>(context, listen: false);
      motionService.stop();
    } catch (e) {}
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveSession();
      Provider.of<MotionScoringService>(context, listen: false).pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_isActive) {
        Provider.of<MotionScoringService>(context, listen: false).resume();
      }
    }
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEventId = prefs.getString('saved_event_id');
    final savedSessionId = prefs.getString('saved_session_id');

    if (savedEventId == widget.eventId && savedSessionId != null) {
      final savedPoints = prefs.getInt('saved_points') ?? 0;
      final savedStart =
          DateTime.tryParse(prefs.getString('saved_start_time') ?? '') ??
              DateTime.now();

      setState(() {
        _sessionId = savedSessionId;
        _isActive = true;
        _seconds = DateTime.now().difference(savedStart).inSeconds;
      });

      final motionService =
          Provider.of<MotionScoringService>(context, listen: false);
      motionService.restore(savedPoints, savedStart);

      _startTimer();
      _pulseController.repeat(reverse: true);
      _ringController.repeat();
    }
  }

  Future<void> _saveSession() async {
    if (!_isActive || _sessionId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final motionService =
        Provider.of<MotionScoringService>(context, listen: false);

    await prefs.setString('saved_event_id', widget.eventId);
    await prefs.setString('saved_session_id', _sessionId!);
    await prefs.setInt('saved_points', motionService.currentPoints);
    await prefs.setString('saved_start_time',
        DateTime.now().subtract(Duration(seconds: _seconds)).toIso8601String());
  }

  Future<void> _clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_event_id');
    await prefs.remove('saved_session_id');
    await prefs.remove('saved_points');
    await prefs.remove('saved_start_time');
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _startSession() async {
    setState(() => _isActive = true);
    _pulseController.repeat(reverse: true);
    _ringController.repeat();

    final eventService = Provider.of<EventService>(context, listen: false);
    final motionService =
        Provider.of<MotionScoringService>(context, listen: false);

    try {
      _sessionId = await eventService.startSession(widget.eventId);
      motionService.start();
      _seconds = 0;
      _startTimer();
      _saveSession();

      if (mounted) {
        Provider.of<DanceSessionManager>(context, listen: false)
            .syncFromLiveDance(
          isDancing: true,
          sessionId: _sessionId,
          eventId: widget.eventId,
          eventName: 'Event',
          points: 0,
          elapsedSeconds: 0,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isActive = false);
        _pulseController.stop();
        _ringController.stop();
      }
    }
  }

  Future<void> _stopSession() async {
    if (_isStopping || _sessionId == null) return;
    setState(() => _isStopping = true);

    _clearSavedSession();
    _pulseController.stop();
    _ringController.stop();

    Provider.of<DanceSessionManager>(context, listen: false)
        .syncFromLiveDance(isDancing: false);

    final eventService = Provider.of<EventService>(context, listen: false);
    final motionService =
        Provider.of<MotionScoringService>(context, listen: false);

    motionService.stop();
    _timer?.cancel();

    final results = motionService.getSessionResults();
    final points = results['points'] as int;
    final duration = results['duration_sec'] as int;

    try {
      final response =
          await eventService.stopSession(_sessionId!, points, duration);

      if (mounted) {
        if (response['level_up'] == true) {
          await _showLevelUpDialog(response['new_level']);
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isStopping = false);
      }
    }
  }

  Future<void> _showLevelUpDialog(int newLevel) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text("LEVEL UP!",
            style: AppTheme.titleLarge.copyWith(color: AppTheme.warning)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, color: AppTheme.warning, size: 64),
            const SizedBox(height: AppTheme.spacingLg),
            Text("You reached Level $newLevel!", style: AppTheme.bodyLarge),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text("AWESOME"),
          )
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final motionService = Provider.of<MotionScoringService>(context);
    final points = motionService.currentPoints;
    final isDancing = motionService.isDancing;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
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
                  child: _buildCircularDisplay(points, isDancing),
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
                    _buildStatItem(
                        'TIME', _formatTime(_seconds), AppTheme.warning),
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
              _isActive ? _buildStopButton() : _buildStartButton(),

              const SizedBox(height: AppTheme.spacingLg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularDisplay(int points, bool isDancing) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _ringController]),
      builder: (context, child) {
        final scale = _isActive ? 1.0 + (_pulseController.value * 0.03) : 1.0;

        return Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring
              CustomPaint(
                size: const Size(260, 260),
                painter: _CircularProgressPainter(
                  progress: _isActive ? _ringController.value : 0,
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
                    Text(
                      _formatTime(_seconds),
                      style: AppTheme.displayLarge.copyWith(fontSize: 40),
                    ),
                    const SizedBox(height: AppTheme.spacingXs),
                    Text(
                      _isActive
                          ? (isDancing ? 'DANCING' : 'WAITING...')
                          : 'READY',
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

  Widget _buildStopButton() {
    return GestureDetector(
      onTap: _isStopping ? null : _stopSession,
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
