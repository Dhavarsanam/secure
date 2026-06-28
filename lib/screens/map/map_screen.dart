import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/location_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_icon_colors.dart';
import 'live_location_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapCtrl = MapController();
  bool _isTripActive = true;

  // Spec dummy values
  final String _eta = '25 min';
  final double _distance = 18.6;
  final double _speed = 60;
  final String _tripStatus = 'On the way';

  void _confirmEndTrip(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        title: Text('End Trip?', style: TextStyle(color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E), fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to end this trip?', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dctx);
              setState(() => _isTripActive = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Trip ended safely'),
                backgroundColor: const Color(0xFF22C55E),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final location = context.watch<LocationProvider>();
    final trips = context.watch<TripProvider>();
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final pos = location.positionOrDefault;

    // Destination: Madurai Junction
    final dest = const LatLng(9.9252, 78.1198);

    return Scaffold(
      body: Stack(children: [
        // Full screen map
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(initialCenter: LatLng(pos.latitude, pos.longitude), initialZoom: 13),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.secureride.app'),
            // Route polyline (spec: Live route on map)
            PolylineLayer(polylines: [
              Polyline(points: [LatLng(pos.latitude, pos.longitude), dest],
                  color: const Color(0xFF1A73E8), strokeWidth: 4),
            ]),
            MarkerLayer(markers: [
              // Your location
              Marker(point: LatLng(pos.latitude, pos.longitude), width: 44, height: 44,
                  child: Container(
                      decoration: BoxDecoration(color: const Color(0xFF1A73E8), shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color(0xFF1A73E8).withValues(alpha: 0.4), blurRadius: 8)]),
                      child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 22))),
              // Destination
              Marker(point: dest, width: 44, height: 44,
                  child: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 44)),
            ]),
          ],
        ),

        // AppBar overlay
        Positioned(top: 0, left: 0, right: 0,
            child: SafeArea(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFF1A73E8), borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)]),
                    child: const Row(children: [
                      Icon(Icons.map_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text('Live Map', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ])),
                const Spacer(),
                // Locate button
                GestureDetector(
                    onTap: () => _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 15),
                    child: Container(width: 40, height: 40,
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)]),
                        child: const Icon(Icons.my_location_rounded, color: Color(0xFF1A73E8), size: 22))),
              ]),
            ))),

        // Bottom info card (spec: ETA, Distance, Speed, Status)
        Positioned(bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: card,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, -4))]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Route info
                Row(children: [
                  const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF1A73E8), size: 14),
                  const SizedBox(width: 6),
                  Text('Fathima College for Women', style: TextStyle(color: tp, fontSize: 12, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 14),
                  const SizedBox(width: 6),
                  Text('Madurai Junction', style: TextStyle(color: tp, fontSize: 12, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 14),

                // ETA, Distance, Speed (spec requirements)
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _InfoChip(icon: Icons.access_time_rounded, label: 'ETA', value: _eta, color: const Color(0xFF1A73E8)),
                  _InfoChip(icon: Icons.straighten_rounded, label: 'Distance', value: '$_distance km', color: const Color(0xFF22C55E)),
                  _InfoChip(icon: Icons.speed_rounded, label: 'Speed', value: '$_speed km/h', color: const Color(0xFFF59E0B)),
                ]),
                const SizedBox(height: 12),

                // Trip Status (spec: On the way)
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Trip Status: $_tripStatus', style: const TextStyle(color: Color(0xFF22C55E), fontSize: 12, fontWeight: FontWeight.w600)),
                    ])),
                const SizedBox(height: 12),

                // Buttons (spec: Share Live Location + End Trip)
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveLocationScreen())),
                      icon: const Icon(Icons.share_location_rounded, size: 18, color: Color(0xFF1A73E8)),
                      label: const Text('Share Live Location', style: TextStyle(color: Color(0xFF1A73E8), fontSize: 12)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1A73E8)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10)))),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                      onPressed: () => _confirmEndTrip(context),
                      icon: Icon(Icons.stop_circle_rounded, size: 18, color: appIconColor(Icons.stop_circle_rounded)),
                      label: const Text('End Trip', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10)))),
                ]),
              ]),
            )),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: color, size: 20),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
  ]);
}