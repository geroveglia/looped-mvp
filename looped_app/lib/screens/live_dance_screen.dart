import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/event_service.dart';
import '../services/motion_scoring_service.dart';

class LiveDanceScreen extends StatefulWidget {
  final String eventId;

  const LiveDanceScreen({super.key, required this.eventId});

  @override
  State<LiveDanceScreen> createState() => _LiveDanceScreenState();
}

class _LiveDanceScreenState extends State<LiveDanceScreen>
    with WidgetsBindingObserver {
  String? _sessionId;
  int _seconds = 0;
  Timer? _timer;
  bool _isStopping = false;
  bool _showDebug = false;

  // State to track if we are "active" (session started)
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Safety check: ensure service stopped if user backs out explicitly (dispose)
    final motionService =
        Provider.of<MotionScoringService>(context, listen: false);
    motionService.stop();
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
      // Check if restoring is needed or just resume
      if (_isActive) {
        Provider.of<MotionScoringService>(context, listen: false).resume();
        // Optionally show snackbar "Session Resumed"
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Session Resumed"), duration: Duration(seconds: 1)));
      }
    }
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEventId = prefs.getString('saved_event_id');
    final savedSessionId = prefs.getString('saved_session_id');

    if (savedEventId == widget.eventId && savedSessionId != null) {
      // We have a saved session for this event
      final savedPoints = prefs.getInt('saved_points') ?? 0;
      final savedStart =
          DateTime.tryParse(prefs.getString('saved_start_time') ?? '') ??
              DateTime.now();

      setState(() {
        _sessionId = savedSessionId;
        _isActive = true;
        // Recalculate seconds
        _seconds = DateTime.now().difference(savedStart).inSeconds;
      });

      final motionService =
          Provider.of<MotionScoringService>(context, listen: false);
      motionService.restore(savedPoints, savedStart);

      _startTimer();

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Session Restored from Background")));
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

    final eventService = Provider.of<EventService>(context, listen: false);
    final motionService =
        Provider.of<MotionScoringService>(context, listen: false);

    try {
      _sessionId = await eventService.startSession(widget.eventId);

      motionService.start();

      _seconds = 0;
      _startTimer();
      _saveSession(); // Initial save
    } catch (e) {
      if (mounted) {
        String message = "Error starting: $e";
        if (e.toString().contains("EVENT_NOT_ACTIVE")) {
          message = "Event is not active!";
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        setState(() => _isActive = false);
      }
    }
  }

  Future<void> _stopSession() async {
    if (_isStopping || _sessionId == null) return;
    setState(() => _isStopping = true);

    // Clear persistence immediately
    _clearSavedSession();

    final eventService = Provider.of<EventService>(context, listen: false);
    final motionService =
        Provider.of<MotionScoringService>(context, listen: false);

    motionService.stop();
    _timer?.cancel();

    // Get final stats
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
                        const SizedBox(height: 10),
                        Text(
                            "Keep dancing to reach Level ${(response['new_level'] ?? 0) + 1}",
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop(); // Exit screen
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
            .showSnackBar(SnackBar(content: Text("Error stopping: $e")));
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

    // Dynamic color or animation based on isDancing could be cool
    final circleColor =
        motionService.isDancing ? Colors.purpleAccent : Colors.grey;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header / Time
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("LIVE DANCE",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      if (_isActive)
                        Text(_formatTime(_seconds),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontFamily: 'Monospace')),
                    ],
                  ),
                ),

                const Spacer(),

                // Main Circle
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: circleColor.withOpacity(0.5), width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: circleColor.withOpacity(0.2),
                            blurRadius: 40,
                            spreadRadius: 10,
                          )
                        ],
                        color: Colors.black.withOpacity(0.5)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${motionService.currentPoints}",
                          style: TextStyle(
                              color: circleColor,
                              fontSize: 80,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _isActive
                              ? (motionService.isDancing
                                  ? "DANCING!"
                                  : "KEEP MOVING")
                              : "READY?",
                          style: const TextStyle(
                              color: Colors.white70, letterSpacing: 1.5),
                        )
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Controls
                if (_isStopping)
                  const CircularProgressIndicator(color: Colors.purpleAccent)
                else if (!_isActive)
                  _buildStartButton()
                else
                  _buildStopButton(),

                const SizedBox(height: 30),

                // Debug Toggle
                GestureDetector(
                  onTap: () => setState(() => _showDebug = !_showDebug),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.transparent,
                    child: Text(_showDebug ? "Hide Debug" : "Show Debug",
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ),
                if (_showDebug) _buildDebugInfo(motionService),
                const SizedBox(height: 10),
              ],
            ),

            // Back button
            if (!_isActive)
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: _startSession,
      child: Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          color: Colors.greenAccent,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.play_arrow, color: Colors.black, size: 40),
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return GestureDetector(
      onLongPress:
          _stopSession, // Changed to LongPress to prevent accidental stops? Or just tap. Prompt said "Botón Stop". Let's stick to Tap but maybe with confirmation?
      onTap: _stopSession,
      child: Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.stop, color: Colors.white, size: 40),
        ),
      ),
    );
  }

  Widget _buildDebugInfo(MotionScoringService service) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
          color: Colors.white10, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          _debugRow("Dynamic (m/s²)", service.lastDynamic.toStringAsFixed(2)),
          _debugRow("Threshold", service.threshold.toStringAsFixed(2)),
          _debugRow(
              "PPS (Actual)", service.currentPointsPerSec.toStringAsFixed(1)),
          _debugRow("PPS Cap", service.pointsPerSecondCap.toStringAsFixed(1)),
          Slider(
            value: service.threshold,
            min: 0.5,
            max: 5.0,
            activeColor: Colors.purpleAccent,
            label: "Threshold: ${service.threshold.toStringAsFixed(1)}",
            onChanged: (v) {
              setState(() {
                service.threshold = v;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _debugRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
