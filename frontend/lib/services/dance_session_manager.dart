import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';
import 'foreground_session_service.dart';
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
  // Elapsed time is derived from wall clock (survives background freezes,
  // where periodic Timers stop ticking). Pauses are accumulated separately.
  DateTime? _pausedAt;
  int _pausedAccumSeconds = 0;
  int _lastHydrationSecond = 0;
  Timer? _syncTimer;
  Timer? _timer;
  Timer? _heartbeatTimer;
  bool _isStopping = false;

  /// Sessions older than this found in storage are discarded instead of resumed.
  static const Duration _maxRestoreAge = Duration(hours: 12);

  /// Cadence of the live sync: reports cumulative points to the server so the
  /// event leaderboard is live and the session isn't swept as abandoned.
  static const Duration _heartbeatInterval = Duration(seconds: 60);

  DanceSessionManager() {
    _startConnectivityObserver();
  }

  void _startConnectivityObserver() {
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      final prefs = await SharedPreferences.getInstance();
      final List<String> pending = prefs.getStringList('event_pending_sync') ?? [];
      if (pending.isNotEmpty && !_isDancing) {
        debugPrint('DanceSessionManager: Found ${pending.length} pending event sessions. Trying to sync...');
        await syncPendingSessions();
      }
    });
  }

  // Pedometer State
  StreamSubscription<StepCount>? _pedometerSubscription;
  int _steps = 0;
  int _initialSteps = -1;
  int _stepsAtPause = 0;
  bool _usePedometerFallback = false;
  bool _hydrationRemindersEnabled = true;

  // Getters
  bool get isDancing => _isDancing;
  bool get hydrationRemindersEnabled => _hydrationRemindersEnabled;

  Future<void> setHydrationRemindersEnabled(bool value) async {
    _hydrationRemindersEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_hydration_reminders_enabled', value);
    notifyListeners();
  }
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
      _stopPedometer();
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

    // Reset Pedometer state
    _steps = 0;
    _initialSteps = -1;
    _stepsAtPause = 0;

    // Request permissions and initialize pedometer before calling API (so it works offline too)
    bool hasPermission = false;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.activityRecognition.request();
        hasPermission = status.isGranted;
      } else {
        hasPermission = true;
      }
    } catch (e) {
      hasPermission = false;
    }

    if (hasPermission) {
      _usePedometerFallback = false;
      _startPedometer();
    } else {
      _usePedometerFallback = true;
    }

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

      _beginLocalSession();
      return true;
    } catch (e) {
      // Server rejected the session (event not active / not found / not a
      // member of a private event): surface the failure instead of silently
      // starting an offline session that could never sync.
      final msg = e.toString();
      if (msg.contains('EVENT_NOT_ACTIVE') ||
          msg.contains('Event not found') ||
          msg.contains('NOT_A_MEMBER')) {
        _stopPedometer();
        _sessionType = null;
        return false;
      }

      // Offline fallback (network error) for Event or Solo
      _sessionId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
      if (type == SessionType.event) {
        _eventId = eventId;
        _eventName = eventName ?? 'Event Session (Offline)';
      } else {
        _eventName = 'Solo Session (Offline)';
      }
      _beginLocalSession();
      return true;
    }
  }

  void _beginLocalSession() {
    _points = 0;
    _elapsedSeconds = 0;
    _startedAt = DateTime.now();
    _pausedAt = null;
    _pausedAccumSeconds = 0;
    _lastHydrationSecond = 0;
    _isDancing = true;
    _isPaused = false;

    _startTimer();
    _startHeartbeat();
    _motionService?.start();
    _saveSession();

    // Persistent notification keeps the process (and pedometer) alive
    // while the phone is locked in a pocket.
    ForegroundSessionService.start(
      title: _eventName ?? 'Looped',
      text: 'Tracking your session — 0 pts',
    );

    notifyListeners();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer =
        Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
  }

  /// Reports cumulative points so the leaderboard is live and the server's
  /// stale-session sweep knows this session is still alive. Runs while
  /// paused too (a paused session is alive, its points just don't grow).
  Future<void> _sendHeartbeat() async {
    if (!_isDancing) return;
    final id = _sessionId;

    // Refresh the foreground notification for any session type.
    ForegroundSessionService.update(
      title: _eventName ?? 'Looped',
      text: _isPaused ? 'Paused — $_points pts' : '$_points pts · $formattedTime',
    );

    // Server heartbeat only exists for online event sessions.
    if (_sessionType != SessionType.event) return;
    if (id == null || id.startsWith('pending_')) return;
    try {
      await _api.post('/sessions/heartbeat', {
        'session_id': id,
        'points': _points,
      });
    } catch (e) {
      // Offline or server hiccup: harmless, /stop reconciles at the end.
      debugPrint('DanceSessionManager: heartbeat failed: $e');
    }
  }

  void pauseSession() {
    if (!_isDancing || _isPaused) return;
    _isPaused = true;
    _pausedAt = DateTime.now();
    _timer?.cancel();
    _motionService?.pause();

    // Pause Pedometer and save steps
    _stopPedometer(isPause: true);
    _saveSession();

    notifyListeners();
  }

  void resumeSession() {
    if (!_isDancing || !_isPaused) return;
    _isPaused = false;
    if (_pausedAt != null) {
      _pausedAccumSeconds += DateTime.now().difference(_pausedAt!).inSeconds;
      _pausedAt = null;
    }
    _recomputeElapsed();
    _startTimer();
    _motionService?.resume();

    // Resume Pedometer
    if (!_usePedometerFallback) {
      _startPedometer();
    }

    notifyListeners();
  }

  /// Wall-clock elapsed = (now | pause start) - session start - accumulated pauses.
  void _recomputeElapsed() {
    if (_startedAt == null) return;
    final end = _pausedAt ?? DateTime.now();
    final secs = end.difference(_startedAt!).inSeconds - _pausedAccumSeconds;
    _elapsedSeconds = secs < 0 ? 0 : secs;
  }

  /// Stop the current session and save points
  Future<Map<String, dynamic>?> stopSession() async {
    if (!_isDancing || _sessionId == null || _isStopping) return null;

    _isStopping = true;
    notifyListeners();

    _timer?.cancel();
    _recomputeElapsed(); // final wall-clock reading (timer may have been frozen)
    _motionService?.stop();
    _stopPedometer();

    final sessionResults = _motionService?.getSessionResults();
    final motionStats = sessionResults?['motion_stats'];

    Map<String, dynamic>? response;

    final sessionData = {
      'points': _points,
      'duration_sec': _elapsedSeconds,
      'motion_stats': motionStats,
      // Real start in UTC: offline syncs replay it so the server's temporal
      // points cap (duration <= now - started_at) doesn't zero the session.
      'started_at': _startedAt?.toUtc().toIso8601String(),
    };

    try {
      if (_sessionType == SessionType.event) {
        if (!_sessionId!.startsWith('pending_')) {
          response = await _api.post('/sessions/stop', {
            'session_id': _sessionId,
            'points': _points,
            'duration_sec': _elapsedSeconds,
            'motion_stats': motionStats,
          });
        } else {
          await _savePendingSync(_sessionId!, _eventId, sessionData);
          response = sessionData;
        }
      } else {
        // Solo
        final soloData = {
          'points': _points,
          'duration_seconds': _elapsedSeconds,
          'motion_stats': motionStats,
          'started_at': _startedAt?.toUtc().toIso8601String(),
        };
        if (!_sessionId!.startsWith('pending_')) {
          await _api.post('/solo/$_sessionId/finish', soloData);
        } else {
          final prefs = await SharedPreferences.getInstance();
          List<String> pending = prefs.getStringList('solo_pending_sync') ?? [];
          soloData['id'] = _sessionId!;
          soloData['timestamp'] = DateTime.now().toUtc().toIso8601String();
          pending.add(jsonEncode(soloData));
          await prefs.setStringList('solo_pending_sync', pending);
        }
        response = soloData;
      }

      await _clearSavedSession();
      _resetState();

      return response;
    } catch (e) {
      if (_sessionType == SessionType.event) {
        await _savePendingSync(_sessionId!, _eventId, sessionData);
      } else {
        final soloData = {
          'points': _points,
          'duration_seconds': _elapsedSeconds,
          'motion_stats': motionStats,
          'started_at': _startedAt?.toUtc().toIso8601String(),
          'id': _sessionId!,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        };
        final prefs = await SharedPreferences.getInstance();
        List<String> pending = prefs.getStringList('solo_pending_sync') ?? [];
        pending.add(jsonEncode(soloData));
        await prefs.setStringList('solo_pending_sync', pending);
      }

      await _clearSavedSession();
      _resetState();
      return sessionData;
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
    _hydrationRemindersEnabled = prefs.getBool('settings_hydration_reminders_enabled') ?? true;
    final savedType = prefs.getString('dance_session_type');
    final savedEventId = prefs.getString('dance_event_id');
    final savedSessionId = prefs.getString('dance_session_id');
    final savedEventName = prefs.getString('dance_event_name');
    final savedStartStr = prefs.getString('dance_start_time');
    final savedPoints = prefs.getInt('dance_points') ?? 0;

    if (savedSessionId != null && savedStartStr != null) {
      final savedStart = DateTime.tryParse(savedStartStr);
      if (savedStart != null &&
          DateTime.now().difference(savedStart) > _maxRestoreAge) {
        // Stale session (app killed long ago): discard instead of resuming
        // with a multi-day elapsed counter.
        debugPrint('DanceSessionManager: Discarding stale saved session ($savedStartStr)');
        await _clearSavedSession();
      } else if (savedStart != null) {
        _sessionId = savedSessionId;
        _eventId = savedEventId;
        _eventName = savedEventName;
        _points = savedPoints;
        _startedAt = savedStart;
        _pausedAt = null;
        _pausedAccumSeconds = prefs.getInt('dance_paused_accum') ?? 0;
        _lastHydrationSecond = 0;
        _sessionType =
            savedType == 'solo' ? SessionType.solo : SessionType.event;
        _isDancing = true;
        // Assume we restore in unpaused state, or we could save pause state too.
        _isPaused = false;
        _recomputeElapsed();

        // Restore pedometer variables
        _steps = prefs.getInt('dance_steps') ?? 0;
        _stepsAtPause = prefs.getInt('dance_steps_at_pause') ?? 0;
        _usePedometerFallback = prefs.getBool('dance_use_pedometer_fallback') ?? false;

        _startTimer();
        _startHeartbeat();
        _motionService?.restore(savedPoints, savedStart);

        if (!_usePedometerFallback) {
          _startPedometer();
        }

        ForegroundSessionService.start(
          title: _eventName ?? 'Looped',
          text: 'Session resumed — $_points pts',
        );

        notifyListeners();
      }
    }
    await syncPendingSessions();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        _recomputeElapsed();
        // Sync points from motion service if available
        if (_motionService != null) {
          _points = _motionService!.currentPoints;
        }

        // Hydration Reminder: every 30 min of active time.
        // Threshold-based (not modulo) so it still fires when the elapsed
        // counter jumps after a background freeze.
        if (_hydrationRemindersEnabled &&
            _elapsedSeconds - _lastHydrationSecond >= 1800) {
          _lastHydrationSecond = _elapsedSeconds;
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
    await prefs.setInt('dance_steps', _steps);
    await prefs.setInt('dance_steps_at_pause', _stepsAtPause);
    await prefs.setInt('dance_paused_accum', _pausedAccumSeconds);
    await prefs.setBool('dance_use_pedometer_fallback', _usePedometerFallback);
  }

  Future<void> _clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dance_session_type');
    await prefs.remove('dance_event_id');
    await prefs.remove('dance_session_id');
    await prefs.remove('dance_event_name');
    await prefs.remove('dance_start_time');
    await prefs.remove('dance_points');
    await prefs.remove('dance_steps');
    await prefs.remove('dance_steps_at_pause');
    await prefs.remove('dance_paused_accum');
    await prefs.remove('dance_use_pedometer_fallback');
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
    _pausedAt = null;
    _pausedAccumSeconds = 0;
    _lastHydrationSecond = 0;
    _isStopping = false;
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    ForegroundSessionService.stop();

    _steps = 0;
    _initialSteps = -1;
    _stepsAtPause = 0;
    _stopPedometer();

    notifyListeners();
  }

  String get formattedTime {
    final hours = (_elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  // Derived Stats
  int get steps {
    if (_usePedometerFallback) {
      return (_points * 0.82).round(); // Estimation fallback
    }
    return _steps;
  }
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

  // Pedometer logic helpers
  void _startPedometer() {
    _pedometerSubscription?.cancel();
    try {
      _pedometerSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onPedometerError,
      );
    } catch (e) {
      debugPrint('Pedometer stream initialization failed: $e');
      _usePedometerFallback = true;
      notifyListeners();
    }
  }

  void _stopPedometer({bool isPause = false}) {
    _pedometerSubscription?.cancel();
    _pedometerSubscription = null;
    if (isPause) {
      _stepsAtPause = _steps;
      _initialSteps = -1;
    }
  }

  void _onStepCount(StepCount event) {
    if (!_isDancing || _isPaused) return;

    if (_initialSteps == -1) {
      _initialSteps = event.steps;
    }

    final newSteps = event.steps - _initialSteps;
    final deltaSteps = newSteps - (_steps - _stepsAtPause);

    if (deltaSteps > 0) {
      _steps = _stepsAtPause + newSteps;
      
      // Submit new steps as points to MotionScoringService
      if (_motionService != null) {
        _motionService!.addPoints(deltaSteps);
        _points = _motionService!.currentPoints;
      }
    }
    
    notifyListeners();
  }

  void _onPedometerError(Object error) {
    debugPrint('Pedometer subscription error: $error');
    _usePedometerFallback = true;
    notifyListeners();
  }

  Future<void> _savePendingSync(String id, String? eventId, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pending = prefs.getStringList('event_pending_sync') ?? [];
      data['id'] = id;
      data['event_id'] = eventId;
      data['timestamp'] = DateTime.now().toUtc().toIso8601String();
      pending.add(jsonEncode(data));
      await prefs.setStringList('event_pending_sync', pending);
      debugPrint('DanceSessionManager: Cached pending event session: $id');
    } catch (e) {
      debugPrint('DanceSessionManager: Failed to cache pending session: $e');
    }
  }

  Future<void> syncPendingSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pending = prefs.getStringList('event_pending_sync') ?? [];
      if (pending.isEmpty) return;

      List<String> failed = [];
      for (String item in pending) {
        try {
          final data = jsonDecode(item);
          final id = data['id'];
          final eventId = data['event_id'];

          if (id.startsWith('pending_')) {
            final startRes = await _api.post('/sessions/start', {
              'event_id': eventId,
              // Prefer the real session start; 'timestamp' (save time) is a
              // legacy fallback for entries queued before started_at existed.
              'started_at': data['started_at'] ?? data['timestamp'],
            });
            final newId = startRes['session_id'];
            await _api.post('/sessions/stop', {
              'session_id': newId,
              'points': data['points'],
              'duration_sec': data['duration_sec'],
              'motion_stats': data['motion_stats'],
            });
          } else {
            await _api.post('/sessions/stop', {
              'session_id': id,
              'points': data['points'],
              'duration_sec': data['duration_sec'],
              'motion_stats': data['motion_stats'],
            });
          }
        } catch (e) {
          debugPrint('DanceSessionManager: Failed to sync pending session: $e');
          failed.add(item);
        }
      }
      await prefs.setStringList('event_pending_sync', failed);
    } catch (e) {
      debugPrint('DanceSessionManager: Error during syncPendingSessions: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _syncTimer?.cancel();
    _heartbeatTimer?.cancel();
    _stopPedometer();
    super.dispose();
  }

  void reset() {
    _resetState();
  }
}
