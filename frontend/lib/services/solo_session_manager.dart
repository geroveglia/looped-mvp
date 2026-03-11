import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'motion_scoring_service.dart';
import '../models/solo_session.dart';

class SoloSessionManager with ChangeNotifier {
  final ApiService _api = ApiService();
  MotionScoringService? _motionService;

  bool _isDancing = false;
  String? _sessionId;
  int _points = 0;
  int _elapsedSeconds = 0;
  DateTime? _startedAt;
  Timer? _timer;
  bool _isStopping = false;

  bool get isDancing => _isDancing;
  String? get sessionId => _sessionId;
  int get points => _points;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isStopping => _isStopping;

  void setMotionService(MotionScoringService service) {
    _motionService = service;
  }

  Future<bool> startSession() async {
    if (_isDancing) return false;

    try {
      final response = await _api.post('/solo/start', {});
      _sessionId = response['session_id'];
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
      // Allow starting offline? User said: "Manejo offline básico (si se corta internet, guardar local y sync al volver)"
      // For now, let's allow it to start locally if API fails, but we need a temp ID.
      _sessionId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
      _points = 0;
      _elapsedSeconds = 0;
      _startedAt = DateTime.now();
      _isDancing = true;

      _startTimer();
      _motionService?.start();
      await _saveSession();

      notifyListeners();
      return true;
    }
  }

  Future<Map<String, dynamic>?> stopSession() async {
    if (!_isDancing || _isStopping) return null;

    _isStopping = true;
    notifyListeners();

    _timer?.cancel();
    _motionService?.stop();

    final sessionResults = _motionService?.getSessionResults();
    final motionStats = sessionResults?['motion_stats'];
    final avgIntensity = motionStats?['avg_intensity'] ?? 0.0;

    final sessionData = {
      'points': _points,
      'duration_seconds': _elapsedSeconds,
      'avg_intensity': avgIntensity,
    };

    try {
      if (_sessionId != null && !_sessionId!.startsWith('pending_')) {
        await _api.post('/solo/$_sessionId/finish', sessionData);
      } else {
        await _savePendingSync(_sessionId ?? 'unknown', sessionData);
      }

      await _clearSavedSession();
      _resetState();
      return sessionData;
    } catch (e) {
      // Save for later sync
      await _savePendingSync(_sessionId ?? 'unknown', sessionData);
      await _clearSavedSession();
      _resetState();
      return sessionData;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      if (_motionService != null) {
        _points = _motionService!.currentPoints;
      }
      notifyListeners();
    });
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('solo_session_id', _sessionId!);
    await prefs.setString('solo_start_time', _startedAt!.toIso8601String());
    await prefs.setInt('solo_points', _points);
  }

  Future<void> _clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('solo_session_id');
    await prefs.remove('solo_start_time');
    await prefs.remove('solo_points');
  }

  Future<void> _savePendingSync(String id, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pending = prefs.getStringList('solo_pending_sync') ?? [];
    data['id'] = id;
    data['timestamp'] = DateTime.now().toIso8601String();
    pending.add(jsonEncode(data));
    await prefs.setStringList('solo_pending_sync', pending);
  }

  Future<void> syncPendingSessions() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pending = prefs.getStringList('solo_pending_sync') ?? [];
    if (pending.isEmpty) return;

    List<String> failed = [];
    for (String item in pending) {
      try {
        final data = jsonDecode(item);
        final id = data['id'];
        if (id.startsWith('pending_')) {
          // If it was started offline, we might need a way to 'create' it first or use a bulk endpoint.
          // For now, let's assume we can POST to /solo/start with start_at.
          // Adjust backend if needed.
          final startRes = await _api.post('/solo/start', {
            'started_at': data['timestamp'], // simplistic
          });
          final newId = startRes['session_id'];
          await _api.post('/solo/$newId/finish', data);
        } else {
          await _api.post('/solo/$id/finish', data);
        }
      } catch (e) {
        failed.add(item);
      }
    }
    await prefs.setStringList('solo_pending_sync', failed);
  }

  Future<void> restoreFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('solo_session_id');
    final savedStartStr = prefs.getString('solo_start_time');
    final savedPoints = prefs.getInt('solo_points') ?? 0;

    if (savedId != null && savedStartStr != null) {
      final savedStart = DateTime.tryParse(savedStartStr);
      if (savedStart != null) {
        _sessionId = savedId;
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

  void _resetState() {
    _isDancing = false;
    _sessionId = null;
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

  Future<List<SoloSession>> getHistory() async {
    try {
      final List<dynamic> response = await _api.get('/solo/history');
      return response.map((json) => SoloSession.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
}
