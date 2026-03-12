import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../models/rank_model.dart';

class RankService with ChangeNotifier {
  final ApiService _api = ApiService();

  UserRank? _myRank;
  UserRank? get myRank => _myRank;

  List<Top100Entry>? _top100;
  List<Top100Entry>? get top100 => _top100;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// Fetch current user's rank info
  Future<UserRank?> fetchMyRank() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get('/ranks/me');
      _myRank = UserRank.fromJson(response);
      return _myRank;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch Top 100 monthly leaderboard
  Future<List<Top100Entry>> fetchTop100() async {
    try {
      final response = await _api.get('/ranks/top100');
      final list = (response as List)
          .map((e) => Top100Entry.fromJson(e))
          .toList();
      _top100 = list;
      notifyListeners();
      return list;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Get rank from the /me profile data (lightweight, no extra request)
  static UserRankQuick fromProfileData(Map<String, dynamic> profileData) {
    return UserRankQuick(
      rank: profileData['rank'] ?? 'ghost',
      monthlyPoints: profileData['monthly_points'] ?? 0,
      badges: (profileData['badges'] as List?)
              ?.map((b) => Badge.fromJson(b))
              .toList() ??
          [],
    );
  }
}

/// Lightweight rank data that comes with /auth/me (no extra API call needed)
class UserRankQuick {
  final String rank;
  final int monthlyPoints;
  final List<Badge> badges;

  UserRankQuick({
    required this.rank,
    required this.monthlyPoints,
    required this.badges,
  });
}
