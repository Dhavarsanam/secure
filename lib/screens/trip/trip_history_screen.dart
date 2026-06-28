import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/trip_model.dart';
import 'trip_detail_screen.dart';
import '../../utils/app_icon_colors.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});
  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filterStatus = 'All';
  String _searchQuery = '';
  bool _isTableView = false;
  final _searchController = TextEditingController();
  final List<String> _statusFilters = ['All', 'Active', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<TripModel> _filtered(List<TripModel> trips) {
    return trips.where((t) {
      final matchStatus = _filterStatus == 'All' ||
          t.status.name.toLowerCase() == _filterStatus.toLowerCase();
      final matchSearch = _searchQuery.isEmpty ||
          t.startLocationName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.destinationName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.tripCode.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchStatus && matchSearch;
    }).toList();
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final trips = context.watch<TripProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final filtered = _filtered(trips.myTrips);

    // Stats
    final total = trips.myTrips.length;
    final completed = trips.completedTrips.length;
    final totalKm = trips.myTrips.fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));
    final asCreator = trips.myTrips.where((t) => t.creatorUid == auth.currentUser?.uid).length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        title: const Text('Trip History', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isTableView ? Icons.view_list_rounded : Icons.table_chart_rounded, color: appIconColor(_isTableView ? Icons.view_list_rounded : Icons.table_chart_rounded)),
            tooltip: _isTableView ? 'Card View' : 'Table View',
            onPressed: () => setState(() => _isTableView = !_isTableView),
          ),
        ],
      ),
      body: Column(children: [

        // Stats header
        Container(
          color: const Color(0xFF1A73E8),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            _StatBadge(label: 'Total', value: '$total', icon: Icons.directions_car),
            _StatBadge(label: 'Done', value: '$completed', icon: Icons.check_circle_outline),
            _StatBadge(label: 'KM', value: totalKm.toStringAsFixed(0), icon: Icons.straighten),
            _StatBadge(label: 'Created', value: '$asCreator', icon: Icons.add_circle_outline),
          ]),
        ),

        // Search + Filters
        Container(
          color: card,
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by location or code...',
                hintStyle: TextStyle(color: ts, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: appIconColor(Icons.search), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: Icon(Icons.clear, color: appIconColor(Icons.clear), size: 18),
                    onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F7FA),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _statusFilters.map((f) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f, style: TextStyle(fontSize: 12,
                        color: _filterStatus == f ? Colors.white : tp,
                        fontWeight: _filterStatus == f ? FontWeight.w600 : FontWeight.normal)),
                    selected: _filterStatus == f,
                    onSelected: (_) => setState(() => _filterStatus = f),
                    backgroundColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F7FA),
                    selectedColor: const Color(0xFF1A73E8),
                    checkmarkColor: Colors.white,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                )).toList(),
              ),
            ),
          ]),
        ),

        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            Text('${filtered.length} trips found', style: TextStyle(fontSize: 12, color: ts)),
            const Spacer(),
            Icon(_isTableView ? Icons.table_chart_rounded : Icons.view_list_rounded,
                size: 14, color: appIconColor(_isTableView ? Icons.table_chart_rounded : Icons.view_list_rounded)),
            const SizedBox(width: 4),
            Text(_isTableView ? 'Table View' : 'Card View', style: TextStyle(fontSize: 11, color: ts)),
          ]),
        ),

        // Content
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.history, size: 64, color: appIconColor(Icons.history)),
            const SizedBox(height: 16),
            Text('No trips found', style: TextStyle(color: ts, fontSize: 16)),
          ]))
              : _isTableView
              ? _TableView(trips: filtered, card: card, tp: tp, ts: ts, formatDate: _formatDate,
              onTap: (trip) => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip))))
              : _CardView(trips: filtered, card: card, tp: tp, ts: ts,
              isCreatorUid: auth.currentUser?.uid ?? '',
              onTap: (trip) => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)))),
        ),
      ]),
    );
  }
}

// ── TABLE VIEW ──────────────────────────────────────────
class _TableView extends StatelessWidget {
  final List<TripModel> trips;
  final Color card, tp, ts;
  final String Function(DateTime) formatDate;
  final void Function(TripModel) onTap;

