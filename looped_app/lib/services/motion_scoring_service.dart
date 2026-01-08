import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MotionScoringService with ChangeNotifier {
  // Streams / Values
  int _currentPoints = 0;
  int get currentPoints => _currentPoints;

  bool _isDancing = false;
  bool get isDancing => _isDancing;

  // Debug Stats
  double _lastDynamic = 0.0;
  double get lastDynamic => _lastDynamic;

  double _currentPointsPerSec = 0.0;
  double get currentPointsPerSec => _currentPointsPerSec;

  // Configuration (Calibratable)
  double threshold = 2.5; // Threshold for valid movement (dynamic acceleration)
  int cooldownMs = 300; // Min time between beats
  double pointsPerSecondCap = 8.0; // Max points allowed per second
  double varianceWindowSec = 2.0; // Window to check for "stuck" sensor

  // Internal State
  StreamSubscription? _subscription;
  DateTime? _startTime;
  DateTime _lastBeatTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Smoothing (Low-pass filter / EMA)
  double _filteredMagnitude = 9.81;
  final double _alpha = 0.1; // Smoothing factor (0 < alpha < 1)

  // Anti-cheat / Cap logic
  List<DateTime> _recentPointsTimestamp = [];

  // Variance check (basic implementation)
  List<double> _recentDynamics = [];
  final int _maxVarianceSamples =
      20; // Approx 2 seconds at 10Hz (sensor speed varies)

  void start() {
    // If not restoring (restoring is separate), reset everything
    reset();
    resume();
  }

  void reset() {
    _currentPoints = 0;
    _isDancing = false;
    _lastDynamic = 0.0;
    _startTime = DateTime.now();
    _recentPointsTimestamp.clear();
    _recentDynamics.clear();
    _filteredMagnitude = 9.81;
    notifyListeners();
  }

  void stop() {
    pause();
    _isDancing = false;
    notifyListeners();
  }

  void pause() {
    _subscription?.cancel();
    _subscription = null;
  }

  void resume() {
    _subscription?.cancel();
    _subscription = accelerometerEvents.listen(_onAccelerometerEvent);
  }

  void restore(int points, DateTime startTime) {
    _currentPoints = points;
    _startTime = startTime;
    _isDancing = false;
    _recentPointsTimestamp.clear(); // Lost immediate history, fine
    notifyListeners();
    resume();
  }

  Map<String, dynamic> getSessionResults() {
    final duration = _startTime != null
        ? DateTime.now().difference(_startTime!).inSeconds
        : 0;
    return {
      'points': _currentPoints,
      'duration_sec': duration,
    };
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    // 1. Calculate raw magnitude
    double rawMagnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    // 2. Smoothing (EMA) to reduce noise
    _filteredMagnitude =
        _alpha * rawMagnitude + (1 - _alpha) * _filteredMagnitude;

    // 3. Dynamic component (absolute difference from gravity 9.81)
    // We use the smoothed magnitude to be more stable, or raw?
    // Prompt says: "dynamic = abs(m - 9.81)". Let's use raw for 'm' but maybe smooth 'dynamic' result?
    // Let's stick to simple: dynamic = abs(rawMagnitude - 9.81) then smooth THAT?
    // Prompt: "Aplicar smoothing: media móvil... para estabilizar".
    // Let's smooth the magnitude first as it represents physical force.

    double dynamicMag = (_filteredMagnitude - 9.81).abs();
    _lastDynamic = dynamicMag;

    // 4. Update "Dancing" state (simple inactivity check)
    if (dynamicMag > threshold * 0.5) {
      if (!_isDancing) {
        _isDancing = true;
        notifyListeners(); // State change
      }
    } else {
      // If stays low for a while... handled by outside check?
      // For now, let's just flip it if it drops very low, but maybe with a delay?
      // For MVP, direct mapping or simple debounce.
      // Let's keep it simple: if dynamic is low, we are not "actively" getting points,
      // but maybe we don't need to flicker the UI state _isDancing too fast.
      // We'll leave _isDancing true if we got points recently.
    }

    // Inactivity timeout logic could go here, but let's focus on Beats.

    // 5. Beat Detection
    if (dynamicMag > threshold) {
      final now = DateTime.now();

      // Cooldown check
      if (now.difference(_lastBeatTime).inMilliseconds > cooldownMs) {
        // Variance / Anti-spam check
        _updateVarianceHistory(dynamicMag);
        if (!_isMechanicalSpam()) {
          _addPoint(now, dynamicMag);
        }
      }
    }

    // Prune old timestamps for cap calculation
    _pruneOldPoints();
    _updatePPS();

    notifyListeners(); // Notify UI of updates (points, debug values)
  }

  void _addPoint(DateTime now, double dynamicMag) {
    // Anti-cheat: Cap points per second
    if (_recentPointsTimestamp.length < pointsPerSecondCap) {
      int pointsToAdd = 1;
      // Bonus
      if (dynamicMag > threshold * 2.0) {
        pointsToAdd = 2;
      }

      _currentPoints += pointsToAdd;
      _lastBeatTime = now;
      _recentPointsTimestamp.add(now);

      // Update dancing state refresh
      _isDancing = true;
    }
  }

  void _updateVarianceHistory(double val) {
    if (_recentDynamics.length >= _maxVarianceSamples) {
      _recentDynamics.removeAt(0);
    }
    _recentDynamics.add(val);
  }

  bool _isMechanicalSpam() {
    // If variance is essentially zero, it's artificial (like a machine shaker?)
    // Or if purely constant.
    if (_recentDynamics.length < 5) return false;

    double mean =
        _recentDynamics.reduce((a, b) => a + b) / _recentDynamics.length;
    double variance =
        _recentDynamics.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
            _recentDynamics.length;

    // If variance is extremely low, it might be suspicious?
    // Actually for human motion, variance is high.
    // If variance < 0.05 (arbitrary small), valid "shake" but too rhythmic/constant?
    // Let's skip strict variance for MVP unless requested.
    // Prompt: "Patrón demasiado constante... ejemplo: medir varianza... si varianza < X, no suma"

    return variance < 0.01;
  }

  void _pruneOldPoints() {
    final now = DateTime.now();
    _recentPointsTimestamp
        .removeWhere((t) => now.difference(t).inMilliseconds > 1000);
  }

  void _updatePPS() {
    _currentPointsPerSec = _recentPointsTimestamp.length.toDouble();
  }
}
