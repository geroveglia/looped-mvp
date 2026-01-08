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

  // Anti-Cheat v2 Metrics
  int _totalSamples = 0;
  int _sumPeakIntervals = 0;
  int _peakCount = 0;
  int _flatPatternSeconds = 0;
  DateTime? _lastFlatCheck;
  double _penaltyMultiplier = 1.0;

  // Rule 2 vars: Speed
  List<int> _recentPeakIntervals = [];

  // Anti-cheat / Cap logic
  List<DateTime> _recentPointsTimestamp = [];

  // Variance check
  List<double> _recentDynamics = [];
  final int _maxVarianceSamples = 20;

  void start() {
    _totalSamples = 0;
    _sumPeakIntervals = 0;
    _peakCount = 0;
    _flatPatternSeconds = 0;
    _penaltyMultiplier = 1.0;
    _recentPeakIntervals.clear();
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

    // Calculate final stats
    double avgInterval = _peakCount > 0 ? _sumPeakIntervals / _peakCount : 0;
    double variance = _calculateVariance(_recentDynamics);

    return {
      'points': _currentPoints,
      'duration_sec': duration,
      'motion_stats': {
        'total_samples': _totalSamples,
        'avg_peak_interval_ms': avgInterval,
        'flat_pattern_seconds': _flatPatternSeconds,
        'variance': variance
      }
    };
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    _totalSamples++;
    // ... Smoothing and Dynamic Calc ...
    double rawMagnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _filteredMagnitude =
        _alpha * rawMagnitude + (1 - _alpha) * _filteredMagnitude;
    double dynamicMag = (_filteredMagnitude - 9.81).abs();
    _lastDynamic = dynamicMag;

    // Rule 1: Flat Pattern Check (every 1s)
    final now = DateTime.now();
    if (_lastFlatCheck == null) _lastFlatCheck = now;
    if (now.difference(_lastFlatCheck!).inMilliseconds > 1000) {
      _lastFlatCheck = now;
      if (_calculateVariance(_recentDynamics) < 0.02 &&
          _recentDynamics.length > 10) {
        _flatPatternSeconds++;
        if (_flatPatternSeconds > 5) _penaltyMultiplier *= 0.8; // Reduce by 20%
      }
    }

    if (dynamicMag > threshold * 0.5) {
      if (!_isDancing) {
        _isDancing = true;
        notifyListeners();
      }
    }

    // Beat Detection
    if (dynamicMag > threshold) {
      if (now.difference(_lastBeatTime).inMilliseconds > cooldownMs) {
        int interval = now.difference(_lastBeatTime).inMilliseconds;
        if (_peakCount > 0) {
          _sumPeakIntervals += interval;
          _recentPeakIntervals.add(interval);
          if (_recentPeakIntervals.length > 20)
            _recentPeakIntervals.removeAt(0);
        }
        _peakCount++;

        _updateVarianceHistory(dynamicMag);

        // Rule 2: Inhuman Rhythm Check
        double avgRecentInterval = _recentPeakIntervals.isEmpty
            ? 1000
            : _recentPeakIntervals.reduce((a, b) => a + b) /
                _recentPeakIntervals.length;
        if (avgRecentInterval < 180 && _recentPeakIntervals.length > 5) {
          _penaltyMultiplier *= 0.9;
        }

        if (!_isMechanicalSpam()) {
          _addPoint(now, dynamicMag);
        }
      }
    }

    _pruneOldPoints();
    _updatePPS();
    notifyListeners();
  }

  void _addPoint(DateTime now, double dynamicMag) {
    if (_recentPointsTimestamp.length < pointsPerSecondCap) {
      int basePoints = 1;
      if (dynamicMag > threshold * 2.0) basePoints = 2; // Bonus

      // Apply Penalty
      if (_penaltyMultiplier < 0.4) _penaltyMultiplier = 0.4; // Min cap
      int finalPoints = (basePoints * _penaltyMultiplier).round();
      if (finalPoints < 0) finalPoints = 0; // Integrity

      _currentPoints += finalPoints;

      _lastBeatTime = now;
      _recentPointsTimestamp.add(now);
      _isDancing = true;
    } else {
      // Rule 3: Saturation Cap (Implicitly handled by not adding points, but we could track it)
    }
  }

  double _calculateVariance(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    double mean = samples.reduce((a, b) => a + b) / samples.length;
    return samples.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
        samples.length;
  }

  // ... rest of helper methods (_updateVarianceHistory, _isMechanicalSpam, etc) keep logic but use new vars?
  // Actually _updateVarianceHistory is fine. _isMechanicalSpam uses _recentDynamics.

  void _updateVarianceHistory(double val) {
    if (_recentDynamics.length >= _maxVarianceSamples) {
      _recentDynamics.removeAt(0);
    }
    _recentDynamics.add(val);
  }

  bool _isMechanicalSpam() {
    if (_recentDynamics.length < 5) return false;
    return _calculateVariance(_recentDynamics) < 0.01;
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
