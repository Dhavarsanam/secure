import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/location_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_icon_colors.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});
  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  bool _isSharing = false;
  String _duration = '30 Minutes';

  void _showAddContactDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    InputDecoration deco(String h) => InputDecoration(
          hintText: h,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          filled: true,
          fillColor: isDark ? const Color(0xFF252538) : const Color(0xFFF5F7FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        );
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        title: Text('Add Contact', style: TextStyle(color: tp, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, style: TextStyle(color: tp), decoration: deco('Name (e.g. Amma)')),
          const SizedBox(height: 10),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, style: TextStyle(color: tp), decoration: deco('Phone number')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter name and phone'), backgroundColor: Color(0xFFEF4444), behavior: SnackBarBehavior.floating));
                return;
              }
              await context.read<AuthProvider>().addContact('$name: $phone');
              if (!dctx.mounted) return;
              Navigator.pop(dctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('$name added to safety contacts'),
                backgroundColor: const Color(0xFF22C55E),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  final List<Map<String, dynamic>> _contacts = [
    {'name': 'Amma', 'phone': '+91 XXXXX XXXXX', 'color': 0xFF1A73E8},
    {'name': 'Appa', 'phone': '+91 XXXXX XXXXX', 'color': 0xFF22C55E},
    {'name': 'Friend', 'phone': '+91 XXXXX XXXXX', 'color': 0xFF7C3AED},
  ];

  final List<String> _durations = [
    '30 Minutes',
    '1 Hour',
    'Until Trip Ends',
    'Custom Duration',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final location = context.watch<LocationProvider>();
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final border = isDark ? const Color(0xFF2D2D44) : const Color(0xFFE5E7EB);
    final pos = location.positionOrDefault;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        title: const Text('Location Share', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Live Location Sharing toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Color(0xFF22C55E), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live Location Sharing',
                        style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 15)),
                    Text(
                      _isSharing ? 'Currently sharing your location' : 'Share with approved contacts',
                      style: TextStyle(fontSize: 12, color: ts),
                    ),
                  ],
                )),
                Switch(
                  value: _isSharing,
                  onChanged: (v) => setState(() => _isSharing = v),
                  activeColor: const Color(0xFF22C55E),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Mini Map
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(pos.latitude, pos.longitude),
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.secureride.app',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(pos.latitude, pos.longitude),
                        width: 40, height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A73E8),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                              color: const Color(0xFF1A73E8).withValues(alpha: 0.4),
                              blurRadius: 8,
                            )],
                          ),
                          child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sharing With
            Text('Sharing With (${_contacts.length})',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tp)),
            const SizedBox(height: 10),

            ..._contacts.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(c['color'] as int).withValues(alpha: 0.1),
                  child: Text(
                    (c['name'] as String)[0],
                    style: TextStyle(color: Color(c['color'] as int), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['name'] as String,
                        style: TextStyle(fontWeight: FontWeight.w600, color: tp, fontSize: 13)),
                    Text(c['phone'] as String,
                        style: TextStyle(fontSize: 11, color: ts)),
                  ],
                )),
                // Quick call button
                IconButton(
                  icon: const Icon(Icons.phone_rounded, color: Color(0xFF22C55E), size: 20),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Calling ${c['name']}...'),
                      backgroundColor: const Color(0xFF22C55E),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    ));
                  },
                ),
              ]),
            )),

            // Add Contact
            GestureDetector(
              onTap: () => _showAddContactDialog(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1A73E8).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: Color(0xFF1A73E8), size: 20),
                    SizedBox(width: 6),
                    Text('Add Contact',
                        style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Share Duration
            Text('Share Duration',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tp)),
            const SizedBox(height: 10),

            ..._durations.map((d) => GestureDetector(
              onTap: () => setState(() => _duration = d),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _duration == d ? const Color(0xFF1A73E8) : card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _duration == d
                        ? const Color(0xFF1A73E8)
                        : border,
                  ),
                ),
                child: Row(children: [
                  Icon(
                    _duration == d
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: _duration == d ? Colors.white : ts,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(d,
                      style: TextStyle(
                        color: _duration == d ? Colors.white : tp,
                        fontWeight: _duration == d ? FontWeight.w600 : FontWeight.normal,
                      )),
                ]),
              ),
            )),
            const SizedBox(height: 16),

            // Current Status
            if (_isSharing) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 8, height: 8,
                        decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Sharing Live',
                        style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'Started At: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} - ${now.day} May ${now.year}',
                    style: TextStyle(fontSize: 12, color: ts),
                  ),
                ]),
              ),
              const SizedBox(height: 10),

              // Stop Sharing
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _isSharing = false),
                  icon: Icon(Icons.stop_circle_rounded, color: appIconColor(Icons.stop_circle_rounded)),
                  label: const Text('Stop Sharing',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _isSharing = true),
                  icon: Icon(Icons.share_location_rounded, color: appIconColor(Icons.share_location_rounded)),
                  label: const Text('Start Sharing',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}