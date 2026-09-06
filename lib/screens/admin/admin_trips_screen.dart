import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/services/firestore_service.dart';
import '../../models/trip_model.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_icon_colors.dart';

// Fully dynamic — every trip comes live from Firestore's `trips`
// collection (see FirestoreService.allTripsStream). No hardcoded demo
// trips and no duplicates: each Firestore document ID is unique.
class AdminTripsScreen extends StatefulWidget {
  const AdminTripsScreen({super.key});
  @override
  State<AdminTripsScreen> createState() => _AdminTripsScreenState();
}

class _AdminTripsScreenState extends State<AdminTripsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestoreService = FirestoreService();
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _tabController = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabController.dispose(); _searchCtrl.dispose(); super.dispose(); }

  List<TripModel> _filtered(List<TripModel> trips, String status) => trips.where((t) {
    final q = _search.toLowerCase();
    final matchSearch = _search.isEmpty ||
        t.tripCode.toLowerCase().contains(q) ||
        t.startLocationName.toLowerCase().contains(q) ||
        t.destinationName.toLowerCase().contains(q) ||
        t.creatorName.toLowerCase().contains(q);
    final matchStatus = status == 'all' || t.status.name == status;
    return matchSearch && matchStatus;
  }).toList();

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _deleteTrip(TripModel trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete this trip?'),
        content: Text('Trip #${trip.tripCode} (${trip.startLocationName} → ${trip.destinationName}) will be permanently removed for every member.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _firestoreService.deleteTrip(trip.tripId);
    if (!mounted) return;
    _showSnack(ok ? 'Trip deleted' : 'Could not delete trip', ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444));
  }

  Color _statusColor(TripStatus s) {
    switch (s) {
      case TripStatus.active: return const Color(0xFF22C55E);
      case TripStatus.completed: return const Color(0xFF1A73E8);
      case TripStatus.cancelled: return const Color(0xFFEF4444);
    // ignore: unreachable_switch_default
      default: return const Color(0xFF6B7280);
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
      body: StreamBuilder<List<TripModel>>(
        stream: _firestoreService.allTripsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(children: [
              _appBar(0, 0, 0, isDark),
              Expanded(child: Center(child: Text('Failed to load trips', style: TextStyle(color: ts)))),
            ]);
          }
          if (!snapshot.hasData) {
            return Column(children: [
              _appBar(0, 0, 0, isDark),
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))),
            ]);
          }

          final trips = snapshot.data!;
          final activeCount = trips.where((t) => t.status == TripStatus.active).length;
          final completedCount = trips.where((t) => t.status == TripStatus.completed).length;

          return Column(children: [
            _appBar(trips.length, activeCount, completedCount, isDark),
            Container(color: card, padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search by code, location, creator...',
                    hintStyle: TextStyle(color: ts, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: appIconColor(Icons.search)),
                    suffixIcon: _search.isNotEmpty ? IconButton(icon: Icon(Icons.clear, color: appIconColor(Icons.clear)),
                        onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); }) : null,
                    filled: true, fillColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F7FA),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                )),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: ['all', 'active', 'completed'].map((status) {
                  final list = _filtered(trips, status);
                  if (list.isEmpty) {
                    return Center(child: Text('No trips found', style: TextStyle(color: ts, fontSize: 13)));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final trip = list[i];
                      final color = _statusColor(trip.status);
                      final km = trip.distanceKm;
                      return Container(
                        key: ValueKey(trip.tripId),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14),
                            border: Border(left: BorderSide(color: color, width: 4)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                                  child: Text('# ${trip.tripCode}', style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.bold))),
                              const SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                                  child: Text(trip.status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
                              const Spacer(),
                              Text(DateFormat('dd MMM yyyy').format(trip.travelDate), style: TextStyle(fontSize: 11, color: ts)),
                              IconButton(
                                onPressed: () => _deleteTrip(trip),
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.only(left: 8),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Icon(Icons.radio_button_checked, color: Color(0xFF1A73E8), size: 13),
                              const SizedBox(width: 6),
                              Expanded(child: Text(trip.startLocationName, style: TextStyle(color: tp, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                            ]),
                            const SizedBox(height: 3),
                            Row(children: [
                              const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 13),
                              const SizedBox(width: 6),
                              Expanded(child: Text(trip.destinationName, style: TextStyle(color: tp, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              Icon(Icons.person_outline, size: 12, color: appIconColor(Icons.person_outline)),
                              const SizedBox(width: 3),
                              Expanded(child: Text(trip.creatorName, style: TextStyle(fontSize: 11, color: ts), overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 12),
                              Icon(Icons.directions_car_outlined, size: 12, color: appIconColor(Icons.directions_car_outlined)),
                              const SizedBox(width: 3),
                              Text(trip.vehicleType, style: TextStyle(fontSize: 11, color: ts)),
                              const SizedBox(width: 12),
                              Icon(Icons.people_outline, size: 12, color: appIconColor(Icons.people_outline)),
                              const SizedBox(width: 3),
                              Text('${trip.bookedSeats}/${trip.availableSeats}', style: TextStyle(fontSize: 11, color: ts)),
                              const Spacer(),
                              Text(km != null ? '${km.toStringAsFixed(1)} km' : '— km', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                            ]),
                          ]),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _appBar(int all, int active, int completed, bool isDark) => AppBar(
    backgroundColor: const Color(0xFF7C3AED),
    foregroundColor: Colors.white,
    automaticallyImplyLeading: false,
    title: const Text('Trip Management', style: TextStyle(fontWeight: FontWeight.bold)),
    bottom: TabBar(
      controller: _tabController,
      indicatorColor: Colors.white,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      tabs: [
        Tab(text: 'All ($all)'),
        Tab(text: 'Active ($active)'),
        Tab(text: 'Completed ($completed)'),
      ],
    ),
  );
}