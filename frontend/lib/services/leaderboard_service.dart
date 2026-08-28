import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../models/leaderboard_model.dart';

class LeaderboardService with ChangeNotifier {
  final ApiService _api = ApiService();
  bool _isDisposed = false;

  LeaderboardResponse? _currentData;
  LeaderboardResponse? get currentData => _currentData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Timer? _pollingTimer;

  // Which event the timer is polling. The live dance screen sits on top of the
  // event detail screen, so both read the same standings; tracking the event
  // lets the second one join in instead of restarting the timer.
  String? _pollingEventId;
  String? get pollingEventId => _pollingEventId;

  // When the standings we hold were built server-side (they are shared across
  // the event for a few seconds), falling back to our own clock. The dance
  // screen shows this age, since rivals only move when the table is rebuilt.
  DateTime? _lastUpdatedAt;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  // Single fetch
  Future<void> fetchLeaderboard(String eventId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get('/events/$eventId/leaderboard');
      if (_isDisposed) return;
      _currentData = LeaderboardResponse.fromJson(response);
      _lastUpdatedAt = _currentData?.updatedAt ?? DateTime.now();
    } catch (e) {
      if (_isDisposed) return;
      _error = e.toString();
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Polling
  void startPolling(String eventId) {
    stopPolling();
    _pollingEventId = eventId;
    // Initial fetch
    fetchLeaderboard(eventId);
    // Poll every 15 seconds (keeps a multi-hour session well under the
    // server rate limit while still feeling live)
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        final response = await _api.get('/events/$eventId/leaderboard');
        if (_isDisposed) return;
        _currentData = LeaderboardResponse.fromJson(response);
        _lastUpdatedAt = _currentData?.updatedAt ?? DateTime.now();
        notifyListeners();
      } catch (e) {
        // silently ignore polling errors or log?
        debugPrint("Polling error: $e");
      }
    });
  }

  /// Poll [eventId] only if that isn't already happening. For screens that
  /// want to read the standings without owning their lifecycle — they must not
  /// call [stopPolling] on the way out, or they kill the screen underneath.
  void ensurePolling(String eventId) {
    if (_pollingTimer != null && _pollingEventId == eventId) return;
    startPolling(eventId);
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _pollingEventId = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopPolling();
    super.dispose();
  }

  void reset() {
    _currentData = null;
    _isLoading = false;
    _error = null;
    _lastUpdatedAt = null;
    stopPolling();
    if (!_isDisposed) {
      notifyListeners();
    }
  }
}
