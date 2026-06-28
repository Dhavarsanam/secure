import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/theme_provider.dart';
import '../trip/create_trip_screen.dart';
import '../trip/my_trips_screen.dart';
import '../trip/join_trip_screen.dart';
import '../map/map_screen.dart';
import '../map/weather_screen.dart';
import '../sos/sos_screen.dart';
import '../settings/settings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../trip/safety_score_screen.dart';
import '../trip/trip_detail_screen.dart';
import '../../utils/app_icon_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    _HomeTab(),
    MyTripsScreen(),
    MapScreen(),
    SosScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) context.read<TripProvider>().loadDummyTrips(auth.currentUser!.uid);
    });
  }

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
                fontSize: 11,
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
    final navBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: navBg,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))]),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Row(children: [
              _navItem(0, Icons.home_rounded, 'Home', const Color(0xFF1A73E8), isDark),
              _navItem(1, Icons.directions_car_rounded, 'My Trips', const Color(0xFF6366F1), isDark),
              _navItem(2, Icons.map_rounded, 'Map', const Color(0xFF16A34A), isDark),
              _navItem(3, Icons.sos_rounded, 'SOS', const Color(0xFFEF4444), isDark),
              _navItem(4, Icons.settings_rounded, 'Settings', const Color(0xFF64748B), isDark),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final trips = context.watch<TripProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final user = auth.currentUser;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Hello, ${user?.fullName.split(' ').first ?? 'User'}! 👋',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
          const Text('Safe & Private Rides', style: TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
        actions: [
          // Notification bell with red dot
          Stack(children: [
            IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            Positioned(top: 10, right: 10,
                child: Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle))),
          ]),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { if (user != null) trips.loadDummyTrips(user.uid); },
        color: const Color(0xFF1A73E8),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Quick Actions — Create Trip + Join Trip
            Row(children: [
              Expanded(child: _ActionBtn(icon: Icons.add_circle_rounded, label: 'Create Trip',
                  color: const Color(0xFF1A73E8),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTripScreen())))),
              const SizedBox(width: 12),
              Expanded(child: _ActionBtn(icon: Icons.group_add_rounded, label: 'Join Trip',
                  color: const Color(0xFF22C55E),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinTripScreen())))),
            ]),
            const SizedBox(height: 20),

            // Dashboard Stats (spec: Total Trips 5, Completed 4, Contacts 3)
            Text('Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _StatCard(icon: Icons.directions_car_rounded, label: 'Total Trips',
                  value: '${trips.myTrips.length}', color: const Color(0xFF1A73E8), card: card, tp: tp, ts: ts)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(icon: Icons.check_circle_rounded, label: 'Completed',
                  value: '${trips.completedTrips.length}', color: const Color(0xFF22C55E), card: card, tp: tp, ts: ts)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(icon: Icons.contacts_rounded, label: 'Contacts',
                  value: '${user?.approvedContacts.length ?? 0}', color: const Color(0xFF7C3AED), card: card, tp: tp, ts: ts)),
            ]),
            const SizedBox(height: 14),

            // Safety Score Card (spec: 83% with stars)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyScoreScreen())),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 8)]),
                child: Row(children: [
                  // Circular score indicator
                  Container(width: 54, height: 54,
                      decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4), width: 2)),
                      child: const Center(child: Text('83%',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Safety Score', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 14)),
                    Row(children: [
                      ...List.generate(4, (_) => const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14)),
                      const Icon(Icons.star_half_rounded, color: Color(0xFFF59E0B), size: 14),
                      const SizedBox(width: 4),
                      const Text('Very Good', style: TextStyle(fontSize: 11, color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
                    ]),
                    Text('Tap to see details', style: TextStyle(fontSize: 11, color: ts)),
                  ])),
                  const Icon(Icons.shield_rounded, color: Color(0xFF22C55E), size: 20),
                  Icon(Icons.chevron_right_rounded, color: ts),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // Weather Alert Banner
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252538) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4))),
                child: Row(children: [
                  const Text('🌦️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Weather Alert', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 13)),
                    Text('Light Rain expected · Madurai', style: TextStyle(fontSize: 11, color: ts)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: ts, size: 18),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Recent Trips
            Row(children: [
              Text('Recent Trips', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('${trips.activeTrips.length} active',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF1A73E8), fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 10),

            trips.myTrips.isEmpty
                ? _EmptyState(card: card, tp: tp, ts: ts)
                : Column(children: trips.myTrips.take(3).map((t) =>
                GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(trip: t))),
                    child: _TripRow(trip: t, card: card, tp: tp, ts: ts, isDark: isDark))).toList()),

            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}

// Quick Action Button
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))]),
      child: Column(children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    ),
  );
}

// Stat Card
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color, card, tp, ts;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color, required this.card, required this.tp, required this.ts});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tp)),
      Text(label, style: TextStyle(fontSize: 10, color: ts), textAlign: TextAlign.center),
    ]),
  );
}

// Trip Row
class _TripRow extends StatelessWidget {
  final dynamic trip;
  final Color card, tp, ts;
  final bool isDark;
  const _TripRow({required this.trip, required this.card, required this.tp, required this.ts, required this.isDark});

  Color get _statusColor {
    final s = trip.status.toString().split('.').last;
    if (s == 'active') return const Color(0xFF1A73E8);
    if (s == 'completed') return const Color(0xFF22C55E);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: _statusColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 6)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('${trip.tripCode}', style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(width: 8),
        // Route: Madurai → Chennai format
        Expanded(child: Text('${trip.startLocationName} → ${trip.destinationName}',
            style: TextStyle(color: tp, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(trip.status.toString().split('.').last.toUpperCase(),
                style: TextStyle(color: _statusColor, fontSize: 9, fontWeight: FontWeight.bold))),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Icon(Icons.calendar_today_outlined, size: 11, color: appIconColor(Icons.calendar_today_outlined)),
        const SizedBox(width: 3),
        Text('${trip.travelDate.day} ${_month(trip.travelDate.month)} ${trip.travelDate.year}',
            style: TextStyle(fontSize: 11, color: ts)),
        const SizedBox(width: 10),
        Icon(Icons.directions_car_outlined, size: 11, color: appIconColor(Icons.directions_car_outlined)),
        const SizedBox(width: 3),
        Text(trip.vehicleType, style: TextStyle(fontSize: 11, color: ts)),
        const Spacer(),
        Icon(Icons.chevron_right_rounded, color: ts, size: 16),
      ]),
    ]),
  );

  String _month(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];
}

// Empty State
class _EmptyState extends StatelessWidget {
  final Color card, tp, ts;
  const _EmptyState({required this.card, required this.tp, required this.ts});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 28),
    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [
      Icon(Icons.directions_car_outlined, size: 48, color: appIconColor(Icons.directions_car_outlined)),
      const SizedBox(height: 10),
      Text('No trips yet', style: TextStyle(color: tp, fontWeight: FontWeight.w600, fontSize: 14)),
      Text('Create or join a trip to get started!', style: TextStyle(color: ts, fontSize: 12)),
    ]),
  );
}