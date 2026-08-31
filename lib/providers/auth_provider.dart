import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/emergency_contact_model.dart';
import '../models/user_activity_model.dart';
import '../core/services/auth_service.dart';
import '../core/services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<fb_auth.User?>? _authSub;

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  // Local cache key — only used for the profile photo (kept out of
  // Firestore to avoid bloating documents with base64 blobs).
  static const _keyProfileImage = 'userProfileImageBase64';

  AuthProvider() {
    _init();
  }

  // Listen to Firebase's own auth session — this is what gives us
  // "stay logged in after app restart" for free, no manual prefs needed.
  Future<void> _init() async {
    _setLoading(true);
    _authSub = _authService.authStateChanges.listen((fbUser) async {
      if (fbUser == null) {
        _currentUser = null;
        _isLoggedIn = false;
        notifyListeners();
        return;
      }
      await _loadUserData(fbUser);
    });
    _setLoading(false);
  }

  // Fetches the Firestore user doc for a just-authenticated Firebase user
  // and populates _currentUser. Shared by the auth-state listener (handles
  // "already logged in on app restart") AND by login()/signUp() directly
  // (see below) — calling it synchronously from login()/signUp() means
  // _currentUser is guaranteed to be populated by the time those futures
  // resolve, instead of racing an arbitrary fixed delay against however
  // long the Firestore read actually takes.
  Future<void> _loadUserData(fb_auth.User fbUser) async {
    final data = await _authService.getUserData(fbUser.uid);
    final prefs = await SharedPreferences.getInstance();
    final cachedImage = prefs.getString(_keyProfileImage);

    final emergencyContacts = (data?['emergencyContacts'] as List<dynamic>? ?? [])
        .map((e) => EmergencyContact.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    // approvedContacts should always exactly mirror the emails of real,
    // currently-saved emergency contacts. If it doesn't (e.g. leftover
    // "Name: Phone" strings from a legacy quick-add flow that never
    // created a matching EmergencyContact — those had no way to ever be
    // removed by the user), heal it here rather than let stale/garbage
    // entries silently inflate the Contacts count and Safety Score
    // forever.
    final validEmails = emergencyContacts.where((c) => c.email.isNotEmpty).map((c) => c.email).toSet();
    final storedApproved = List<String>.from(data?['approvedContacts'] ?? []);
    final cleanedApproved = storedApproved.where(validEmails.contains).toList();
    if (cleanedApproved.length != storedApproved.length) {
      unawaited(_authService.updateUserData(fbUser.uid, {'approvedContacts': cleanedApproved}));
    }

    _currentUser = UserModel(
      uid: fbUser.uid,
      fullName: data?['fullName'] ?? fbUser.displayName ?? '',
      email: data?['email'] ?? fbUser.email ?? '',
      phoneNumber: data?['phoneNumber'] ?? '',
      profileImageUrl: data?['profileImageUrl'] ?? cachedImage,
      approvedContacts: cleanedApproved,
      emergencyContacts: emergencyContacts,
      isLocationSharing: data?['isLocationSharing'] ?? false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _isLoggedIn = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // Login — real Firebase Auth
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    final result = await _authService.signIn(email: email, password: password);
    _setLoading(false);
    if (result['success'] != true) {
      return {'success': false, 'error': result['error']};
    }
    // Real login event, written to Firestore immediately — feeds the
    // "Login Successfully" entry on the Notifications screen.
    final fbUser = result['user'] as fb_auth.User?;
    if (fbUser != null) {
      unawaited(_firestoreService.logActivity(fbUser.uid, UserActivityType.login));
      // Load the Firestore user doc HERE and wait for it, instead of
      // guessing with a fixed delay. The _authSub listener will also fire
      // for this same sign-in and call _loadUserData again — harmless,
      // it just re-sets the same data — but this call is what guarantees
      // _currentUser is populated by the time login() returns, so the
      // screen the caller navigates to next never renders with an empty
      // user.
      await _loadUserData(fbUser);
    }
    return {'success': true};
  }

  // Signup — real Firebase Auth + Firestore user doc
  Future<Map<String, dynamic>> signUp({
    required String fullName,
    required String email,
    required String password,
    required String phoneNumber,
  }) async {
    _setLoading(true);
    final result = await _authService.signUp(
      fullName: fullName.trim(),
      email: email.trim(),
      password: password,
      phoneNumber: phoneNumber.trim(),
    );
    _setLoading(false);
    if (result['success'] != true) {
      return {'success': false, 'error': result['error']};
    }
    // Same fix as login() — load the new user's Firestore doc and wait
    // for it directly, instead of a fixed delay racing the auth listener.
    final fbUser = result['user'] as fb_auth.User?;
    if (fbUser != null) {
      await _loadUserData(fbUser);
    }
    return {'success': true};
  }

  // Logout
  Future<void> logout() async {
    _setLoading(true);
    // Log the real logout event before the session/uid disappear —
    // feeds the "Logout" entry on the Notifications screen.
    if (_currentUser != null) {
      unawaited(_firestoreService.logActivity(_currentUser!.uid, UserActivityType.logout));
    }
    await _authService.signOut();
    _currentUser = null;
    _isLoggedIn = false;
    _setLoading(false);
    notifyListeners();
  }

  // Reset password — real Firebase email
  Future<Map<String, dynamic>> resetPassword(String email) async {
    _setLoading(true);
    final result = await _authService.resetPassword(email.trim());
    _setLoading(false);
    return result;
  }

  // Add a named emergency contact (name + phone + optional email + relation).
  // approvedContacts (emails) is always fully rebuilt from emergencyContacts
  // below — never patched incrementally — so it can't drift out of sync.
  Future<bool> addEmergencyContact({
    required String name,
    required String phone,
    String email = '',
    required String relation,
  }) async {
    if (_currentUser == null) return false;

    final contact = EmergencyContact(id: const Uuid().v4(), name: name, phone: phone, email: email, relation: relation);
    final updatedContacts = List<EmergencyContact>.from(_currentUser!.emergencyContacts)..add(contact);
    final updatedEmails = updatedContacts.where((c) => c.email.isNotEmpty).map((c) => c.email).toSet().toList();

    final ok = await _authService.updateUserData(_currentUser!.uid, {
      'emergencyContacts': updatedContacts.map((e) => e.toMap()).toList(),
      'approvedContacts': updatedEmails,
    });
    if (!ok) return false;

    _currentUser = _currentUser!.copyWith(emergencyContacts: updatedContacts, approvedContacts: updatedEmails);
    notifyListeners();
    return true;
  }

  // Edit an existing emergency contact in place.
  Future<bool> updateEmergencyContact({
    required String id,
    required String name,
    required String phone,
    String email = '',
    required String relation,
  }) async {
    if (_currentUser == null) return false;
    final list = _currentUser!.emergencyContacts;
    final index = list.indexWhere((c) => c.id == id);
    if (index == -1) return false;

    final updatedContacts = List<EmergencyContact>.from(list);
    updatedContacts[index] = list[index].copyWith(name: name, phone: phone, email: email, relation: relation);
    final updatedEmails = updatedContacts.where((c) => c.email.isNotEmpty).map((c) => c.email).toSet().toList();

    final ok = await _authService.updateUserData(_currentUser!.uid, {
      'emergencyContacts': updatedContacts.map((e) => e.toMap()).toList(),
      'approvedContacts': updatedEmails,
    });
    if (!ok) return false;

    _currentUser = _currentUser!.copyWith(emergencyContacts: updatedContacts, approvedContacts: updatedEmails);
    notifyListeners();
    return true;
  }

  // Delete an emergency contact — approvedContacts is rebuilt from what's
  // left, so the removed contact's email (if any) is gone with it, and it
  // can never come back as a leftover.
  Future<bool> deleteEmergencyContact(String id) async {
    if (_currentUser == null) return false;
    final list = _currentUser!.emergencyContacts;
    final target = list.where((c) => c.id == id).toList();
    if (target.isEmpty) return false;

    final updatedContacts = list.where((c) => c.id != id).toList();
    final updatedEmails = updatedContacts.where((c) => c.email.isNotEmpty).map((c) => c.email).toSet().toList();

    final ok = await _authService.updateUserData(_currentUser!.uid, {
      'emergencyContacts': updatedContacts.map((e) => e.toMap()).toList(),
      'approvedContacts': updatedEmails,
    });
    if (!ok) return false;

    _currentUser = _currentUser!.copyWith(emergencyContacts: updatedContacts, approvedContacts: updatedEmails);
    notifyListeners();
    return true;
  }

  // Toggle location sharing — Firestore + local model update
  Future<void> toggleLocationSharing() async {
    if (_currentUser == null) return;
    await setLocationSharing(!_currentUser!.isLocationSharing);
  }

  // Explicitly set location sharing to match what's really happening —
  // called by the real live-location start/stop flow (Live Location
  // screen) so the Safety Score's Location Sharing factor reflects the
  // user's actual GPS sharing action, not just this standalone switch.
  Future<void> setLocationSharing(bool value) async {
    if (_currentUser == null || _currentUser!.isLocationSharing == value) return;
    await _authService.updateUserData(_currentUser!.uid, {
      'isLocationSharing': value,
    });
    _currentUser = _currentUser!.copyWith(isLocationSharing: value);
    // Log only the moment sharing turns on — feeds the real "Live
    // Location Shared" entry on the Notifications screen.
    if (value) {
      unawaited(_firestoreService.logActivity(_currentUser!.uid, UserActivityType.locationShared));
    }
    notifyListeners();
  }

  // Update profile — Firestore + local model update
  Future<bool> updateProfile({String? fullName, String? phoneNumber}) async {
    if (_currentUser == null) return false;
    _setLoading(true);

    final data = <String, dynamic>{};
    if (fullName != null) data['fullName'] = fullName;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;

    final ok = await _authService.updateUserData(_currentUser!.uid, data);
    if (ok) {
      _currentUser = _currentUser!.copyWith(
        fullName: fullName ?? _currentUser!.fullName,
        phoneNumber: phoneNumber ?? _currentUser!.phoneNumber,
      );
    }
    _setLoading(false);
    notifyListeners();
    return ok;
  }

  // Update profile photo — stored as base64 string, same as before.
  // Kept in local prefs (not Firestore) to avoid document bloat; swap
  // this for Firebase Storage upload later if you want it synced across
  // devices.
  Future<bool> updateProfileImage(String base64Image) async {
    if (_currentUser == null) return false;
    _currentUser = _currentUser!.copyWith(profileImageUrl: base64Image);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyProfileImage, base64Image);
    } catch (e) {
      // Silent fail — non-critical
    }

    notifyListeners();
    return true;
  }

  // Remove profile photo
  Future<void> removeProfileImage() async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(profileImageUrl: null);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyProfileImage);
    } catch (e) {
      // Silent fail
    }

    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}