import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/notification_settings_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../core/services/location_service.dart';
import '../auth/login_screen.dart';
import '../contacts/approved_contacts_screen.dart';
import '../notifications/notifications_screen.dart';
import 'edit_profile_screen.dart';

/// Settings screen — every value shown here comes from AuthProvider,
/// ThemeProvider, NotificationSettingsProvider or NotificationsProvider
/// (for the unread badge). Nothing is hardcoded, so nothing here can drift
/// out of sync with what the rest of the app already knows about the
/// signed-in user.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kSharingModeKey = 'default_sharing_mode';
  static const _kAutoStopKey = 'auto_stop_sharing';
  static const _kLanguageKey = 'app_language';
  static const _languages = ['English', 'Tamil', 'Hindi', 'Telugu'];

  String _sharingMode = 'Live';
  bool _autoStopSharing = true;
  String _language = 'English';
  bool _prefsLoaded = false;

  // ---- Hidden developer credit: tap "About SecureRide" 7 times within
  // 3 seconds to reveal it. A normal single tap (or a slow tap that never
  // reaches 7) still opens the plain About dialog — nothing changes there.
  // The dialog only opens once taps STOP for a beat, because opening it
  // on every tap would pop a modal after tap #1 and block further taps
  // from ever reaching the tile.
  int _aboutTapCount = 0;
  DateTime? _aboutFirstTapAt;
  Timer? _aboutDebounce;

  @override
  void initState() {
    super.initState();
    _loadLocalPrefs();
  }

  @override
  void dispose() {
    _aboutDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _sharingMode = prefs.getString(_kSharingModeKey) ?? 'Live';
        _autoStopSharing = prefs.getBool(_kAutoStopKey) ?? true;
        _language = prefs.getString(_kLanguageKey) ?? 'English';
        _prefsLoaded = true;
      });
    } catch (_) {
      setState(() => _prefsLoaded = true);
    }
  }

  Future<void> _setSharingMode(String mode) async {
    setState(() => _sharingMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSharingModeKey, mode);
    } catch (_) {}
  }

  Future<void> _setAutoStop(bool value) async {
    setState(() => _autoStopSharing = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAutoStopKey, value);
    } catch (_) {}
  }

  Future<void> _setLanguage(String lang) async {
    setState(() => _language = lang);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLanguageKey, lang);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    context.watch<NotificationSettingsProvider>();
    final unreadCount = context.watch<NotificationsProvider>().unreadCount;
    final user = auth.currentUser;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final hasPhoto = (user?.profileImageUrl?.isNotEmpty == true);

    if (!_prefsLoaded) {
      return Scaffold(backgroundColor: bg, body: const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8))));
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(clipBehavior: Clip.none, children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                    child: Text('$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ---- Profile card ----
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.35)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 8)]),
            child: Column(children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                child: Row(children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                    backgroundImage: hasPhoto ? MemoryImage(base64Decode(user!.profileImageUrl!)) : null,
                    child: hasPhoto
                        ? null
                        : Text((user?.fullName.isNotEmpty == true) ? user!.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user?.fullName.isNotEmpty == true ? user!.fullName : 'User',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: tp)),
                      Text(user?.email ?? '', style: TextStyle(fontSize: 12, color: ts)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: ts),
                ]),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                  icon: const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF1A73E8)),
                  label: const Text('View Profile', style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1A73E8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 22),

          // ====== PREFERENCES ======
          _sectionTitle('PREFERENCES'),
          _tile(context, icon: Icons.notifications_rounded, title: 'Notifications',
              subtitle: 'Manage notification preferences',
              color: const Color(0xFF3B82F6), card: card, tp: tp, ts: ts,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
          _tile(context, icon: Icons.dark_mode_rounded, title: 'Appearance',
              subtitle: isDark ? 'Dark Mode' : 'Light Mode',
              color: const Color(0xFF7C3AED), card: card, tp: tp, ts: ts,
              trailingWidget: Switch(value: isDark, onChanged: (_) => context.read<ThemeProvider>().toggleTheme(),
                  activeColor: const Color(0xFF1A73E8))),
          _tile(context, icon: Icons.language_rounded, title: 'Language',
              subtitle: _language,
              color: const Color(0xFF3B82F6), card: card, tp: tp, ts: ts,
              onTap: () => _showLanguagePicker(card, tp, ts)),
          _tile(context, icon: Icons.location_on_rounded, title: 'Location',
              subtitle: 'Manage location permissions',
              color: const Color(0xFF22C55E), card: card, tp: tp, ts: ts,
              onTap: () => _showLocationSettings(context, user, card, tp, ts)),

          const SizedBox(height: 18),

          // ====== TRIP SETTINGS ======
          _sectionTitle('TRIP SETTINGS'),
          _tile(context, icon: Icons.groups_rounded, title: 'Default Sharing Mode',
              subtitle: 'Choose your default sharing mode',
              color: const Color(0xFFF59E0B), card: card, tp: tp, ts: ts,
              trailingText: _sharingMode,
              trailingTextColor: _sharingMode == 'Live' ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
              ts2: ts,
              onTap: () => _setSharingMode(_sharingMode == 'Live' ? 'Manual' : 'Live')),
          _tile(context, icon: Icons.timer_rounded, title: 'Auto Stop Sharing',
              subtitle: 'Stop sharing after trip ends',
              color: const Color(0xFF1A73E8), card: card, tp: tp, ts: ts,
              trailingWidget: Switch(value: _autoStopSharing, onChanged: _setAutoStop,
                  activeColor: const Color(0xFF1A73E8))),
          _tile(context, icon: Icons.call_rounded, title: 'Emergency Contacts',
              subtitle: 'Manage your emergency contacts',
              color: const Color(0xFFEF4444), card: card, tp: tp, ts: ts,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApprovedContactsScreen()))),

          const SizedBox(height: 18),

          // ====== SUPPORT ======
          _sectionTitle('SUPPORT'),
          _tile(context, icon: Icons.headset_mic_rounded, title: 'Help & Support',
              subtitle: 'Get help and find answers',
              color: const Color(0xFF1A73E8), card: card, tp: tp, ts: ts,
              onTap: () => _showHelp(context, card, tp, ts)),
          _tile(context, icon: Icons.description_rounded, title: 'Terms & Conditions',
              subtitle: 'Read our terms and conditions',
              color: const Color(0xFF22C55E), card: card, tp: tp, ts: ts,
              onTap: () => _showTerms(context, card, tp, ts)),
          _tile(context, icon: Icons.shield_rounded, title: 'Privacy Policy',
              subtitle: 'Your data is safe with us',
              color: const Color(0xFF7C3AED), card: card, tp: tp, ts: ts,
              onTap: () => _showPrivacy(context, card, tp, ts)),
          _tile(context, icon: Icons.info_outline_rounded, title: 'About SecureRide',
              subtitle: 'App version and information',
              color: const Color(0xFF6B7280), card: card, tp: tp, ts: ts,
              trailingText: 'v1.0.0', trailingTextColor: ts, ts2: ts,
              onTap: () => _onAboutTap(context, card, tp, ts)),

          const SizedBox(height: 24),

          // ---- Logout ----
          SizedBox(width: double.infinity, height: 52,
              child: OutlinedButton.icon(
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                  label: const Text('Logout', style: TextStyle(color: Color(0xFFEF4444), fontSize: 16, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          const SizedBox(height: 14),

          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: ts),
              const SizedBox(width: 6),
              Text('Your data is encrypted and secure', style: TextStyle(fontSize: 12, color: ts)),
            ]),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ---- Section header ----
  Widget _sectionTitle(String title) => Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2, top: 4),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8), letterSpacing: 0.8)));

  // ---- Reusable list tile ----
  Widget _tile(BuildContext context, {required IconData icon, required String title, required String subtitle,
    required Color color, required Color card, required Color tp, required Color ts,
    VoidCallback? onTap, String? trailingText, Color? trailingTextColor, Color? ts2, Widget? trailingWidget}) {
    Widget? trailing;
    if (trailingWidget != null) {
      trailing = trailingWidget;
    } else if (trailingText != null) {
      trailing = Row(mainAxisSize: MainAxisSize.min, children: [
        Text(trailingText, style: TextStyle(color: trailingTextColor ?? color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right_rounded, color: ts2 ?? ts),
      ]);
    } else if (onTap != null) {
      trailing = Icon(Icons.chevron_right_rounded, color: ts);
    }
    return Container(margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
        child: ListTile(
            leading: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20)),
            title: Text(title, style: TextStyle(color: tp, fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(subtitle, style: TextStyle(color: ts, fontSize: 12)),
            trailing: trailing,
            onTap: onTap));
  }

  // ---- About tap counter — 7 rapid taps reveals the hidden credit dialog
  // instead of the plain About dialog that tap. Any gap over 3s between
  // taps resets the count, so it can never trigger by accident. ----
  void _onAboutTap(BuildContext context, Color card, Color tp, Color ts) {
    final now = DateTime.now();
    if (_aboutFirstTapAt == null || now.difference(_aboutFirstTapAt!) > const Duration(seconds: 3)) {
      _aboutTapCount = 0;
      _aboutFirstTapAt = now;
    }
    _aboutTapCount++;
    _aboutDebounce?.cancel();

    if (_aboutTapCount >= 7) {
      _aboutTapCount = 0;
      _aboutFirstTapAt = null;
      _showDeveloperCredit(context, card, tp, ts);
      return;
    }

    // Wait a beat for another tap before opening anything — this is what
    // lets several taps land on the tile before a modal ever appears.
    _aboutDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _aboutTapCount = 0;
      _aboutFirstTapAt = null;
      showAboutDialog(
        context: context,
        applicationName: 'SecureRide',
        applicationVersion: '1.0.0',
        applicationLegalese: '© 2025 SecureRide • Safe. Private. Connected.',
      );
    });
  }

  void _showDeveloperCredit(BuildContext context, Color card, Color tp, Color ts) {
    showDialog(context: context, builder: (dctx) => Dialog(
      backgroundColor: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 64, height: 64,
              decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(Icons.code_rounded, color: Color(0xFF1A73E8), size: 32)),
          const SizedBox(height: 16),
          Text('Developed by', style: TextStyle(color: ts, fontSize: 12)),
          const SizedBox(height: 4),
          Text('Dhavarsanam Murugesh',
              textAlign: TextAlign.center,
              style: TextStyle(color: tp, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity,
              child: ElevatedButton(
                  onPressed: () => Navigator.pop(dctx),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)))),
        ]),
      ),
    ));
  }

  // ---- Language picker ----
  void _showLanguagePicker(Color card, Color tp, Color ts) {
    showDialog(context: context, builder: (dctx) => AlertDialog(
      backgroundColor: card,
      title: Text('Choose Language', style: TextStyle(color: tp, fontSize: 18, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: _languages.map((lang) => RadioListTile<String>(
        value: lang,
        groupValue: _language,
        activeColor: const Color(0xFF1A73E8),
        title: Text(lang, style: TextStyle(color: tp, fontSize: 14)),
        onChanged: (v) {
          if (v != null) _setLanguage(v);
          Navigator.pop(dctx);
        },
      )).toList()),
      actions: [TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Close', style: TextStyle(color: Color(0xFF1A73E8))))],
    ));
  }

  // ---- Location permissions & sharing ----
  void _showLocationSettings(BuildContext context, dynamic user, Color card, Color tp, Color ts) {
    String? status;
    bool checking = false;
    showDialog(context: context, builder: (dctx) => StatefulBuilder(
      builder: (dctx, setDialogState) {
        final liveUser = dctx.watch<AuthProvider>().currentUser;
        return AlertDialog(
          backgroundColor: card,
          title: Text('Location Settings', style: TextStyle(color: tp, fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.share_location_rounded, size: 18, color: Color(0xFF22C55E)),
              const SizedBox(width: 10),
              Expanded(child: Text('Location Sharing', style: TextStyle(color: tp, fontSize: 13, fontWeight: FontWeight.w600))),
              Switch(
                value: liveUser?.isLocationSharing ?? false,
                activeColor: const Color(0xFF1A73E8),
                onChanged: null, // read-only here — actual sharing is started/stopped from Map → Live Location
              ),
            ]),
            const SizedBox(height: 4),
            Text('Turn this on from Map → Live Location — it reflects your real, active location sharing.',
                style: TextStyle(color: ts, fontSize: 11, height: 1.3)),
            const SizedBox(height: 12),
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(status!, style: TextStyle(color: ts, fontSize: 12, height: 1.4)),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: checking ? null : () async {
                  setDialogState(() => checking = true);
                  final service = LocationService();
                  final ok = await service.checkPermission();
                  setDialogState(() {
                    checking = false;
                    status = ok ? 'Location permission is granted.' : (service.lastErrorMessage ?? 'Permission not granted.');
                  });
                },
                icon: const Icon(Icons.gps_fixed_rounded, size: 16, color: Color(0xFF1A73E8)),
                label: Text(checking ? 'Checking…' : 'Check / Request Permission',
                    style: const TextStyle(color: Color(0xFF1A73E8), fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1A73E8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Close', style: TextStyle(color: Color(0xFF1A73E8))))],
        );
      },
    ));
  }

  Widget _infoRow(IconData icon, String label, String value, Color tp, Color ts) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 18, color: const Color(0xFF1A73E8)),
      const SizedBox(width: 10),
      Text('$label: ', style: TextStyle(color: ts, fontSize: 13)),
      Expanded(child: Text(value, style: TextStyle(color: tp, fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );

  void _showHelp(BuildContext context, Color card, Color tp, Color ts) {
    showDialog(context: context, builder: (dctx) => AlertDialog(
      backgroundColor: card,
      title: Text('Help & Support', style: TextStyle(color: tp, fontSize: 18, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Need help? Reach us anytime:', style: TextStyle(color: ts, fontSize: 13)),
        const SizedBox(height: 12),
        _infoRow(Icons.email_outlined, 'Email', 'support@secureride.com', tp, ts),
        _infoRow(Icons.call_outlined, 'Helpline', '+91 98765 43210', tp, ts),
        _infoRow(Icons.access_time, 'Hours', 'Mon–Sat, 9 AM – 8 PM', tp, ts),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Close', style: TextStyle(color: Color(0xFF1A73E8))))],
    ));
  }

  void _showTerms(BuildContext context, Color card, Color tp, Color ts) {
    showDialog(context: context, builder: (dctx) => AlertDialog(
      backgroundColor: card,
      title: Text('Terms & Conditions', style: TextStyle(color: tp, fontSize: 18, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Text(
          'By using SecureRide, you agree to share trips and location only with contacts you approve. '
              'You are responsible for the accuracy of trip details you create. SecureRide is a safety companion '
              'and does not replace emergency services — in a real emergency, always contact local authorities. '
              'We may update these terms; continued use means you accept the latest version.',
          style: TextStyle(color: ts, height: 1.6, fontSize: 13))),
      actions: [TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Close', style: TextStyle(color: Color(0xFF1A73E8))))],
    ));
  }

  void _showPrivacy(BuildContext context, Color card, Color tp, Color ts) {
    showDialog(context: context, builder: (dctx) => AlertDialog(
      backgroundColor: card,
      title: Text('Privacy Policy', style: TextStyle(color: tp, fontSize: 18, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Text(
          'SecureRide values your privacy. Your location is shared only with the trusted contacts you approve, '
              'and only while you choose to share it. We never sell your data. Trip history, contacts, and profile '
              'details are stored securely on your device. You can stop location sharing or remove contacts at any time.',
          style: TextStyle(color: ts, height: 1.6, fontSize: 13))),
      actions: [TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Close', style: TextStyle(color: Color(0xFF1A73E8))))],
    ));
  }
}