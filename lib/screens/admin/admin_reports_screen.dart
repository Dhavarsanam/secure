import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_icon_colors.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _period = 'This Month';
  final List<String> _periods = ['This Week', 'This Month', 'Last 3 Months', 'This Year'];

  // Monthly trip data (dummy)
  final List<Map<String, dynamic>> _monthlyData = [
    {'month': 'Jan', 'trips': 68, 'users': 24},
    {'month': 'Feb', 'trips': 82, 'users': 31},
    {'month': 'Mar', 'trips': 95, 'users': 38},
    {'month': 'Apr', 'trips': 110, 'users': 42},
    {'month': 'May', 'trips': 143, 'users': 56},
    {'month': 'Jun', 'trips': 127, 'users': 57},
  ];

  // Vehicle usage
  final List<Map<String, dynamic>> _vehicleData = [
    {'type': 'Car', 'count': 412, 'color': 0xFF1A73E8, 'pct': 0.40},
    {'type': 'Van', 'count': 287, 'color': 0xFF22C55E, 'pct': 0.28},
    {'type': 'Auto', 'count': 198, 'color': 0xFFF59E0B, 'pct': 0.19},
    {'type': 'Bike', 'count': 89, 'color': 0xFF8B5CF6, 'pct': 0.09},
    {'type': 'Bus', 'count': 38, 'color': 0xFFEF4444, 'pct': 0.04},
  ];

  // Top routes
  final List<Map<String, dynamic>> _topRoutes = [
    {'from': 'Fathima College', 'to': 'Madurai Junction', 'count': 234, 'km': 8.2},
    {'from': 'Madurai Airport', 'to': 'Fathima College', 'count': 187, 'km': 15.6},
    {'from': 'Periyar Bus Stand', 'to': 'Fathima College', 'count': 156, 'km': 7.4},
    {'from': 'Meenakshi Temple', 'to': 'Fathima College', 'count': 142, 'km': 10.1},
    {'from': 'Mattuthavani', 'to': 'Fathima College', 'count': 98, 'km': 5.8},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF0F4FF);
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final maxTrips = _monthlyData.map((d) => d['trips'] as int).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: Icon(Icons.download_rounded, color: appIconColor(Icons.download_rounded)), onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Report exported! (Demo)'),
                backgroundColor: const Color(0xFF22C55E),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16)));
          }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Period Selector
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

          // Summary cards
          Row(children: [
            Expanded(child: _SummaryCard(title: 'Total Trips', value: '1,024', change: '+12%', icon: Icons.directions_car_rounded, color: const Color(0xFF1A73E8), card: card, tp: tp, ts: ts)),
            const SizedBox(width: 12),
            Expanded(child: _SummaryCard(title: 'New Users', value: '57', change: '+8%', icon: Icons.people_rounded, color: const Color(0xFF22C55E), card: card, tp: tp, ts: ts)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _SummaryCard(title: 'Total KM', value: '8,742', change: '+15%', icon: Icons.straighten_rounded, color: const Color(0xFFF59E0B), card: card, tp: tp, ts: ts)),
            const SizedBox(width: 12),
            Expanded(child: _SummaryCard(title: 'SOS Alerts', value: '5', change: '-2', icon: Icons.sos_rounded, color: const Color(0xFFEF4444), card: card, tp: tp, ts: ts)),
          ]),

          const SizedBox(height: 24),

          // Monthly Trips Chart
          Text('Monthly Trips', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _monthlyData.map((d) {
                    final h = (d['trips'] as int) / maxTrips * 120;
                    return Column(children: [
                      Text('${d['trips']}', style: TextStyle(fontSize: 10, color: const Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(width: 32, height: h,
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                              borderRadius: BorderRadius.circular(6))),
                      const SizedBox(height: 6),
                      Text(d['month'] as String, style: TextStyle(fontSize: 10, color: ts)),
                    ]);
                  }).toList()),
            ]),
          ),

          const SizedBox(height: 24),

          // Vehicle Usage
          Text('Vehicle Usage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
            child: Column(children: _vehicleData.map((v) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(width: 36, child: Text(v['type'] as String, style: TextStyle(fontSize: 12, color: tp, fontWeight: FontWeight.w500))),
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

          // Top Routes
          Text('Top Routes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
            child: Column(children: _topRoutes.asMap().entries.map((entry) {
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
                      Text('${r['km']} km', style: TextStyle(fontSize: 10, color: ts)),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text('${r['count']} trips', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)))),
                  ]),
                ),
                if (i < _topRoutes.length - 1) const Divider(height: 1, indent: 14, endIndent: 14),
              ]);
            }).toList()),
          ),

          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title, value, change;
  final IconData icon;
  final Color color, card, tp, ts;
  const _SummaryCard({required this.title, required this.value, required this.change,
    required this.icon, required this.color, required this.card, required this.tp, required this.ts});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16)),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(change, style: const TextStyle(fontSize: 9, color: Color(0xFF22C55E), fontWeight: FontWeight.bold))),
      ]),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tp)),
      Text(title, style: TextStyle(fontSize: 11, color: ts)),
    ]),
  );
}
