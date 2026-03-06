import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'api_service.dart';

class EventService with ChangeNotifier {
  final ApiService _api = ApiService();
  List<dynamic> _events = [];
  List<dynamic> _myEvents = [];

  List<dynamic> get events => _events;
  List<dynamic> get myEvents => _myEvents;

  // Fetch public events
  Future<void> fetchEvents() async {
    try {
      final response = await _api.get('/events');
      _events = response;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Fetch my events (where I'm member/host)
  Future<void> fetchMyEvents() async {
    try {
      final response = await _api.get('/events/my');
      _myEvents = response;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createEvent(Map<String, dynamic> eventData,
      {Uint8List? imageBytes, String? fileName}) async {
    try {
      final Map<String, String> stringFields = {};
      eventData.forEach((key, value) {
        if (value != null) stringFields[key] = value.toString();
      });

      await _api.postMultipart('/events', stringFields, imageBytes, fileName: fileName);
      await fetchEvents();
      await fetchMyEvents();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> joinEvent(String eventId) async {
    try {
      await _api.post('/events/join', {'event_id': eventId});
      await fetchMyEvents();
    } catch (e) {
      if (e.toString().contains('Already joined')) return;
      rethrow;
    }
  }

  // Join private event by invite code
  Future<Map<String, dynamic>> joinByCode(String inviteCode) async {
    final response = await _api.post('/events/join-by-code', {
      'invite_code': inviteCode,
    });
    await fetchMyEvents();
    return response;
  }

  Future<String> startSession(String eventId) async {
    final response = await _api.post('/sessions/start', {'event_id': eventId});
    return response['session_id'];
  }

  Future<Map<String, dynamic>> stopSession(
      String sessionId, int points, int durationSec) async {
    final response = await _api.post('/sessions/stop', {
      'session_id': sessionId,
      'points': points,
      'duration_sec': durationSec,
    });
    return response;
  }

  Future<List<dynamic>> getLeaderboard(String eventId) async {
    final response = await _api.get('/events/$eventId/leaderboard');
    return response;
  }

  Future<Map<String, dynamic>> getEvent(String eventId) async {
    final response = await _api.get('/events/$eventId');
    return response;
  }

  Future<void> updateEventStatus(String eventId, String status) async {
    await _api.patch('/events/$eventId/status', {'status': status});
    await fetchEvents();
    await fetchMyEvents();
    notifyListeners();
  }

  Future<List<dynamic>> getMyEventSessions(String eventId) async {
    final response = await _api.get('/sessions/my?event_id=$eventId');
    return response as List<dynamic>;
  }
}
