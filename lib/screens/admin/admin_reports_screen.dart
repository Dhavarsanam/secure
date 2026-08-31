import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/services/firestore_service.dart';
import '../../models/trip_model.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';

// Fully dynamic — every number and chart here is computed live from
// Firestore's `trips` and `users` collections (see
// FirestoreService.allTripsStream / allUsersStream). Nothing is hardcoded.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _period = 'This Month';
  final List<String> _periods = ['This Week', 'This Month', 'Last 3 Months', 'This Year'];
  final _firestoreService = FirestoreService();

  DateTime get _periodStart {
    final now = DateTime.now();
    switch (_period) {
      case 'This Week': return now.subtract(const Duration(days: 7));
      case 'Last 3 Months': return DateTime(now.year, now.month - 3, now.day);
      case 'This Year': return DateTime(now.year, 1, 1);
      case 'This Month':
      default: return DateTime(now.year, now.month, 1);
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<TripModel>>(
        stream: _firestoreService.allTripsStream(),
        builder: (context, tripSnap) {
          if (!tripSnap.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
          }
          final allTrips = tripSnap.data!;

          return StreamBuilder<List<UserModel>>(
            stream: _firestoreService.allUsersStream(),
            builder: (context, userSnap) {
              final allUsers = userSnap.data ?? const <UserModel>[];

              final periodTrips = allTrips.where((t) => t.createdAt.isAfter(_periodStart)).toList();
              final periodNewUsers = allUsers.where((u) => u.createdAt.isAfter(_periodStart)).length;
              final periodKm = periodTrips.fold<double>(0, (sum, t) => sum + (t.distanceKm ?? 0));

              // Monthly trips/new-users for the last 6 months, oldest first.
              final now = DateTime.now();
              final months = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1));
              final monthlyData = months.map((m) {
                final tripsInMonth = allTrips.where((t) => t.createdAt.year == m.year && t.createdAt.month == m.month).length;
                final usersInMonth = allUsers.where((u) => u.createdAt.year == m.year && u.createdAt.month == m.month).length;
                return {'month': DateFormat('MMM').format(m), 'trips': tripsInMonth, 'users': usersInMonth};
              }).toList();
              final maxTrips = monthlyData.map((d) => d['trips'] as int).fold(0, (a, b) => a > b ? a : b);

              // Vehicle usage, from all trips (whole-fleet view).
              final vehicleColors = <String, int>{
                'Car': 0xFF1A73E8, 'Van': 0xFF22C55E, 'Auto': 0xFFF59E0B, 'Bike': 0xFF8B5CF6, 'Bus': 0xFFEF4444,
              };
              final vehicleCounts = <String, int>{};
              for (final t in allTrips) {
                vehicleCounts[t.vehicleType] = (vehicleCounts[t.vehicleType] ?? 0) + 1;
              }
              final vehicleData = vehicleCounts.entries.map((e) => {
                'type': e.key,
                'count': e.value,
                'color': vehicleColors[e.key] ?? 0xFF6B7280,
                'pct': allTrips.isEmpty ? 0.0 : e.value / allTrips.length,
              }).toList()
                ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

              // Top routes, from all trips.
              final routeCounts = <String, Map<String, dynamic>>{};
              for (final t in allTrips) {
                final key = '${t.startLocationName}→${t.destinationName}';
                final existing = routeCounts[key];
                if (existing == null) {
                  routeCounts[key] = {'from': t.startLocationName, 'to': t.destinationName, 'count': 1, 'km': t.distanceKm ?? 0.0};
                } else {
                  existing['count'] = (existing['count'] as int) + 1;
                }
              }
              final topRoutes = routeCounts.values.toList()
                ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
              final topRoutesTop5 = topRoutes.take(5).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children:
                  _periods.map((p) => Padding(padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(label: Text(p, style: TextStyle(fontSize: 12,
                          color: _period == p ? Colors.white : tp, fontWeight: _period == p ? FontWeight.w600 : FontWeight.normal)),
                          selected: _period == p,
                          onSelected: (_) => setState(() => _period = p),
                          selectedColor: const Color(0xFF7C3AED),
                          backgroundColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F7FA),
                          side: BorderSide.none))).toList())),

                  const SizedBox(height: 20),

                  Row(children: [
                    Expanded(child: _SummaryCard(title: 'Trips ($_period)', value: '${periodTrips.length}', icon: Icons.directions_car_rounded, color: const Color(0xFF1A73E8), card: card, tp: tp, ts: ts)),
                    const SizedBox(width: 12),
                    Expanded(child: _SummaryCard(title: 'New Users', value: '$periodNewUsers', icon: Icons.people_rounded, color: const Color(0xFF22C55E), card: card, tp: tp, ts: ts)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _SummaryCard(title: 'Total KM', value: periodKm.toStringAsFixed(1), icon: Icons.straighten_rounded, color: const Color(0xFFF59E0B), card: card, tp: tp, ts: ts)),
                    const SizedBox(width: 12),
                    Expanded(child: _SosSummaryCard(periodStart: _periodStart, firestoreService: _firestoreService, card: card, tp: tp, ts: ts)),
                  ]),

                  const SizedBox(height: 24),

                  Text('Monthly Trips', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                    child: monthlyData.every((d) => (d['trips'] as int) == 0)
                        ? Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text('No trip data yet', style: TextStyle(color: ts)))
                        : Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: monthlyData.map((d) {
                          final h = maxTrips == 0 ? 4.0 : (d['trips'] as int) / maxTrips * 120;
                          return Column(children: [
                            Text('${d['trips']}', style: TextStyle(fontSize: 10, color: const Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(width: 32, height: h < 4 ? 4 : h,
                                decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                                    borderRadius: BorderRadius.circular(6))),
                            const SizedBox(height: 6),
                            Text(d['month'] as String, style: TextStyle(fontSize: 10, color: ts)),
                          ]);
                        }).toList()),
                  ),

                  const SizedBox(height: 24),

                  Text('Vehicle Usage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                    child: vehicleData.isEmpty
                        ? Text('No trips yet', style: TextStyle(color: ts))
                        : Column(children: vehicleData.map((v) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        SizedBox(width: 36, child: Text(v['type'] as String, style: TextStyle(fontSize: 12, color: tp, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: v['pct'] as double,
                                backgroundColor: Color(v['color'] as int).withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation(Color(v['color'] as int)), minHeight: 8))),
                        const SizedBox(width: 8),
                        Text('${v['count']}', style: TextStyle(fontSize: 11, color: Color(v['color'] as int), fontWeight: FontWeight.bold)),
                      ]),
                    )).toList()),
                  ),

                  const SizedBox(height: 24),

                  Text('Top Routes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                    child: topRoutesTop5.isEmpty
                        ? Padding(padding: const EdgeInsets.all(16), child: Text('No trips yet', style: TextStyle(color: ts)))
                        : Column(children: topRoutesTop5.asMap().entries.map((entry) {
                      final i = entry.key;
                      final r = entry.value;
                      return Column(children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Container(width: 24, height: 24,
                                decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                child: Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))))),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${r['from']} → ${r['to']}', style: TextStyle(fontSize: 12, color: tp, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                              Text('${(r['km'] as double).toStringAsFixed(1)} km', style: TextStyle(fontSize: 10, color: ts)),
                            ])),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                                child: Text('${r['count']} trips', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)))),
                          ]),
                        ),
                        if (i < topRoutesTop5.length - 1) const Divider(height: 1, indent: 14, endIndent: 14),
                      ]);
                    }).toList()),
                  ),

                  const SizedBox(height: 20),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class _SosSummaryCard extends StatelessWidget {
  final DateTime periodStart;
  final FirestoreService firestoreService;
  final Color card, tp, ts;
  const _SosSummaryCard({required this.periodStart, required this.firestoreService, required this.card, required this.tp, required this.ts});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: firestoreService.allSosAlertsStream(),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? const [];
        final periodCount = alerts.where((a) => a.triggeredAt.isAfter(periodStart)).length;
        return _SummaryCard(title: 'SOS Alerts', value: '$periodCount', icon: Icons.sos_rounded, color: const Color(0xFFEF4444), card: card, tp: tp, ts: ts);
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color, card, tp, ts;
  const _SummaryCard({required this.title, required this.value,
    required this.icon, required this.color, required this.card, required this.tp, required this.ts});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16)),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tp)),
      Text(title, style: TextStyle(fontSize: 11, color: ts)),
    ]),
  );
}