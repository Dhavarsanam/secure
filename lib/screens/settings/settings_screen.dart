import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../auth/login_screen.dart';
import '../contacts/approved_contacts_screen.dart';
import '../map/live_location_screen.dart';
import '../trip/verified_badge_screen.dart';
import '../map/weather_screen.dart';
import '../notifications/notifications_screen.dart';
import '../trip/safety_score_screen.dart';
import '../trip/achievement_badges_screen.dart';
import '../admin/admin_login_screen.dart';
import '../../utils/app_icon_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final user = auth.currentUser;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Profile section (spec: Profile with name, number)
          Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 8)]),
              child: Row(children: [
                CircleAvatar(radius: 30, backgroundColor: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                    child: Text((user?.fullName.isNotEmpty == true) ? user!.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?.fullName ?? 'User', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: tp)),
                  Text(user?.email ?? '', style: TextStyle(fontSize: 12, color: ts)),
                  if ((user?.phoneNumber ?? '').isNotEmpty)
                    Text(user!.phoneNumber, style: TextStyle(fontSize: 12, color: ts)),
                ])),
                Icon(Icons.chevron_right_rounded, color: ts),
              ])),

          const SizedBox(height: 20),

          // Emergency Contacts (spec requirement)
          _sectionTitle('Emergency Contacts', ts),
          _tile(context, icon: Icons.contacts_rounded, title: 'Emergency Contacts',
              subtitle: '${user?.approvedContacts.length ?? 0} contacts added',
              color: const Color(0xFF1A73E8), card: card, tp: tp, ts: ts,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApprovedContactsScreen()))),

          const SizedBox(height: 16),

          // Location Sharing (spec)
          _sectionTitle('Location Sharing', ts),
          _tile(context, icon: Icons.location_on_rounded, title: 'Live Location',
              subtitle: 'Share your location with contacts',
              color: const Color(0xFF22C55E), card: card, tp: tp, ts: ts,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveLocationScreen()))),

          const SizedBox(height: 16),

          // Notifications (spec: different icons)
          _sectionTitle('Notifications', ts),
          _tile(context, icon: Icons.notifications_rounded, title: 'Notifications',
              subtitle: 'Trip alerts, SOS, weather updates',
              color: const Color(0xFFF59E0B), card: card, tp: tp, ts: ts,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),

          const SizedBox(height: 16),

          // Theme (spec: Theme Blue option)
          _sectionTitle('Theme', ts),
          Container(margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04), blurRadius: 6)]),
              child: ListTile(
                  leading: Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF6B7280).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: appIconColor(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded), size: 20)),
                  title: Text('Dark Mode', style: TextStyle(color: tp, fontWeight: FontWeight.w500)),
                  subtitle: Text(isDark ? 'Currently Dark' : 'Currently Light', style: TextStyle(color: ts, fontSize: 12)),
                  trailing: Switch(value: isDark, onChanged: (_) => context.read<ThemeProvider>().toggleTheme(),
                      activeColor: const Color(0xFF1A73E8)))),

          const SizedBox(height: 16),

          // Privacy & Security (spec)
          _sectionTitle('Privacy & Security', ts),
          _tile(context, icon: Icons.verified_rounded, title: 'Get Verified',
              subtitle: 'Earn your blue verified badge',
              color: const Color(0xFF1A73E8), card: card, tp: tp, ts: ts,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifiedBadgeScreen()))),
          _tile(context, icon: Icons.shield_rounded, title: 'Safety Score',
              subtitle: 'View your safety rating & tips',
              color: const Color(0xFF22C55E), card: card, tp: tp, ts: ts,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyScoreScreen()))),
          _tile(context, icon: Icons.emoji_events_rounded, title: 'Achievement Badges',
              subtitle: 'View your earned badges 🏆',
              color: const Color(0xFFF59E0B), card: card, tp: tp, ts: ts,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementBadgesScreen()))),
          _tile(context, icon: Icons.wb_sunny_outlined, title: 'Weather & Traffic',
              subtitle: 'Check weather before your trip',
              color: const Color(0xFF3B82F6), card: card, tp: tp, ts: ts,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()))),

          const SizedBox(height: 16),

          // Admin (hidden via swipe on login, but kept for easy access)
          _sectionTitle('Administration', ts),
          Container(margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                  leading: Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20)),
                  title: const Text('Admin Panel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Manage users & trips', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen())))),

          const SizedBox(height: 16),

          // App info
          _sectionTitle('About', ts),
          _tile(context, icon: Icons.info_outline_rounded, title: 'App Version', subtitle: '1.0.0',
              color: const Color(0xFF6B7280), card: card, tp: tp, ts: ts,
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'SecureRide',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2025 SecureRide • Safe. Private. Connected.',
              )),
          _tile(context, icon: Icons.security_rounded, title: 'Privacy Policy', subtitle: 'Your data is safe with us',
              color: const Color(0xFF1A73E8), card: card, tp: tp, ts: ts,
              onTap: () => showDialog(
                context: context,
                builder: (dctx) => AlertDialog(
                  backgroundColor: card,
                  title: Text('Privacy Policy', style: TextStyle(color: tp, fontSize: 18, fontWeight: FontWeight.bold)),
                  content: SingleChildScrollView(
                    child: Text(
                      'SecureRide values your privacy. Your location is shared only with the trusted contacts you approve, and only while you choose to share it. We never sell your data. Trip history, contacts, and profile details are stored securely on your device. You can stop location sharing or remove contacts at any time.',
                      style: TextStyle(color: ts, height: 1.6, fontSize: 13),
                    ),
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Close', style: TextStyle(color: Color(0xFF1A73E8))))],
                ),
              )),

          const SizedBox(height: 24),

          // Logout (spec)
          SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                    }
                  },
                  icon: Icon(Icons.logout_rounded, color: appIconColor(Icons.logout_rounded)),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String title, Color ts) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ts, letterSpacing: 0.5)));

  Widget _tile(BuildContext context, {required IconData icon, required String title, required String subtitle,
    required Color color, required Color card, required Color tp, required Color ts, required VoidCallback? onTap}) =>
      Container(margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
          child: ListTile(
              leading: Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 20)),
              title: Text(title, style: TextStyle(color: tp, fontWeight: FontWeight.w500)),
              subtitle: Text(subtitle, style: TextStyle(color: ts, fontSize: 12)),
              trailing: onTap != null ? Icon(Icons.chevron_right_rounded, color: ts) : null,
              onTap: onTap));
}