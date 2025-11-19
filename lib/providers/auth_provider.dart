import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/d1vai_service.dart';

class AuthProvider extends ChangeNotifier {
  final D1vaiService _d1vaiService = D1vaiService();
  User? _user;
  bool _isLoading = true;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      try {
        _user = await _d1vaiService.getUserProfile();
      } catch (e) {
        // Token invalid or expired
        await prefs.remove('auth_token');
        _user = null;
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {
      final token = await _d1vaiService.postUserPasswordLogin(email, password);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      
      _user = await _d1vaiService.getUserProfile();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _user = null;
    notifyListeners();
  }
}

