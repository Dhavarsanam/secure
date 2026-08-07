import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/theme_provider.dart';
import '../../providers/notification_settings_provider.dart';
import '../../providers/notifications_provider.dart';
import '../trip/trip_detail_screen.dart';
import '../sos/sos_screen.dart';
import '../map/weather_screen.dart';
import '../map/live_location_screen.dart';
import '../settings/settings_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // Different icon per notification type
  IconData _icon(NotifType t) {
    switch (t) {
      case NotifType.tripCreated:
      case NotifType.tripJoined:
      case NotifType.tripJoinedByMe:
        return Icons.directions_car_rounded;
      case NotifType.tripActive:
        return Icons.play_circle_fill_rounded;
      case NotifType.tripCompleted:
        return Icons.check_circle_rounded;
      case NotifType.tripCancelled:
        return Icons.cancel_rounded;
      case NotifType.sos:
        return Icons.sos_rounded;
      case NotifType.weatherAlert:
        return Icons.cloud_rounded;
      case NotifType.trafficAlert:
        return Icons.traffic_rounded;
      case NotifType.loginSuccess:
        return Icons.login_rounded;
      case NotifType.logout:
        return Icons.logout_rounded;
      case NotifType.locationShared:
        return Icons.share_location_rounded;
    }
  }

  Color _color(NotifType t) {
    switch (t) {
      case NotifType.tripCreated:
      case NotifType.tripJoined:
      case NotifType.tripJoinedByMe:
        return const Color(0xFF1A73E8);
      case NotifType.tripActive:
        return const Color(0xFF14B8A6);
      case NotifType.tripCompleted:
        return const Color(0xFF22C55E);
      case NotifType.tripCancelled:
        return const Color(0xFFF59E0B);
      case NotifType.sos:
        return const Color(0xFFEF4444);
      case NotifType.weatherAlert:
        return const Color(0xFF0EA5E9);
      case NotifType.trafficAlert:
        return const Color(0xFFF97316);
      case NotifType.loginSuccess:
        return const Color(0xFF22C55E);
      case NotifType.logout:
        return const Color(0xFF6B7280);
      case NotifType.locationShared:
        return const Color(0xFF8B5CF6);
    }
  }

  // Groups by real calendar day — Today / Yesterday / an actual date —
  // computed from each notification's real timestamp (no hardcoded labels).
  String _dayLabel(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(t.year, t.month, t.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMM yyyy').format(t);
  }

  // Opens the screen the notification is about — trip, SOS, or weather/traffic.
  void _openRelated(BuildContext context, AppNotif n) {
    switch (n.type) {
      case NotifType.tripCreated:
      case NotifType.tripJoined:
      case NotifType.tripJoinedByMe:
      case NotifType.tripActive:
      case NotifType.tripCompleted:
      case NotifType.tripCancelled:
        final trip = n.tripId != null
            ? context.read<NotificationsProvider>().tripById(n.tripId!)
            : null;
        if (trip != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)));
        }
        break;
      case NotifType.sos:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SosScreen()));
        break;
      case NotifType.weatherAlert:
      case NotifType.trafficAlert:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()));
        break;
      case NotifType.locationShared:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveLocationScreen()));
        break;
      case NotifType.loginSuccess:
      case NotifType.logout:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
        break;
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This will remove every notification currently in your list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear All')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<NotificationsProvider>().clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final notificationsEnabled = context.watch<NotificationSettingsProvider>().notificationsEnabled;
    final notifProvider = context.watch<NotificationsProvider>();
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    final notifs = notifProvider.notifications; // already sorted newest-first
    final unread = notifs.where((n) => !n.isRead).length;

    // Build day-grouped widget list from real timestamps
    final order = <String>[];
    for (final n in notifs) {
      final label = _dayLabel(n.time);
      if (!order.contains(label)) order.add(label);
    }
    final children = <Widget>[];
    for (final day in order) {
      final dayNotifs = notifs.where((n) => _dayLabel(n.time) == day).toList();
      if (dayNotifs.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10, left: 2),
        child: Row(children: [
          Text(day, style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 15)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: ts.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Text('${dayNotifs.length}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ts)),
          ),
        ]),
      ));
      for (final n in dayNotifs) {
        children.add(_notifCard(context, n, card, tp, ts));
      }
      children.add(const SizedBox(height: 10));
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
        title: Row(children: [
          const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
          if (notificationsEnabled && unread > 0) ...[const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(20)),
                child: Text('$unread', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))],
        ]),
        actions: [
          if (notificationsEnabled && unread > 0) TextButton(
              onPressed: () => context.read<NotificationsProvider>().markAllRead(),
              child: const Text('Mark all read', style: TextStyle(color: Colors.white70, fontSize: 12))),
          if (notificationsEnabled && notifs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
              tooltip: 'Clear All',
              onPressed: () => _confirmClearAll(context),
            ),
          Switch(
            value: notificationsEnabled,
            onChanged: (v) => context.read<NotificationSettingsProvider>().setEnabled(v),
            activeColor: Colors.white,
            activeTrackColor: Colors.white38,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !notificationsEnabled
          ? Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_off_rounded, size: 56, color: ts.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text('Notifications are turned off', style: TextStyle(color: tp, fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Turn the switch above back on to see trip, SOS, and safety alerts.',
              style: TextStyle(color: ts, fontSize: 12.5, height: 1.4), textAlign: TextAlign.center),
        ]),
      ))
          : children.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.notifications_off_outlined, size: 56, color: ts.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text('No Notifications Yet', style: TextStyle(color: tp, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Trip, SOS, weather, and traffic alerts will show up here.',
            style: TextStyle(color: ts, fontSize: 12.5, height: 1.4), textAlign: TextAlign.center),
      ]))
          : ListView(padding: const EdgeInsets.all(16), children: children),
    );
  }

  Widget _notifCard(BuildContext context, AppNotif n, Color card, Color tp, Color ts) {
    final color = _color(n.type);
    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => context.read<NotificationsProvider>().dismiss(n.id),
      background: Container(margin: const EdgeInsets.only(bottom: 10), alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white)),
      child: GestureDetector(
        onTap: () {
          context.read<NotificationsProvider>().markRead(n.id);
          _openRelated(context, n);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: n.isRead ? card : color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: n.isRead ? null : Border.all(color: color.withValues(alpha: 0.25)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 44, height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(_icon(n.type), color: color, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(n.title,
                    style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.bold, color: tp, fontSize: 13))),
                Text(DateFormat('hh:mm a').format(n.time), style: TextStyle(fontSize: 10, color: ts)),
                if (!n.isRead) ...[const SizedBox(width: 6), Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle))],
              ]),
              const SizedBox(height: 3),
              Text(n.message, style: TextStyle(fontSize: 12, color: ts, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
          ]),
        ),
      ),
    );
  }
}