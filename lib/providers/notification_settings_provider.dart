import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple on/off switch for whether the app should surface notifications
/// (the bell badge on Home and the switch on the Notifications screen /
/// Settings screen). Persisted locally so it survives app restarts.
class NotificationSettingsProvider extends ChangeNotifier {
  static const _prefsKey = 'notifications_enabled';

  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  NotificationSettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool(_prefsKey) ?? true;
      notifyListeners();
    } catch (_) {
      // Silent fail — defaults to enabled for this session.
    }
  }

  Future<void> setEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {
      // Silent fail — setting just won't persist this session.
    }
  }
}