import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/notification_settings_provider.dart';
import '../../providers/notifications_provider.dart';
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
import '../../core/services/weather_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/geocoding_service.dart';
// SafetyScore.calculate() is shared with SafetyScoreScreen so the number
// on this dashboard card and the detail screen always match.
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
      if (auth.currentUser != null) {
        context.read<TripProvider>().loadDummyTrips(auth.currentUser!.uid);
        context.read<NotificationsProvider>().listenFor(auth.currentUser!.uid);
      }
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

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final WeatherService _weatherService = WeatherService();
  final LocationService _locationService = LocationService();
  final GeocodingService _geocodingService = GeocodingService();
  WeatherData? _weather;
  bool _weatherLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  // Gets the device's real current location, then fetches live weather
  // (Open-Meteo — free, no API key) for that exact spot. No dummy
  // fallback: if location or the API isn't available, the banner shows
  // a friendly "unavailable" message instead of fake data.
  Future<void> _loadWeather() async {
    if (mounted) setState(() => _weatherLoading = true);
    final position = await _locationService.getCurrentPosition();
    WeatherData? weather;
    if (position != null) {
      final cityName = await _geocodingService.reverseGeocode(position.latitude, position.longitude);
      weather = await _weatherService.getWeather(lat: position.latitude, lng: position.longitude, cityName: cityName);
    }
    if (mounted) setState(() { _weather = weather; _weatherLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final trips = context.watch<TripProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final user = auth.currentUser;
    final safetyScoreData = SafetyScore.calculate(trips, auth);
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final notificationsEnabled = context.watch<NotificationSettingsProvider>().notificationsEnabled;
    final unreadNotifs = context.watch<NotificationsProvider>().unreadCount;

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
          const Text('Ready to share your ride?', style: TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
        actions: [
          // Notification bell with red dot — dot only shows when
          // notifications are ON in Settings AND there's a real unread one.
          Stack(children: [
            IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            if (notificationsEnabled && unreadNotifs > 0)
              Positioned(top: 10, right: 10,
                  child: Container(width: 8, height: 8,
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle))),
          ]),
          // Profile icon — shows the logged-in user's details
          IconButton(
              icon: CircleAvatar(
                radius: 15,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: (user?.profileImageUrl?.isNotEmpty == true)
                    ? MemoryImage(base64Decode(user!.profileImageUrl!))
                    : null,
                child: (user?.profileImageUrl?.isNotEmpty == true)
                    ? null
                    : Text((user?.fullName.isNotEmpty == true) ? user!.fullName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              tooltip: 'Profile',
              onPressed: () => _showUserDetails(context, user, card, tp, ts)),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (user != null) trips.loadDummyTrips(user.uid);
          await _loadWeather();
        },
        color: const Color(0xFF1A73E8),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Overview Stats (spec: Total Trips 5, Completed 4, Contacts 3)
            Text('Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
            const SizedBox(height: 10),
            // 4 stat cards in one row: Total Trips, Completed, Contacts, Safety Score
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _StatCard(icon: Icons.directions_car_rounded, label: 'Total Trips',
                    value: '${trips.myTrips.length}', color: const Color(0xFF1A73E8), card: card, tp: tp, ts: ts)),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(icon: Icons.check_circle_rounded, label: 'Completed',
                    value: '${trips.completedTrips.length}', color: const Color(0xFF22C55E), card: card, tp: tp, ts: ts)),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(icon: Icons.contacts_rounded, label: 'Contacts',
                    value: '${user?.emergencyContacts.length ?? 0}', color: const Color(0xFF7C3AED), card: card, tp: tp, ts: ts)),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(icon: Icons.shield_rounded, label: 'Safety Score',
                    value: safetyScoreData.hasNoActivity ? 'New' : '${safetyScoreData.overall.round()}%', color: const Color(0xFFF59E0B), card: card, tp: tp, ts: ts,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyScoreScreen())))),
              ]),
            ),
            const SizedBox(height: 14),

            // Weather Alert Banner — live data for the user's current location
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252538) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4))),
                child: Row(children: [
                  Text(_weather?.isStormy == true ? '⛈️' : _weather?.isRaining == true ? '🌧️' : _weather?.isFoggy == true ? '🌫️' : '🌤️',
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Weather Alert', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 13)),
                    Text(
                        _weatherLoading
                            ? 'Fetching weather for your location…'
                            : _weather == null
                            ? 'Weather data currently unavailable'
                            : '${_weather!.description[0].toUpperCase()}${_weather!.description.substring(1)}, ${_weather!.temperature.round()}°C · ${_weather!.city}',
                        style: TextStyle(fontSize: 11, color: ts)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: ts, size: 18),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Quick Actions — Create Trip, Join Trip
            Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
            const SizedBox(height: 12),
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

            // Upcoming Trip — single highlighted card for the next active trip
            Row(children: [
              Text('Upcoming Trip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
              const Spacer(),
              if (trips.activeTrips.isNotEmpty)
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTripsScreen())),
                  child: const Text('View All', style: TextStyle(fontSize: 12, color: Color(0xFF1A73E8), fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 10),

            trips.activeTrips.isEmpty
                ? _EmptyState(card: card, tp: tp, ts: ts)
                : GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trips.activeTrips.first))),
                child: _UpcomingTripCard(trip: trips.activeTrips.first, card: card, tp: tp, ts: ts, isDark: isDark)),

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

  void _showUserDetails(BuildContext context, dynamic user, Color card, Color tp, Color ts) {
    showDialog(
      context: context,
      builder: (dctx) => Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          final u = auth.currentUser;
          final hasPhoto = (u?.profileImageUrl?.isNotEmpty == true);
          return AlertDialog(
            backgroundColor: card,
            title: Text('My Profile', style: TextStyle(color: tp, fontSize: 18, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Center(
                  child: GestureDetector(
                    onTap: () => _pickProfileImage(ctx, card, tp, ts),
                    child: Stack(children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                        backgroundImage: hasPhoto ? MemoryImage(base64Decode(u!.profileImageUrl!)) : null,
                        child: hasPhoto
                            ? null
                            : Text((u?.fullName.isNotEmpty == true) ? u!.fullName[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8))),
                      ),
                      Positioned(bottom: 0, right: 0,
                          child: Container(padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: const Color(0xFF1A73E8), shape: BoxShape.circle,
                                  border: Border.all(color: card, width: 2)),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15))),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton(
                    onPressed: () => _pickProfileImage(ctx, card, tp, ts),
                    child: Text(hasPhoto ? 'Change Photo' : 'Add Photo',
                        style: const TextStyle(color: Color(0xFF1A73E8), fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  if (hasPhoto)
                    TextButton(
                      onPressed: () => ctx.read<AuthProvider>().removeProfileImage(),
                      child: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ]),
                const Divider(height: 22),
                _userInfoRow(Icons.person_outline, 'Name', u?.fullName ?? '—', tp, ts),
                _userInfoRow(Icons.email_outlined, 'Email', u?.email ?? '—', tp, ts),
                _userInfoRow(Icons.phone_outlined, 'Phone', (u?.phoneNumber ?? '').isNotEmpty ? u!.phoneNumber : '—', tp, ts),
                _userInfoRow(Icons.calendar_today_outlined, 'Member Since', u != null ? _formatJoinDate(u.createdAt) : '—', tp, ts),
                _userInfoRow(Icons.contacts_outlined, 'Approved Contacts', '${u?.emergencyContacts.length ?? 0}', tp, ts),
                _userInfoRow(Icons.location_on_outlined, 'Location Sharing', (u?.isLocationSharing == true) ? 'On' : 'Off', tp, ts),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Close', style: TextStyle(color: Color(0xFF1A73E8))))],
          );
        },
      ),
    );
  }

  Future<void> _pickProfileImage(BuildContext context, Color card, Color tp, Color ts) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: Color(0xFF1A73E8)),
              title: Text('Take Photo', style: TextStyle(color: tp, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(bctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF22C55E)),
              title: Text('Choose from Gallery', style: TextStyle(color: tp, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(bctx, ImageSource.gallery),
            ),
            const SizedBox(height: 4),
            TextButton(onPressed: () => Navigator.pop(bctx), child: Text('Cancel', style: TextStyle(color: ts))),
          ]),
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 80);
      if (picked == null || !context.mounted) return;
      final bytes = await picked.readAsBytes();
      final base64Str = base64Encode(bytes);
      await context.read<AuthProvider>().updateProfileImage(base64Str);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not access camera/gallery. Please check permissions.')));
      }
    }
  }

  String _formatJoinDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }

  Widget _userInfoRow(IconData icon, String label, String value, Color tp, Color ts) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 18, color: const Color(0xFF1A73E8)),
      const SizedBox(width: 10),
      Text('$label: ', style: TextStyle(color: ts, fontSize: 13)),
      Expanded(child: Text(value, style: TextStyle(color: tp, fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );
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

// Upcoming Trip — single highlighted card (date box + route + status)
class _UpcomingTripCard extends StatelessWidget {
  final dynamic trip;
  final Color card, tp, ts;
  final bool isDark;
  const _UpcomingTripCard({required this.trip, required this.card, required this.tp, required this.ts, required this.isDark});

  String _month(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];

  @override
  Widget build(BuildContext context) {
    final date = trip.travelDate;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 8)]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Date box
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text('${date.day}', style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold, fontSize: 18)),
            Text(_month(date.month), style: const TextStyle(color: Color(0xFF1A73E8), fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${trip.startLocationName}  →  ${trip.destinationName}',
                style: TextStyle(color: tp, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: const Text('Active', style: TextStyle(color: Color(0xFF1A73E8), fontSize: 10, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.access_time_rounded, size: 13, color: ts),
            const SizedBox(width: 3),
            Text(TimeOfDay.fromDateTime(date).format(context), style: TextStyle(fontSize: 12, color: ts)),
            const SizedBox(width: 12),
            Icon(Icons.event_seat_rounded, size: 13, color: ts),
            const SizedBox(width: 3),
            Text('${trip.availableSeats - trip.bookedSeats} Seats', style: TextStyle(fontSize: 12, color: ts)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.directions_car_outlined, size: 13, color: ts),
            const SizedBox(width: 3),
            Text(trip.vehicleType, style: TextStyle(fontSize: 12, color: ts)),
          ]),
        ])),
      ]),
    );
  }
}

// Stat Card
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color, card, tp, ts;
  final VoidCallback? onTap;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color, required this.card, required this.tp, required this.ts, this.onTap});
  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(height: 6),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: tp))),
        const SizedBox(height: 2),
        FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(fontSize: 10, color: ts), textAlign: TextAlign.center)),
      ]),
    );
    return onTap == null
        ? content
        : GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: content);
  }
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 6)]),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Route dots — green (start) to red (destination)
      Column(children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
        Container(width: 1.5, height: 22, color: ts.withValues(alpha: 0.3)),
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
      ]),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${trip.startLocationName}  →  ${trip.destinationName}',
              style: TextStyle(color: tp, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(trip.status.toString().split('.').last[0].toUpperCase() + trip.status.toString().split('.').last.substring(1),
                  style: TextStyle(color: _statusColor, fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('${trip.travelDate.day} ${_month(trip.travelDate.month)} ${trip.travelDate.year}',
              style: TextStyle(fontSize: 11, color: ts)),
          const Text(' • ', style: TextStyle(fontSize: 11)),
          Text(trip.vehicleType, style: TextStyle(fontSize: 11, color: ts)),
        ]),
      ])),
      Icon(Icons.chevron_right_rounded, color: ts, size: 18),
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