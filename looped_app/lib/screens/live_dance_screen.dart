import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/event_service.dart';

class LiveDanceScreen extends StatefulWidget {
  final String eventId;

  const LiveDanceScreen({super.key, required this.eventId});

  @override
  State<LiveDanceScreen> createState() => _LiveDanceScreenState();
}

class _LiveDanceScreenState extends State<LiveDanceScreen> {
  StreamSubscription? _subscription;
  int _points = 0;
  int _seconds = 0;
  Timer? _timer;
  String? _sessionId;
  DateTime _lastPointTime = DateTime.now();
  bool _isStopping = false;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    final service = Provider.of<EventService>(context, listen: false);
    _sessionId = await service.startSession(widget.eventId);
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _seconds++);
    });

    // Sensor Logic
    // Threshold ~2.0 m/s^2 above gravity (UserAccelerometer gives acceleration without gravity)
    // Actually UserAccelerometer is better if device has gyroscope, otherwise Accelerometer includes gravity.
    // Let's use UserAccelerometer and fallback? No, just UserAccelerometerEvent.
    // Note: might need error handling if sensor not available.
    _subscription = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (magnitude > 2.0) { // Threshold
        final now = DateTime.now();
        if (now.difference(_lastPointTime).inMilliseconds > 200) { // Max 5 pts/sec
          if (mounted) {
            setState(() {
              _points += 1; // Or variable points based on intensity
              _lastPointTime = now;
            });
          }
        }
      }
    });
  }

  Future<void> _stopSession() async {
    if (_isStopping || _sessionId == null) return;
    setState(() => _isStopping = true);

    _subscription?.cancel();
    _timer?.cancel();

    final service = Provider.of<EventService>(context, listen: false);
    await service.stopSession(_sessionId!, _points, _seconds);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(_formatTime(_seconds), 
                 style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
            const Spacer(),
            // Animated Pulse or Just Big Text
            Text('$_points', 
                 style: const TextStyle(color: Colors.purpleAccent, fontSize: 120, fontWeight: FontWeight.bold)),
            const Text("POINTS", style: TextStyle(color: Colors.white, letterSpacing: 2)),
            const Spacer(),
            if (_isStopping)
               const CircularProgressIndicator()
            else
              GestureDetector(
                onTap: _stopSession, // Hold to stop? Or Tap. Prompt says 2 taps to start. 
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
                    ]
                  ),
                  child: const Center(child: Icon(Icons.stop, size: 50, color: Colors.white)),
                ),
              ),
            const SizedBox(height: 50),
            const Text("MOVE TO SCORE!", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
