import 'package:flutter/material.dart';
import 'api_service.dart';

class EventService with ChangeNotifier {
  final ApiService _api = ApiService();
  List<dynamic> _events = [];

  List<dynamic> get events => _events;

  Future<void> fetchEvents() async {
    try {
      final response = await _api.get('/events');
      _events = response;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createEvent(String name, bool isPublic) async {
    try {
      await _api.post('/events', {
        'name': name,
        'is_public': isPublic,
      });
      await fetchEvents();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> joinEvent(String eventId) async {
    try {
      await _api.post('/events/join', {'event_id': eventId});
    } catch (e) {
      // Ignore "already joined" error or handle it
      if (e.toString().contains('Already joined')) return;
      rethrow;
    }
  }

  Future<String> startSession(String eventId) async {
    final response = await _api.post('/sessions/start', {'event_id': eventId});
    return response['session_id'];
  }

  Future<void> stopSession(String sessionId, int points, int durationSec) async {
    await _api.post('/sessions/stop', {
      'session_id': sessionId,
      'points': points,
      'duration_sec': durationSec,
    });
  }

  Future<List<dynamic>> getLeaderboard(String eventId) async {
    final response = await _api.get('/events/$eventId/leaderboard');
    return response;
  }
}
