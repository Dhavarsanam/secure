import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/trip_model.dart';
import 'create_trip_screen.dart';
import 'join_trip_screen.dart';
import 'trip_detail_screen.dart';
import 'trip_history_screen.dart';
import '../../utils/app_icon_colors.dart';

class MyTripsScreen extends StatelessWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trips = context.watch<TripProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    final active = trips.activeTrips;
    final completed = trips.completedTrips;
    final cancelled = trips.myTrips.where((t) => t.status == TripStatus.cancelled).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A73E8),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: const Text('My Trips', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(icon: Icon(Icons.history_rounded, color: appIconColor(Icons.history_rounded)), tooltip: 'Trip History',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripHistoryScreen()))),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(text: 'Active (${active.length})'),
              Tab(text: 'Completed (${completed.length})'),
              Tab(text: 'Cancelled (${cancelled.length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF1A73E8),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('New Trip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTripScreen())),
        ),
        body: TabBarView(
          children: [
            _TripList(trips: active, emptyMsg: 'No active trips!\nCreate or join one.', emptyIcon: Icons.directions_car_outlined, card: card, tp: tp, ts: ts, isDark: isDark, uid: auth.currentUser?.uid ?? ''),
            _TripList(trips: completed, emptyMsg: 'No completed trips yet.', emptyIcon: Icons.check_circle_outline, card: card, tp: tp, ts: ts, isDark: isDark, uid: auth.currentUser?.uid ?? ''),
            _TripList(trips: cancelled, emptyMsg: 'No cancelled trips.', emptyIcon: Icons.cancel_outlined, card: card, tp: tp, ts: ts, isDark: isDark, uid: auth.currentUser?.uid ?? ''),
          ],
        ),
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  final List<TripModel> trips;
  final String emptyMsg, uid;
  final IconData emptyIcon;
  final Color card, tp, ts;
  final bool isDark;

  const _TripList({required this.trips, required this.emptyMsg, required this.emptyIcon,
    required this.card, required this.tp, required this.ts, required this.isDark, required this.uid});

  Color _statusColor(TripStatus s) {
    switch (s) {
      case TripStatus.active: return const Color(0xFF22C55E);
      case TripStatus.completed: return const Color(0xFF1A73E8);
      case TripStatus.cancelled: return const Color(0xFFEF4444);
    }
  }

  String _statusLabel(TripStatus s) {
    switch (s) {
      case TripStatus.active: return 'Active';
      case TripStatus.completed: return 'Completed';
      case TripStatus.cancelled: return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(emptyIcon, size: 64, color: appIconColor(emptyIcon)),
        const SizedBox(height: 14),
        Text(emptyMsg, style: TextStyle(color: ts, fontSize: 14), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinTripScreen())),
          icon: Icon(Icons.group_add_rounded, color: appIconColor(Icons.group_add_rounded)),
          label: const Text('Join a Trip'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        final color = _statusColor(trip.status);
        final isCreator = trip.creatorUid == uid;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                border: Border(left: BorderSide(color: color, width: 4)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 8)]),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  // Trip code
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text('# ${trip.tripCode}', style: const TextStyle(color: Color(0xFF1A73E8), fontSize: 11, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 6),
                  // Status badge
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(_statusLabel(trip.status), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
                  const Spacer(),
                  // Creator/Member badge
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: isCreator ? const Color(0xFF7C3AED).withValues(alpha: 0.1) : const Color(0xFF22C55E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(isCreator ? '👑 Creator' : '👤 Member',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                              color: isCreator ? const Color(0xFF7C3AED) : const Color(0xFF22C55E)))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF1A73E8), size: 13),
                  const SizedBox(width: 6),
                  Expanded(child: Text(trip.startLocationName, style: TextStyle(color: tp, fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 13),
                  const SizedBox(width: 6),
                  Expanded(child: Text(trip.destinationName, style: TextStyle(color: tp, fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  // Vehicle icon
                  Icon(_vehicleIcon(trip.vehicleType), size: 14, color: appIconColor(_vehicleIcon(trip.vehicleType))),
                  const SizedBox(width: 4),
                  Text(trip.vehicleType, style: TextStyle(fontSize: 11, color: ts)),
                  const SizedBox(width: 10),
                  Icon(Icons.people_outline_rounded, size: 13, color: appIconColor(Icons.people_outline_rounded)),
                  const SizedBox(width: 3),
                  Text('${trip.bookedSeats}/${trip.availableSeats} seats', style: TextStyle(fontSize: 11, color: ts)),
                  if (trip.distanceKm != null) ...[
                    const SizedBox(width: 10),
                    Icon(Icons.straighten_rounded, size: 12, color: appIconColor(Icons.straighten_rounded)),
                    const SizedBox(width: 3),
                    Text('${trip.distanceKm!.toStringAsFixed(1)} km', style: TextStyle(fontSize: 11, color: ts)),
                  ],
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: ts, size: 18),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }

  IconData _vehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bike': return Icons.two_wheeler_rounded;
      case 'auto': return Icons.electric_rickshaw_rounded;
      case 'van': return Icons.airport_shuttle_rounded;
      case 'bus': return Icons.directions_bus_rounded;
      default: return Icons.directions_car_rounded;
    }
  }
}
