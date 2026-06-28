import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_icon_colors.dart';

class AdminSosScreen extends StatefulWidget {
  const AdminSosScreen({super.key});
  @override
  State<AdminSosScreen> createState() => _AdminSosScreenState();
}

class _AdminSosScreenState extends State<AdminSosScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final List<Map<String, dynamic>> _alerts = [
    {'id': 's001', 'name': 'Nisha Fathima', 'email': 'nisha@fcw.edu', 'location': 'Fathima College for Women, Madurai', 'time': '2 min ago', 'status': 'active', 'tripCode': 'FCW001', 'lat': 9.9601, 'lng': 78.0766},
    {'id': 's002', 'name': 'Priya S', 'email': 'priya@example.com', 'location': 'Madurai Junction', 'time': '8 min ago', 'status': 'active', 'tripCode': 'MDU004', 'lat': 9.9252, 'lng': 78.1198},
    {'id': 's003', 'name': 'Meena Ravi', 'email': 'meena@yahoo.com', 'location': 'Bypass Road, Madurai', 'time': '15 min ago', 'status': 'active', 'tripCode': 'FCW003', 'lat': 9.9101, 'lng': 78.0956},
    {'id': 's004', 'name': 'Divya L', 'email': 'divya@fcw.edu', 'location': 'Meenakshi Temple, Madurai', 'time': '1 hr ago', 'status': 'resolved', 'tripCode': 'MDU005', 'lat': 9.9195, 'lng': 78.1193},
    {'id': 's005', 'name': 'Saranya K', 'email': 'saranya@gmail.com', 'location': 'Mattuthavani, Madurai', 'time': '3 hr ago', 'status': 'resolved', 'tripCode': 'FCW006', 'lat': 9.9351, 'lng': 78.1012},
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(_pulseCtrl);
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _active => _alerts.where((a) => a['status'] == 'active').toList();
  List<Map<String, dynamic>> get _resolved => _alerts.where((a) => a['status'] == 'resolved').toList();

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
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Row(children: [
          ScaleTransition(scale: _pulseAnim,
              child: Icon(Icons.sos_rounded, size: 24, color: appIconColor(Icons.sos_rounded))),
          const SizedBox(width: 8),
          const Text('SOS Monitor', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          Container(margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
              child: Text('${_active.length} active', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Stats
          Row(children: [
            Expanded(child: _SosStat(label: 'Active', value: '${_active.length}', color: const Color(0xFFDC2626), card: card, tp: tp, ts: ts)),
            const SizedBox(width: 12),
            Expanded(child: _SosStat(label: 'Resolved', value: '${_resolved.length}', color: const Color(0xFF22C55E), card: card, tp: tp, ts: ts)),
            const SizedBox(width: 12),
            Expanded(child: _SosStat(label: 'Total', value: '${_alerts.length}', color: const Color(0xFF7C3AED), card: card, tp: tp, ts: ts)),
          ]),
          const SizedBox(height: 24),

          // Active Alerts
          if (_active.isNotEmpty) ...[
            Row(children: [
              ScaleTransition(scale: _pulseAnim, child: const Icon(Icons.circle, color: Color(0xFFDC2626), size: 10)),
              const SizedBox(width: 6),
              Text('Active Alerts (${_active.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
            ]),
            const SizedBox(height: 10),
            ..._active.map((alert) => _SosCard(alert: alert, isActive: true, card: card, tp: tp, ts: ts,
                onResolve: () => setState(() => alert['status'] = 'resolved'))),
            const SizedBox(height: 20),
          ],

          // Resolved Alerts
          Text('Resolved Alerts (${_resolved.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 10),
          ..._resolved.map((alert) => _SosCard(alert: alert, isActive: false, card: card, tp: tp, ts: ts,
              onResolve: () {})),
        ]),
      ),
    );
  }
}

class _SosStat extends StatelessWidget {
  final String label, value;
  final Color color, card, tp, ts;
  const _SosStat({required this.label, required this.value, required this.color, required this.card, required this.tp, required this.ts});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 12, color: ts)),
    ]),
  );
}

class _SosCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final bool isActive;
  final Color card, tp, ts;
  final VoidCallback onResolve;
  const _SosCard({required this.alert, required this.isActive, required this.card, required this.tp, required this.ts, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFFDC2626) : const Color(0xFF22C55E);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: isActive ? [BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: 0.1), blurRadius: 12)] : [],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.sos_rounded, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(alert['name'] as String, style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 14)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(isActive ? '🔴 ACTIVE' : '✅ RESOLVED',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color))),
            ]),
            Text(alert['email'] as String, style: TextStyle(fontSize: 11, color: ts)),
          ])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.location_on_outlined, size: 13, color: appIconColor(Icons.location_on_outlined)),
          const SizedBox(width: 4),
          Expanded(child: Text(alert['location'] as String, style: TextStyle(fontSize: 12, color: tp, fontWeight: FontWeight.w500))),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.access_time, size: 13, color: appIconColor(Icons.access_time)),
          const SizedBox(width: 4),
          Text(alert['time'] as String, style: TextStyle(fontSize: 11, color: ts)),
          const SizedBox(width: 12),
          Icon(Icons.directions_car_outlined, size: 13, color: appIconColor(Icons.directions_car_outlined)),
          const SizedBox(width: 4),
          Text('Trip: ${alert['tripCode']}', style: TextStyle(fontSize: 11, color: ts)),
        ]),
        if (isActive) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Calling ${alert['name']}...'),
                backgroundColor: const Color(0xFF1A73E8),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              )),
              icon: const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF1A73E8)),
              label: const Text('Call', style: TextStyle(color: Color(0xFF1A73E8), fontSize: 12)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1A73E8)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 6)),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              onPressed: onResolve,
              icon: Icon(Icons.check_circle_outline, size: 14, color: appIconColor(Icons.check_circle_outline)),
              label: const Text('Resolve', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 6)),
            )),
          ]),
        ],
      ]),
    );
  }
}
