import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../models/leaderboard_model.dart';

class LeaderboardService with ChangeNotifier {
  final ApiService _api = ApiService();

  LeaderboardResponse? _currentData;
  LeaderboardResponse? get currentData => _currentData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Timer? _pollingTimer;

  // Single fetch
  Future<void> fetchLeaderboard(String eventId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get('/events/$eventId/leaderboard');
      _currentData = LeaderboardResponse.fromJson(response);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Polling
  void startPolling(String eventId) {
    stopPolling();
    // Initial fetch
    fetchLeaderboard(eventId);
    // Poll every 5 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final response = await _api.get('/events/$eventId/leaderboard');
        _currentData = LeaderboardResponse.fromJson(response);
        notifyListeners();
      } catch (e) {
        // silently ignore polling errors or log?
        print("Polling error: $e");
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
