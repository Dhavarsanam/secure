import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../auth/login_screen.dart';
import 'admin_users_screen.dart';
import 'admin_trips_screen.dart';
import 'admin_sos_screen.dart';
import 'admin_reports_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const _DashboardTab(),
    const AdminUsersScreen(),
    const AdminTripsScreen(),
    const AdminSosScreen(),
    const AdminReportsScreen(),
  ];

  Widget _navItem(int index, IconData icon, String label, Color color, bool isDark) {
    final selected = _currentIndex == index;
    final inactive = isDark ? const Color(0xFF94A3B8) : const Color(0xFF9CA3AF);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 48,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
                boxShadow: selected
                    ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                    : null,
              ),
              child: Icon(icon, size: 22, color: selected ? Colors.white : inactive),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : inactive,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Row(children: [
              _navItem(0, Icons.dashboard_rounded, 'Dashboard', const Color(0xFF7C3AED), isDark),
              _navItem(1, Icons.people_rounded, 'Users', const Color(0xFF1A73E8), isDark),
              _navItem(2, Icons.directions_car_rounded, 'Trips', const Color(0xFF6366F1), isDark),
              _navItem(3, Icons.sos_rounded, 'SOS', const Color(0xFFEF4444), isDark),
              _navItem(4, Icons.bar_chart_rounded, 'Reports', const Color(0xFFF59E0B), isDark),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── DASHBOARD TAB ─────────────────────────────────────────
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  void _showSnack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showBroadcastDialog(BuildContext context) {
    final ctrl = TextEditingController();
    final isDark = context.read<ThemeProvider>().isDarkMode;
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        title: Text('Broadcast Message', style: TextStyle(color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E), fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: TextStyle(color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E)),
          decoration: InputDecoration(
            hintText: 'Type a message to send to all users...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: isDark ? const Color(0xFF252538) : const Color(0xFFF5F7FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              Navigator.pop(dctx);
              _showSnack(context, text.isEmpty ? 'Message cannot be empty' : 'Broadcast sent to all users', text.isEmpty ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  static const _stats = {
    'totalUsers': 248,
    'activeUsers': 183,
    'totalTrips': 1024,
    'activeTrips': 12,
    'completedTrips': 982,
    'sosAlerts': 3,
    'verifiedUsers': 156,
    'totalKm': 8742,
  };

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Logout Admin?'),
          content: const Text('Are you sure you want to logout from the admin panel?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Logout')),
          ],
        ));

    if (ok == true && context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF0F4FF);
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF7C3AED),
            automaticallyImplyLeading: false,
            actions: [
              // Logout button
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Logout',
                onPressed: () => _logout(context),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Admin Panel', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('SecureRide Dashboard', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4))),
                      child: const Row(children: [
                        Icon(Icons.circle, color: Color(0xFF22C55E), size: 8),
                        SizedBox(width: 4),
                        Text('Live', style: TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ]),
                ]),
              ),
              title: null,
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // SOS Alert Banner
                if (_stats['sosAlerts']! > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${_stats['sosAlerts']} Active SOS Alerts!',
                            style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 14)),
                        const Text('Immediate attention required', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                      ])),
                      ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSosScreen())),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('View'),
                      ),
                    ]),
                  ),

                // Stats Grid
                Text('Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12, crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _StatCard(icon: Icons.people_rounded, label: 'Total Users', value: '${_stats['totalUsers']}',
                        sub: '${_stats['activeUsers']} active', color: const Color(0xFF1A73E8), card: card, tp: tp, ts: ts),
                    _StatCard(icon: Icons.directions_car_rounded, label: 'Total Trips', value: '${_stats['totalTrips']}',
                        sub: '${_stats['activeTrips']} active', color: const Color(0xFF22C55E), card: card, tp: tp, ts: ts),
                    _StatCard(icon: Icons.verified_rounded, label: 'Verified Users', value: '${_stats['verifiedUsers']}',
                        sub: '${((_stats['verifiedUsers']! / _stats['totalUsers']!) * 100).round()}% verified',
                        color: const Color(0xFF7C3AED), card: card, tp: tp, ts: ts),
                    _StatCard(icon: Icons.straighten_rounded, label: 'Total KM', value: '${_stats['totalKm']}',
                        sub: 'distance covered', color: const Color(0xFFF59E0B), card: card, tp: tp, ts: ts),
                  ],
                ),

                const SizedBox(height: 24),

                // Trip Status
                Text('Trip Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                  child: Column(children: [
                    _StatusBar(label: 'Completed', value: _stats['completedTrips']!, total: _stats['totalTrips']!, color: const Color(0xFF22C55E), tp: tp, ts: ts),
                    const SizedBox(height: 12),
                    _StatusBar(label: 'Active', value: _stats['activeTrips']!, total: _stats['totalTrips']!, color: const Color(0xFF1A73E8), tp: tp, ts: ts),
                    const SizedBox(height: 12),
                    _StatusBar(label: 'Cancelled',
                        value: _stats['totalTrips']! - _stats['completedTrips']! - _stats['activeTrips']!,
                        total: _stats['totalTrips']!, color: const Color(0xFFEF4444), tp: tp, ts: ts),
                  ]),
                ),

                const SizedBox(height: 24),

                // Recent Activity
                Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
                const SizedBox(height: 12),
                ..._recentActivities.map((a) => _ActivityTile(activity: a, card: card, tp: tp, ts: ts)),

                const SizedBox(height: 24),

                // Quick Actions
                Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _QuickAction(icon: Icons.person_add_rounded, label: 'Add User', color: const Color(0xFF1A73E8), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen())))),
                  const SizedBox(width: 10),
                  Expanded(child: _QuickAction(icon: Icons.block_rounded, label: 'Block User', color: const Color(0xFFEF4444), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen())))),
                  const SizedBox(width: 10),
                  Expanded(child: _QuickAction(icon: Icons.download_rounded, label: 'Export CSV', color: const Color(0xFF22C55E), onTap: () => _showSnack(context, 'User data exported to CSV', const Color(0xFF22C55E)))),
                  const SizedBox(width: 10),
                  Expanded(child: _QuickAction(icon: Icons.notifications_rounded, label: 'Broadcast', color: const Color(0xFFF59E0B), onTap: () => _showBroadcastDialog(context))),
                ]),

                const SizedBox(height: 24),

                // Logout button at bottom
                SizedBox(
                  width: double.infinity, height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                    label: const Text('Logout Admin Panel', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600, fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static final _recentActivities = [
    {'icon': Icons.person_add_rounded, 'color': 0xFF1A73E8, 'title': 'New user registered', 'sub': 'Ayesha K — 2 min ago'},
    {'icon': Icons.directions_car_rounded, 'color': 0xFF22C55E, 'title': 'Trip completed', 'sub': 'FCW001: College → Junction — 5 min ago'},
    {'icon': Icons.sos_rounded, 'color': 0xFFDC2626, 'title': 'SOS Alert triggered', 'sub': 'Nisha F — 12 min ago'},
    {'icon': Icons.verified_rounded, 'color': 0xFF7C3AED, 'title': 'User verified', 'sub': 'Priya S — 30 min ago'},
    {'icon': Icons.star_rounded, 'color': 0xFFF59E0B, 'title': 'New review submitted', 'sub': 'Ravi K rated 5 stars — 1 hr ago'},
  ];
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final Color color, card, tp, ts;
  const _StatCard({required this.icon, required this.label, required this.value, required this.sub, required this.color, required this.card, required this.tp, required this.ts});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18)),
        const Spacer(),
        const Icon(Icons.trending_up_rounded, color: Color(0xFF22C55E), size: 14),
      ]),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: tp)),
      Text(label, style: TextStyle(fontSize: 11, color: ts, fontWeight: FontWeight.w500)),
      Text(sub, style: TextStyle(fontSize: 10, color: color)),
    ]),
  );
}

class _StatusBar extends StatelessWidget {
  final String label;
  final int value, total;
  final Color color, tp, ts;
  const _StatusBar({required this.label, required this.value, required this.total, required this.color, required this.tp, required this.ts});
  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : value / total;
    return Row(children: [
      SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 12, color: tp, fontWeight: FontWeight.w500))),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color), minHeight: 8))),
      const SizedBox(width: 8),
      Text('$value', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  final Color card, tp, ts;
  const _ActivityTile({required this.activity, required this.card, required this.tp, required this.ts});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Color(activity['color'] as int).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(activity['icon'] as IconData, color: Color(activity['color'] as int), size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(activity['title'] as String, style: TextStyle(fontWeight: FontWeight.w600, color: tp, fontSize: 13)),
        Text(activity['sub'] as String, style: TextStyle(fontSize: 11, color: ts)),
      ])),
    ]),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ]),
    ),
  );
}