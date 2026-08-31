import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/firestore_service.dart';
import '../../models/sos_alert_model.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_icon_colors.dart';
import '../../core/utils/time_ago.dart';

// Fully dynamic — every alert comes live from Firestore's `sos_alerts`
// collection (see FirestoreService.allSosAlertsStream). No hardcoded demo
// alerts and no duplicates: each Firestore document ID is unique.
class AdminSosScreen extends StatefulWidget {
  const AdminSosScreen({super.key});
  @override
  State<AdminSosScreen> createState() => _AdminSosScreenState();
}

class _AdminSosScreenState extends State<AdminSosScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(_pulseCtrl);
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  Future<void> _resolve(SosAlertModel alert) async {
    final ok = await _firestoreService.resolveSosAlert(alert.alertId);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Could not resolve this alert'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
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
      body: StreamBuilder<List<SosAlertModel>>(
        stream: _firestoreService.allSosAlertsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(children: [
              _appBar(0, isDark),
              Expanded(child: Center(child: Text('Failed to load SOS alerts', style: TextStyle(color: ts)))),
            ]);
          }
          if (!snapshot.hasData) {
            return Column(children: [
              _appBar(0, isDark),
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)))),
            ]);
          }

          final alerts = snapshot.data!;
          final active = alerts.where((a) => a.status == SosStatus.active).toList();
          final resolved = alerts.where((a) => a.status != SosStatus.active).toList();

          return Column(children: [
            _appBar(active.length, isDark),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  Row(children: [
                    Expanded(child: _SosStat(label: 'Active', value: '${active.length}', color: const Color(0xFFDC2626), card: card, tp: tp, ts: ts)),
                    const SizedBox(width: 12),
                    Expanded(child: _SosStat(label: 'Resolved', value: '${resolved.length}', color: const Color(0xFF22C55E), card: card, tp: tp, ts: ts)),
                    const SizedBox(width: 12),
                    Expanded(child: _SosStat(label: 'Total', value: '${alerts.length}', color: const Color(0xFF7C3AED), card: card, tp: tp, ts: ts)),
                  ]),
                  const SizedBox(height: 24),

                  if (active.isNotEmpty) ...[
                    Row(children: [
                      ScaleTransition(scale: _pulseAnim, child: const Icon(Icons.circle, color: Color(0xFFDC2626), size: 10)),
                      const SizedBox(width: 6),
                      Text('Active Alerts (${active.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
                    ]),
                    const SizedBox(height: 10),
                    ...active.map((alert) => _SosCard(
                        key: ValueKey(alert.alertId),
                        alert: alert, isActive: true, card: card, tp: tp, ts: ts,
                        onResolve: () => _resolve(alert))),
                    const SizedBox(height: 20),
                  ],

                  Text('Resolved Alerts (${resolved.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
                  const SizedBox(height: 10),
                  if (resolved.isEmpty)
                    Text('No resolved alerts yet', style: TextStyle(color: ts, fontSize: 13))
                  else
                    ...resolved.map((alert) => _SosCard(
                        key: ValueKey(alert.alertId),
                        alert: alert, isActive: false, card: card, tp: tp, ts: ts,
                        onResolve: () {})),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _appBar(int activeCount, bool isDark) => AppBar(
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
          child: Text('$activeCount active', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
    ],
  );
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
  final SosAlertModel alert;
  final bool isActive;
  final Color card, tp, ts;
  final VoidCallback onResolve;
  const _SosCard({super.key, required this.alert, required this.isActive, required this.card, required this.tp, required this.ts, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFFDC2626) : const Color(0xFF22C55E);
    final location = alert.locationAddress ?? '${alert.latitude.toStringAsFixed(4)}, ${alert.longitude.toStringAsFixed(4)}';
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
              Expanded(child: Text(alert.senderName, style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 14), overflow: TextOverflow.ellipsis)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(isActive ? '🔴 ACTIVE' : (alert.status == SosStatus.cancelled ? 'CANCELLED' : '✅ RESOLVED'),
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color))),
            ]),
            Text(alert.senderEmail, style: TextStyle(fontSize: 11, color: ts)),
          ])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.location_on_outlined, size: 13, color: appIconColor(Icons.location_on_outlined)),
          const SizedBox(width: 4),
          Expanded(child: Text(location, style: TextStyle(fontSize: 12, color: tp, fontWeight: FontWeight.w500))),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.access_time, size: 13, color: appIconColor(Icons.access_time)),
          const SizedBox(width: 4),
          Text(timeAgo(alert.triggeredAt), style: TextStyle(fontSize: 11, color: ts)),
          if (alert.tripCode != null) ...[
            const SizedBox(width: 12),
            Icon(Icons.directions_car_outlined, size: 13, color: appIconColor(Icons.directions_car_outlined)),
            const SizedBox(width: 4),
            Text('Trip: ${alert.tripCode}', style: TextStyle(fontSize: 11, color: ts)),
          ],
        ]),
        if (alert.senderPhone.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.phone_outlined, size: 13, color: appIconColor(Icons.phone_outlined)),
            const SizedBox(width: 4),
            Text(alert.senderPhone, style: TextStyle(fontSize: 11, color: ts)),
          ]),
        ],
        if (isActive) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Calling ${alert.senderName}...'),
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