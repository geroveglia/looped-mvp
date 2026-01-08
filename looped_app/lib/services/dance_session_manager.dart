import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'motion_scoring_service.dart';

/// Global manager for dance session state.
/// Allows the session to persist across screen navigation.
class DanceSessionManager with ChangeNotifier {
  final ApiService _api = ApiService();
  MotionScoringService? _motionService;

  // Session State
  bool _isDancing = false;
  String? _sessionId;
  String? _eventId;
  String? _eventName;
  int _points = 0;
  int _elapsedSeconds = 0;
  DateTime? _startedAt;
  Timer? _timer;
  bool _isStopping = false;

  // Getters
  bool get isDancing => _isDancing;
  String? get sessionId => _sessionId;
  String? get eventId => _eventId;
  String? get eventName => _eventName;
  int get points => _points;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isStopping => _isStopping;

  /// Set the motion service reference (from Provider context)
  void setMotionService(MotionScoringService service) {
    _motionService = service;
  }

  /// Update points from motion service
  void updatePoints(int newPoints) {
    _points = newPoints;
    notifyListeners();
  }

  /// Sync state from LiveDanceScreen (lightweight integration)
  /// Call this when LiveDanceScreen starts/stops a session
  void syncFromLiveDance({
    required bool isDancing,
    String? sessionId,
    String? eventId,
    String? eventName,
    int points = 0,
    int elapsedSeconds = 0,
  }) {
    _isDancing = isDancing;
    _sessionId = sessionId;
    _eventId = eventId;
    _eventName = eventName;
    _points = points;
    _elapsedSeconds = elapsedSeconds;
    _startedAt = isDancing
        ? DateTime.now().subtract(Duration(seconds: elapsedSeconds))
        : null;

    if (isDancing && _timer == null) {
      _startTimer();
    } else if (!isDancing) {
      _timer?.cancel();
      _timer = null;
    }

    notifyListeners();
  }

  /// Start a new dance session
  Future<bool> startSession(String eventId, String eventName) async {
    if (_isDancing) return false;

    try {
      final response =
          await _api.post('/sessions/start', {'event_id': eventId});

      _sessionId = response['session_id'];
      _eventId = eventId;
      _eventName = eventName;
      _points = 0;
      _elapsedSeconds = 0;
      _startedAt = DateTime.now();
      _isDancing = true;

      _startTimer();
      _motionService?.start();
      await _saveSession();

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Stop the current session and save points
  Future<Map<String, dynamic>?> stopSession() async {
    if (!_isDancing || _sessionId == null || _isStopping) return null;

    _isStopping = true;
    notifyListeners();

    try {
      _timer?.cancel();
      _motionService?.stop();

      final sessionResults = _motionService?.getSessionResults();
      final motionStats = sessionResults?['motion_stats'];

      final response = await _api.post('/sessions/stop', {
        'session_id': _sessionId,
        'points': _points,
        'duration_sec': _elapsedSeconds,
        'motion_stats': motionStats,
      });

      await _clearSavedSession();
      _resetState();

      return response;
    } catch (e) {
      // Even on error, reset local state
      _resetState();
      rethrow;
    }
  }

  /// Leave the event entirely (also stops session)
  Future<void> leaveEvent() async {
    if (_eventId == null) return;

    try {
      _timer?.cancel();
      _motionService?.stop();

      await _api.post('/events/$_eventId/leave', {});
      await _clearSavedSession();
      _resetState();
    } catch (e) {
      _resetState();
      rethrow;
    }
  }

  /// Restore session from SharedPreferences
  Future<void> restoreFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEventId = prefs.getString('dance_event_id');
    final savedSessionId = prefs.getString('dance_session_id');
    final savedEventName = prefs.getString('dance_event_name');
    final savedStartStr = prefs.getString('dance_start_time');
    final savedPoints = prefs.getInt('dance_points') ?? 0;

    if (savedEventId != null &&
        savedSessionId != null &&
        savedStartStr != null) {
      final savedStart = DateTime.tryParse(savedStartStr);
      if (savedStart != null) {
        _sessionId = savedSessionId;
        _eventId = savedEventId;
        _eventName = savedEventName;
        _points = savedPoints;
        _startedAt = savedStart;
        _elapsedSeconds = DateTime.now().difference(savedStart).inSeconds;
        _isDancing = true;

        _startTimer();
        _motionService?.restore(savedPoints, savedStart);

        notifyListeners();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      // Sync points from motion service if available
      if (_motionService != null) {
        _points = _motionService!.currentPoints;
      }
      notifyListeners();
    });
  }

  Future<void> _saveSession() async {
    if (!_isDancing || _sessionId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dance_event_id', _eventId!);
    await prefs.setString('dance_session_id', _sessionId!);
    await prefs.setString('dance_event_name', _eventName ?? '');
    await prefs.setString('dance_start_time', _startedAt!.toIso8601String());
    await prefs.setInt('dance_points', _points);
  }

  Future<void> _clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dance_event_id');
    await prefs.remove('dance_session_id');
    await prefs.remove('dance_event_name');
    await prefs.remove('dance_start_time');
    await prefs.remove('dance_points');
  }

  void _resetState() {
    _isDancing = false;
    _sessionId = null;
    _eventId = null;
    _eventName = null;
    _points = 0;
    _elapsedSeconds = 0;
    _startedAt = null;
    _isStopping = false;
    _timer?.cancel();
    notifyListeners();
  }

  String get formattedTime {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
