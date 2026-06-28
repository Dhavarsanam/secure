import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

enum NotifType { trip, sos, location, rating, system, weather }

class AppNotif {
  final String id, title, message, time;
  final NotifType type;
  bool isRead;
  AppNotif({required this.id, required this.title, required this.message, required this.time, required this.type, this.isRead = false});
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Spec exact notifications
  final List<AppNotif> _notifs = [
    AppNotif(id: '1', title: 'Trip Created Successfully', message: 'Your trip FCW001 Madurai → Chennai is created!', time: '10:00 AM', type: NotifType.trip),
    AppNotif(id: '2', title: 'Passenger Joined Your Ride', message: 'Priya S joined your trip FCW001. 3/6 seats filled.', time: '10:05 AM', type: NotifType.trip),
    AppNotif(id: '3', title: 'Weather Alert: Light Rain', message: 'Light rain expected in Madurai today. Take umbrella!', time: '10:20 AM', type: NotifType.weather),
    AppNotif(id: '4', title: 'Trip Completed Successfully', message: 'FCW002 Chennai → Trichy completed. Rate your ride!', time: '01:45 PM', type: NotifType.trip, isRead: true),
    AppNotif(id: '5', title: 'SOS Alert Sent', message: 'Your SOS alert has been sent to 3 contacts.', time: '02:10 PM', type: NotifType.sos, isRead: true),
  ];

  int get _unread => _notifs.where((n) => !n.isRead).length;

  // Spec: Different icons for each type
  IconData _icon(NotifType t) {
    switch (t) {
      case NotifType.trip: return Icons.directions_car_rounded;
      case NotifType.sos: return Icons.sos_rounded;
      case NotifType.location: return Icons.location_on_rounded;
      case NotifType.rating: return Icons.star_rounded;
      case NotifType.system: return Icons.verified_rounded;
      case NotifType.weather: return Icons.wb_cloudy_rounded;
    }
  }

  Color _color(NotifType t) {
    switch (t) {
      case NotifType.trip: return const Color(0xFF1A73E8);
      case NotifType.sos: return const Color(0xFFEF4444);
      case NotifType.location: return const Color(0xFF22C55E);
      case NotifType.rating: return const Color(0xFFF59E0B);
      case NotifType.system: return const Color(0xFF7C3AED);
      case NotifType.weather: return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
        title: Row(children: [
          const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
          if (_unread > 0) ...[const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(20)),
                child: Text('$_unread', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))],
        ]),
        actions: [if (_unread > 0) TextButton(
            onPressed: () => setState(() { for (final n in _notifs) n.isRead = true; }),
            child: const Text('Mark all read', style: TextStyle(color: Colors.white70, fontSize: 12)))],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifs.length,
        itemBuilder: (context, i) {
          final n = _notifs[i];
          final color = _color(n.type);
          return Dismissible(
            key: Key(n.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => setState(() => _notifs.removeWhere((x) => x.id == n.id)),
            background: Container(margin: const EdgeInsets.only(bottom: 10), alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white)),
            child: GestureDetector(
              onTap: () => setState(() => n.isRead = true),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: n.isRead ? card : color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: n.isRead ? null : Border.all(color: color.withValues(alpha: 0.25)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Different icon per type (spec requirement)
                  Container(width: 44, height: 44,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(_icon(n.type), color: color, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(n.title,
                          style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.bold, color: tp, fontSize: 13))),
                      // Time (spec: 10:00 AM format)
                      Text(n.time, style: TextStyle(fontSize: 10, color: ts)),
                      if (!n.isRead) ...[const SizedBox(width: 6), Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle))],
                    ]),
                    const SizedBox(height: 3),
                    Text(n.message, style: TextStyle(fontSize: 12, color: ts, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ])),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}