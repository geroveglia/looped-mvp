import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/event_service.dart';
import '../services/motion_scoring_service.dart';
import '../services/dance_session_manager.dart';

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
  int _prevPoints = 0;

  // Animation controllers
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
      duration: const Duration(seconds: 2),
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
        _prevPoints = savedPoints;
      });

      final motionService =
          Provider.of<MotionScoringService>(context, listen: false);
      motionService.restore(savedPoints, savedStart);

      _startTimer();
      _pulseController.repeat(reverse: true);
      _ringController.repeat();

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Session Restored")));
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

      // Sync with global manager
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
        String message = "Error: $e";
        if (e.toString().contains("EVENT_NOT_ACTIVE")) {
          message = "Event is not active!";
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
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

    // Sync stop with global manager
    Provider.of<DanceSessionManager>(context, listen: false).syncFromLiveDance(
      isDancing: false,
    );

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
          await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: const Text("LEVEL UP!",
                        style: TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars, color: Colors.amber, size: 60),
                        const SizedBox(height: 20),
                        Text("You reached Level ${response['new_level']}!",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18)),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop();
                        },
                        child: const Text("AWESOME"),
                      )
                    ],
                  ));
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Dancing', style: TextStyle(color: Colors.white70)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Main circular display area
            Expanded(
              flex: 3,
              child: Center(
                child: _buildCircularDisplay(points, isDancing),
              ),
            ),

            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(
                      'POINTS', points.toString(), Colors.greenAccent),
                  _buildStatCard(
                      'TIME', _formatTime(_seconds), Colors.orangeAccent),
                  _buildStatCard(
                      'PPS',
                      motionService.currentPointsPerSec.toStringAsFixed(1),
                      Colors.purpleAccent),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Control button
            _isActive ? _buildStopButton() : _buildStartButton(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularDisplay(int points, bool isDancing) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer animated ring
        AnimatedBuilder(
          animation: _ringController,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(280, 280),
              painter: _CircularProgressPainter(
                progress: _isActive ? (_ringController.value) : 0,
                color: Colors.greenAccent.withOpacity(0.3),
                strokeWidth: 8,
              ),
            );
          },
        ),

        // Middle ring (progress based on points)
        CustomPaint(
          size: const Size(250, 250),
          painter: _CircularProgressPainter(
            progress: (points % 100) / 100,
            color: Colors.greenAccent,
            strokeWidth: 12,
          ),
        ),

        // Pulsing inner circle
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale =
                _isActive ? 1.0 + (_pulseController.value * 0.05) : 1.0;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDancing
                      ? Colors.greenAccent.withOpacity(0.15)
                      : Colors.white10,
                  border: Border.all(
                    color: isDancing ? Colors.greenAccent : Colors.white24,
                    width: 3,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatTime(_seconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w300,
                        fontFamily: 'Monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isActive
                          ? (isDancing ? 'DANCING' : 'WAITING...')
                          : 'READY',
                      style: TextStyle(
                        color: isDancing ? Colors.greenAccent : Colors.white54,
                        fontSize: 14,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'Monospace',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: _startSession,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.greenAccent,
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: const Icon(Icons.play_arrow, size: 50, color: Colors.black),
      ),
    );
  }

  Widget _buildStopButton() {
    return GestureDetector(
      onTap: _isStopping ? null : _stopSession,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isStopping ? Colors.grey : Colors.redAccent,
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: _isStopping
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.stop, size: 50, color: Colors.white),
      ),
    );
  }
}

// Custom painter for circular progress
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

    // Background circle
    final bgPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
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
