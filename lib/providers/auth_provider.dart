import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  // SharedPreferences keys
  static const _keyIsLoggedIn = 'isLoggedIn';
  static const _keyUserName = 'userName';
  static const _keyUserEmail = 'userEmail';
  static const _keyUserPhone = 'userPhone';
  static const _keyUserUid = 'userUid';
  static const _keyContacts = 'userContacts';

  AuthProvider() {
    _loadSession(); // App start aana auto load
  }

  // Load saved session from SharedPreferences
  Future<void> _loadSession() async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;

      if (loggedIn) {
        final uid = prefs.getString(_keyUserUid) ?? '';
        final name = prefs.getString(_keyUserName) ?? '';
        final email = prefs.getString(_keyUserEmail) ?? '';
        final phone = prefs.getString(_keyUserPhone) ?? '';
        final contacts = prefs.getStringList(_keyContacts) ?? [];

        if (uid.isNotEmpty && email.isNotEmpty) {
          _currentUser = UserModel(
            uid: uid,
            fullName: name,
            email: email,
            phoneNumber: phone,
            approvedContacts: contacts,
            isLocationSharing: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          _isLoggedIn = true;
        }
      }
    } catch (e) {
      _isLoggedIn = false;
    }
    _setLoading(false);
  }

  // Save session to SharedPreferences
  Future<void> _saveSession(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserUid, user.uid);
      await prefs.setString(_keyUserName, user.fullName);
      await prefs.setString(_keyUserEmail, user.email);
      await prefs.setString(_keyUserPhone, user.phoneNumber);
      await prefs.setStringList(_keyContacts, user.approvedContacts);
    } catch (e) {
      // Silent fail
    }
  }

  // Clear session
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserUid);
      await prefs.remove(_keyUserName);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyUserPhone);
      await prefs.remove(_keyContacts);
    } catch (e) {
      // Silent fail
    }
  }

  // Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 800));

    // TODO: Replace with Firebase auth
    if (email.trim().isEmpty || password.trim().isEmpty) {
      _setLoading(false);
      return {'success': false, 'error': 'Email and password required'};
    }
    if (password.length < 6) {
      _setLoading(false);
      return {'success': false, 'error': 'Invalid credentials'};
    }

    // Create user from entered credentials
    _currentUser = UserModel(
      uid: 'uid_${email.hashCode.abs()}',
      fullName: email.split('@').first.replaceAll('.', ' ').split(' ')
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
          .join(' '),
      email: email.trim(),
      phoneNumber: '',
      approvedContacts: ['Amma: +91 XXXXX XXXXX', 'Appa: +91 XXXXX XXXXX', 'Friend: +91 XXXXX XXXXX'],
      isLocationSharing: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _isLoggedIn = true;

    // Save session — app close aanalum persist aagum
    await _saveSession(_currentUser!);

    _setLoading(false);
    notifyListeners();
    return {'success': true};
  }

  // Signup
  Future<Map<String, dynamic>> signUp({
    required String fullName,
    required String email,
    required String password,
    required String phoneNumber,
  }) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 800));

    // TODO: Replace with Firebase auth
    _currentUser = UserModel(
      uid: 'uid_${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName.trim(),
      email: email.trim(),
      phoneNumber: phoneNumber.trim(),
      approvedContacts: ['Amma: +91 XXXXX XXXXX', 'Appa: +91 XXXXX XXXXX', 'Friend: +91 XXXXX XXXXX'],
      isLocationSharing: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _isLoggedIn = true;

    // Save session
    await _saveSession(_currentUser!);

    _setLoading(false);
    notifyListeners();
    return {'success': true};
  }

  // Logout — clear session
  Future<void> logout() async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 300));
    // TODO: Firebase signOut
    _currentUser = null;
    _isLoggedIn = false;
    await _clearSession(); // Clear saved session
    _setLoading(false);
    notifyListeners();
  }

  // Reset password
  Future<Map<String, dynamic>> resetPassword(String email) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 800));
    // TODO: Firebase reset password
    _setLoading(false);
    return {'success': true};
  }

  // Add contact — save to prefs
  Future<bool> addContact(String email) async {
    if (_currentUser == null) return false;
    if (_currentUser!.approvedContacts.contains(email)) return false;

    final updated = List<String>.from(_currentUser!.approvedContacts)..add(email);
    _currentUser = _currentUser!.copyWith(approvedContacts: updated);

    // Save updated contacts
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyContacts, updated);
    } catch (e) {}

    notifyListeners();
    return true;
  }

  // Remove contact — save to prefs
  Future<bool> removeContact(String email) async {
    if (_currentUser == null) return false;

    final updated = List<String>.from(_currentUser!.approvedContacts)..remove(email);
    _currentUser = _currentUser!.copyWith(approvedContacts: updated);

    // Save updated contacts
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyContacts, updated);
    } catch (e) {}

    notifyListeners();
    return true;
  }

  // Toggle location sharing
  Future<void> toggleLocationSharing() async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
        isLocationSharing: !_currentUser!.isLocationSharing);
    notifyListeners();
  }

  // Update profile — save to prefs
  Future<bool> updateProfile({String? fullName, String? phoneNumber}) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 300));

    _currentUser = _currentUser!.copyWith(
      fullName: fullName ?? _currentUser!.fullName,
      phoneNumber: phoneNumber ?? _currentUser!.phoneNumber,
    );

    // Save updated profile
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserName, _currentUser!.fullName);
      await prefs.setString(_keyUserPhone, _currentUser!.phoneNumber);
    } catch (e) {}

    _setLoading(false);
    notifyListeners();
    return true;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}