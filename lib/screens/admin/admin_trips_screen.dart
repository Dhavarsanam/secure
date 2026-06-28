import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_icon_colors.dart';

class AdminTripsScreen extends StatefulWidget {
  const AdminTripsScreen({super.key});
  @override
  State<AdminTripsScreen> createState() => _AdminTripsScreenState();
}

class _AdminTripsScreenState extends State<AdminTripsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _tabController = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabController.dispose(); _searchCtrl.dispose(); super.dispose(); }

  final List<Map<String, dynamic>> _trips = [
    {'code': 'FCW001', 'from': 'Fathima College for Women', 'to': 'Madurai Junction', 'creator': 'Nisha F', 'date': '06 Jun 2026', 'seats': '3/6', 'vehicle': 'Van', 'status': 'active', 'km': 8.2},
    {'code': 'FCW002', 'from': 'Madurai Airport', 'to': 'Fathima College for Women', 'creator': 'Priya S', 'date': '03 Jun 2026', 'seats': '4/4', 'vehicle': 'Car', 'status': 'completed', 'km': 15.6},
    {'code': 'FCW003', 'from': 'Periyar Bus Stand', 'to': 'Fathima College for Women', 'creator': 'Meena R', 'date': '01 Jun 2026', 'seats': '2/3', 'vehicle': 'Auto', 'status': 'completed', 'km': 7.4},
    {'code': 'MDU004', 'from': 'Meenakshi Temple', 'to': 'Fathima College for Women', 'creator': 'Ayesha K', 'date': '30 May 2026', 'seats': '1/4', 'vehicle': 'Car', 'status': 'active', 'km': 10.1},
    {'code': 'MDU005', 'from': 'Madurai Junction', 'to': 'Madurai Airport', 'creator': 'Divya L', 'date': '28 May 2026', 'seats': '3/4', 'vehicle': 'Car', 'status': 'cancelled', 'km': 14.2},
    {'code': 'FCW006', 'from': 'Fathima College for Women', 'to': 'Mattuthavani', 'creator': 'Saranya K', 'date': '25 May 2026', 'seats': '2/6', 'vehicle': 'Bus', 'status': 'completed', 'km': 5.8},
  ];

  List<Map<String, dynamic>> _filtered(String status) => _trips.where((t) {
    final matchSearch = _search.isEmpty ||
        (t['code'] as String).toLowerCase().contains(_search.toLowerCase()) ||
        (t['from'] as String).toLowerCase().contains(_search.toLowerCase()) ||
        (t['to'] as String).toLowerCase().contains(_search.toLowerCase()) ||
        (t['creator'] as String).toLowerCase().contains(_search.toLowerCase());
    final matchStatus = status == 'all' || t['status'] == status;
    return matchSearch && matchStatus;
  }).toList();

  Color _statusColor(String s) {
    switch (s) {
      case 'active': return const Color(0xFF22C55E);
      case 'completed': return const Color(0xFF1A73E8);
      case 'cancelled': return const Color(0xFFEF4444);
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
      appBar: AppBar(
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
            Tab(text: 'All (${_trips.length})'),
            Tab(text: 'Active (${_trips.where((t) => t['status'] == 'active').length})'),
            Tab(text: 'Completed (${_trips.where((t) => t['status'] == 'completed').length})'),
          ],
        ),
      ),
      body: Column(children: [
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
            children: ['all', 'active', 'completed'].map((status) =>
                ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtered(status).length,
                  itemBuilder: (context, i) {
                    final trip = _filtered(status)[i];
                    final color = _statusColor(trip['status'] as String);
                    return Container(
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
                                child: Text('# ${trip['code']}', style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 8),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                                child: Text((trip['status'] as String).toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
                            const Spacer(),
                            Text(trip['date'] as String, style: TextStyle(fontSize: 11, color: ts)),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            const Icon(Icons.radio_button_checked, color: Color(0xFF1A73E8), size: 13),
                            const SizedBox(width: 6),
                            Expanded(child: Text(trip['from'] as String, style: TextStyle(color: tp, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                          ]),
                          const SizedBox(height: 3),
                          Row(children: [
                            const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 13),
                            const SizedBox(width: 6),
                            Expanded(child: Text(trip['to'] as String, style: TextStyle(color: tp, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            Icon(Icons.person_outline, size: 12, color: appIconColor(Icons.person_outline)),
                            const SizedBox(width: 3),
                            Text(trip['creator'] as String, style: TextStyle(fontSize: 11, color: ts)),
                            const SizedBox(width: 12),
                            Icon(Icons.directions_car_outlined, size: 12, color: appIconColor(Icons.directions_car_outlined)),
                            const SizedBox(width: 3),
                            Text(trip['vehicle'] as String, style: TextStyle(fontSize: 11, color: ts)),
                            const SizedBox(width: 12),
                            Icon(Icons.people_outline, size: 12, color: appIconColor(Icons.people_outline)),
                            const SizedBox(width: 3),
                            Text(trip['seats'] as String, style: TextStyle(fontSize: 11, color: ts)),
                            const Spacer(),
                            Text('${trip['km']} km', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
            ).toList(),
          ),
        ),
      ]),
    );
  }
}
