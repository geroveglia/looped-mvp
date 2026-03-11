import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'motion_scoring_service.dart';
import 'notification_service.dart';

enum SessionType { solo, event }

/// Global manager for dance session state.
/// Allows the session to persist across screen navigation.
class DanceSessionManager with ChangeNotifier {
  final ApiService _api = ApiService();
  MotionScoringService? _motionService;

  // Session State
  bool _isDancing = false;
  bool _isOnDanceScreen = false;
  bool _isPaused = false;
  SessionType? _sessionType;
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
  bool get isOnDanceScreen => _isOnDanceScreen;
  bool get isPaused => _isPaused;

  set isOnDanceScreen(bool value) {
    if (_isOnDanceScreen != value) {
      _isOnDanceScreen = value;
      notifyListeners();
    }
  }
  SessionType? get sessionType => _sessionType;
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
    if (!_isPaused) {
      _points = newPoints;
      notifyListeners();
    }
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
    // If we are already managing a session centrally, ignore syncs that might conflict
    // unless it's a stop command.
    if (_isDancing && isDancing && _sessionId == sessionId) {
      return;
    }

    _isDancing = isDancing;
    _sessionId = sessionId;
    _eventId = eventId;
    _eventName = eventName;
    _points = points;
    _elapsedSeconds = elapsedSeconds;
    _sessionType = SessionType.event;
    _isPaused = false;
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

  /// Start a new dance session (Event or Solo)
  Future<bool> startSession({
    required SessionType type,
    String? eventId,
    String? eventName,
  }) async {
    if (_isDancing) return false;

    _sessionType = type;

    try {
      if (type == SessionType.event) {
        final response =
            await _api.post('/sessions/start', {'event_id': eventId});
        _sessionId = response['session_id'];
        _eventId = eventId;
        _eventName = eventName;
      } else {
        // Solo
        final response = await _api.post('/solo/start', {});
        _sessionId = response['session_id'];
        _eventName = 'Solo Session';
      }

      _points = 0;
      _elapsedSeconds = 0;
      _startedAt = DateTime.now();
      _isDancing = true;
      _isPaused = false;

      _startTimer();
      _motionService?.start();
      await _saveSession();

      notifyListeners();
      return true;
    } catch (e) {
      // Offline fallback for Solo
      if (type == SessionType.solo) {
        _sessionId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
        _eventName = 'Solo Session (Offline)';
        _points = 0;
        _elapsedSeconds = 0;
        _startedAt = DateTime.now();
        _isDancing = true;
        _isPaused = false;
        _startTimer();
        _motionService?.start();
        await _saveSession();
        notifyListeners();
        return true;
      }
      return false;
    }
  }

  void pauseSession() {
    if (!_isDancing || _isPaused) return;
    _isPaused = true;
    _timer?.cancel();
    _motionService?.pause();
    notifyListeners();
  }

  void resumeSession() {
    if (!_isDancing || !_isPaused) return;
    _isPaused = false;
    _startTimer();
    _motionService?.resume();
    notifyListeners();
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

      Map<String, dynamic>? response;

      if (_sessionType == SessionType.event) {
        response = await _api.post('/sessions/stop', {
          'session_id': _sessionId,
          'points': _points,
          'duration_sec': _elapsedSeconds,
          'motion_stats': motionStats,
        });
      } else {
        // Solo
        final sessionData = {
          'points': _points,
          'duration_seconds': _elapsedSeconds,
          'motion_stats': motionStats,
        };
        if (!_sessionId!.startsWith('pending_')) {
          await _api.post('/solo/$_sessionId/finish', sessionData);
        }
        // If pending, logic handled in SoloSessionManager generally,
        // but for now we unify here or let caller handle sync.
        // Simplified for this task: return the data.
        response = sessionData;
      }

      await _clearSavedSession();
      _resetState();

      return response;
    } catch (e) {
      // Even on error, reset local state
      _resetState();
      // Re-throw if it's an event error we want to show, otherwise suppress for UI flow?
      // For now rethrow so UI can show error
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
    final savedType = prefs.getString('dance_session_type');
    final savedEventId = prefs.getString('dance_event_id');
    final savedSessionId = prefs.getString('dance_session_id');
    final savedEventName = prefs.getString('dance_event_name');
    final savedStartStr = prefs.getString('dance_start_time');
    final savedPoints = prefs.getInt('dance_points') ?? 0;

    if (savedSessionId != null && savedStartStr != null) {
      final savedStart = DateTime.tryParse(savedStartStr);
      if (savedStart != null) {
        _sessionId = savedSessionId;
        _eventId = savedEventId;
        _eventName = savedEventName;
        _points = savedPoints;
        _startedAt = savedStart;
        _elapsedSeconds = DateTime.now().difference(savedStart).inSeconds;
        _sessionType =
            savedType == 'solo' ? SessionType.solo : SessionType.event;
        _isDancing = true;
        // Assume we restore in unpaused state, or we could save pause state too.
        _isPaused = false;

        _startTimer();
        _motionService?.restore(savedPoints, savedStart);

        notifyListeners();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        _elapsedSeconds++;
        // Sync points from motion service if available
        if (_motionService != null) {
          _points = _motionService!.currentPoints;
        }

        // Hydration Reminder: Every 1800 seconds (30 mins)
        if (_elapsedSeconds > 0 && _elapsedSeconds % 1800 == 0) {
          NotificationService().showHydrationReminder();
        }

        notifyListeners();
      }
    });
  }

  Future<void> _saveSession() async {
    if (!_isDancing || _sessionId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dance_session_type',
        _sessionType == SessionType.solo ? 'solo' : 'event');
    if (_eventId != null) await prefs.setString('dance_event_id', _eventId!);
    await prefs.setString('dance_session_id', _sessionId!);
    await prefs.setString('dance_event_name', _eventName ?? '');
    await prefs.setString('dance_start_time', _startedAt!.toIso8601String());
    await prefs.setInt('dance_points', _points);
  }

  Future<void> _clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dance_session_type');
    await prefs.remove('dance_event_id');
    await prefs.remove('dance_session_id');
    await prefs.remove('dance_event_name');
    await prefs.remove('dance_start_time');
    await prefs.remove('dance_points');
  }

  void _resetState() {
    _isDancing = false;
    _isPaused = false;
    _sessionType = null;
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
    final hours = (_elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  // Derived Stats
  int get steps => (_points * 0.82).round(); // Estimation
  double get distanceKm => steps * 0.00076; // 0.76m per step approx
  double get speedKmh => _elapsedSeconds > 0 ? (distanceKm / (_elapsedSeconds / 3600)) : 0.0;
  
  String get pace {
    if (distanceKm < 0.001) return "0'00\"";
    final totalMinutes = (_elapsedSeconds / 60) / distanceKm;
    final mins = totalMinutes.toInt();
    final secs = ((totalMinutes - mins) * 60).toInt();
    return "$mins'${secs.toString().padLeft(2, '0')}\"";
  }

  int get elevation => (_points ~/ 50); // Pseudo-elevation for demo
  int get calories => (_points * 0.15 + _elapsedSeconds * 0.08).round(); // Simple burn estimation

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
