import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config.dart';
import 'api_service.dart';
import 'event_service.dart';
import 'dance_session_manager.dart';
import 'solo_session_manager.dart';
import 'motion_scoring_service.dart';
import 'leaderboard_service.dart';

class AuthService with ChangeNotifier {
  final ApiService _api = ApiService();
  bool _isAuth = false;
  String? _token;
  String? _userId;

  bool get isAuth => _isAuth;
  String? get userId => _userId;

  Future<void> register(String email, String password, String username) async {
    try {
      await _api.post('/auth/register', {
        'email': email,
        'password': password,
        'username': username,
      });
      // Auto login after register? Or just login.
      await login(email, password);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _api.post('/auth/login', {
        'email': email,
        'password': password,
      });

      _token = response['token'];
      _userId = response['user']['id'];
      _isAuth = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('userId', _userId!);

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: AppConfig.googleClientId,
        scopes: ['email', 'profile', 'openid'],
      );
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('User cancelled the Google Sign-In popup.');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      // Log tokens for debugging (obfuscated)
      debugPrint('Google Login: idToken is ${idToken != null ? "present" : "missing"}, accessToken is ${accessToken != null ? "present" : "missing"}');

      final response = await _api.post('/auth/google', {
        if (idToken != null) 'idToken': idToken,
        if (accessToken != null) 'accessToken': accessToken,
      });

      _token = response['token'];
      _userId = response['user']['id'];
      _isAuth = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('userId', _userId!);

      notifyListeners();
    } catch (e) {
      debugPrint('Google Login Error Details: $e');
      rethrow;
    }
  }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('token')) return;

    _token = prefs.getString('token');
    _userId = prefs.getString('userId');
    _isAuth = true;
    notifyListeners();
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    final response = await _api.get('/auth/me');
    return response;
  }

  Future<String> uploadAvatar(Uint8List imageBytes, String fileName) async {
    final response = await _api.postMultipart(
      '/auth/avatar',
      {},
      imageBytes,
      fileName: fileName,
      fileFieldName: 'avatar',
    );
    return response['avatar_url'];
  }

  Future<void> updateProfile(String newUsername) async {
    try {
      await _api.patch('/auth/update', {'username': newUsername});
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAccount({
    EventService? eventService,
    DanceSessionManager? danceSessionManager,
    SoloSessionManager? soloSessionManager,
    MotionScoringService? motionScoringService,
    LeaderboardService? leaderboardService,
  }) async {
    try {
      await _api.delete('/auth/delete-account');
      await logout(
        eventService: eventService,
        danceSessionManager: danceSessionManager,
        soloSessionManager: soloSessionManager,
        motionScoringService: motionScoringService,
        leaderboardService: leaderboardService,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout({
    EventService? eventService,
    DanceSessionManager? danceSessionManager,
    SoloSessionManager? soloSessionManager,
    MotionScoringService? motionScoringService,
    LeaderboardService? leaderboardService,
  }) async {
    _token = null;
    _userId = null;
    _isAuth = false;

    // Reset all provided session services to clear global state safely
    eventService?.reset();
    danceSessionManager?.reset();
    soloSessionManager?.reset();
    motionScoringService?.stop();
    motionScoringService?.reset();
    leaderboardService?.reset();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}

