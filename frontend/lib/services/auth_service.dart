import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

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

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _isAuth = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