  const _TableView({required this.trips, required this.card, required this.tp, required this.ts, required this.formatDate, required this.onTap});

  Color _statusColor(TripStatus s) {
    switch (s) {
      case TripStatus.active: return const Color(0xFF22C55E);
      case TripStatus.completed: return const Color(0xFF1A73E8);
      case TripStatus.cancelled: return const Color(0xFFEF4444);
    }
  }

  String _statusEmoji(TripStatus s) {
    switch (s) {
      case TripStatus.active: return '🟢';
      case TripStatus.completed: return '✅';
      case TripStatus.cancelled: return '❌';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 12))),
              Expanded(flex: 3, child: Text('From', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 12))),
              Expanded(flex: 3, child: Text('To', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 12))),
              Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 12))),
            ]),
          ),
          const Divider(height: 1),

          // Rows
          ...trips.asMap().entries.map((entry) {
            final i = entry.key;
            final trip = entry.value;
            return Column(children: [
              GestureDetector(
                onTap: () => onTap(trip),
                child: Container(
                  color: i.isEven ? Colors.transparent : const Color(0xFF1A73E8).withValues(alpha: 0.03),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Expanded(flex: 2, child: Text(formatDate(trip.travelDate),
                        style: TextStyle(fontSize: 11, color: ts))),
                    Expanded(flex: 3, child: Text(trip.startLocationName,
                        style: TextStyle(fontSize: 11, color: tp, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 3, child: Text(trip.destinationName,
                        style: TextStyle(fontSize: 11, color: tp, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 2, child: Row(children: [
                      Text(_statusEmoji(trip.status), style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 3),
                      Expanded(child: Text(trip.status.name,
                          style: TextStyle(fontSize: 10, color: _statusColor(trip.status), fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis)),
                    ])),
                  ]),
                ),
              ),
              if (i < trips.length - 1) const Divider(height: 1, indent: 12, endIndent: 12),
            ]);
          }),
        ]),
      ),
    );
  }
}

// ── CARD VIEW ───────────────────────────────────────────
class _CardView extends StatelessWidget {
  final List<TripModel> trips;
  final Color card, tp, ts;
  final String isCreatorUid;
  final void Function(TripModel) onTap;

  const _CardView({required this.trips, required this.card, required this.tp, required this.ts, required this.isCreatorUid, required this.onTap});

  Color _statusColor(TripStatus s) {
    switch (s) {
      case TripStatus.active: return const Color(0xFF22C55E);
      case TripStatus.completed: return const Color(0xFF1A73E8);
      case TripStatus.cancelled: return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        final isCreator = trip.creatorUid == isCreatorUid;
        final color = _statusColor(trip.status);
        return GestureDetector(
          onTap: () => onTap(trip),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14),
                border: Border(left: BorderSide(color: color, width: 4)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text('# ${trip.tripCode}', style: const TextStyle(color: Color(0xFF1A73E8), fontSize: 11, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(trip.status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
                  const Spacer(),
                  Text('${trip.travelDate.day}/${trip.travelDate.month}/${trip.travelDate.year}',
                      style: TextStyle(fontSize: 11, color: ts)),
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
                  Text(trip.vehicleType, style: TextStyle(fontSize: 11, color: ts)),
                  const SizedBox(width: 10),
                  Text(trip.passengerType, style: TextStyle(fontSize: 11, color: ts)),
                  if (trip.distanceKm != null) ...[
                    const SizedBox(width: 10),
                    Text('${trip.distanceKm!.toStringAsFixed(1)} km', style: TextStyle(fontSize: 11, color: ts)),
                  ],
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: isCreator ? const Color(0xFF1A73E8).withValues(alpha: 0.1) : const Color(0xFF22C55E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(isCreator ? 'Creator' : 'Member',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                              color: isCreator ? const Color(0xFF1A73E8) : const Color(0xFF22C55E)))),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatBadge({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(icon, color: Colors.white70, size: 16),
    const SizedBox(height: 2),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
  ]));
}
