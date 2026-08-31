import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/location_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_icon_colors.dart';
import '../../core/services/location_service.dart' show LocationFailureReason;
import 'package:url_launcher/url_launcher.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});
  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  String _duration = '30 Minutes';
  // Local flag only for the "stop" direction — stopping should be
  // near-instant and doesn't get the enabling spinner, but the buttons
  // still need to be disabled for the brief moment the backend call is
  // in flight so a double-tap can't fire two stop requests at once.
  bool _isStopping = false;

  @override
  void initState() {
    super.initState();
    // Sync the toggle with whatever's actually persisted/on the backend
    // as soon as the screen opens, instead of always starting from "off".
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>().currentUser;
      if (auth != null) {
        final locationProvider = context.read<LocationProvider>();
        await locationProvider.restoreSharingState(auth.uid);
        if (!mounted) return;
        await context.read<AuthProvider>().setLocationSharing(locationProvider.isSharing);
      }
    });
  }

  Future<void> _toggleSharing(bool turnOn) async {
    final auth = context.read<AuthProvider>().currentUser;
    if (auth == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please log in again to share your location.'),
        backgroundColor: Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ));
      return;
    }
    final locationProvider = context.read<LocationProvider>();
    try {
      if (turnOn) {
        // isEnabling (and its spinner) is driven entirely by the provider
        // here — startSharing() only flips isSharing to true once the
        // permission check, GPS fix, and backend write have all
        // succeeded, and never touches it on failure.
        final ok = await locationProvider.startSharing(
          uid: auth.uid,
          userName: auth.fullName,
          userEmail: auth.email,
        );
        if (ok && mounted) {
          await context.read<AuthProvider>().setLocationSharing(true);
          // Turning sharing on used to jump straight to an SMS composer.
          // Now it asks which channel to use instead, so the user picks
          // SMS / WhatsApp / Mail themselves before anything opens.
          await _showShareChannelSheet();
        }
        if (!mounted) return;
        if (!ok) {
          _showLocationFailureSnackBar(locationProvider);
        }
      } else {
        setState(() => _isStopping = true);
        final ok = await locationProvider.stopSharing(auth.uid);
        if (ok && mounted) {
          await context.read<AuthProvider>().setLocationSharing(false);
        }
        if (!mounted) return;
        if (!ok) {
          final reason = locationProvider.lastError ?? 'Could not stop sharing. Try again.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(reason),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ));
        }
      }
    } catch (e) {
      // Guarantees the toggle never fails completely silently — any
      // unexpected error (e.g. a web/browser plugin hiccup) now surfaces
      // here instead of leaving the switch stuck with no feedback at all.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Something went wrong: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
      }
    } finally {
      if (mounted) setState(() => _isStopping = false);
    }
  }

  // Shows the failure reason and, when it's something the user can fix
  // from a settings screen (GPS off, or permission blocked), offers a
  // one-tap "Settings" action instead of leaving them to hunt for the
  // right screen themselves.
  void _showLocationFailureSnackBar(LocationProvider locationProvider) {
    final reason = locationProvider.lastErrorReason;
    final message = locationProvider.lastError ?? 'Could not get your location. Check GPS/location permission.';

    SnackBarAction? action;
    if (reason == LocationFailureReason.serviceDisabled) {
      action = SnackBarAction(
        label: 'Turn On',
        textColor: Colors.white,
        onPressed: () => locationProvider.openDeviceLocationSettings(),
      );
    } else if (reason == LocationFailureReason.permissionDeniedForever) {
      action = SnackBarAction(
        label: 'Settings',
        textColor: Colors.white,
        onPressed: () => locationProvider.openAppPermissionSettings(),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: action,
    ));
  }

  // Builds the same "I'm sharing my live location" message every channel
  // below sends, so SMS/WhatsApp/Mail always say the same thing.
  String _shareMessageBody() {
    final auth = context.read<AuthProvider>().currentUser;
    final locationProvider = context.read<LocationProvider>();
    final pos = locationProvider.currentPosition ?? locationProvider.positionOrDefault;
    final mapsLink = 'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
    final name = auth?.fullName ?? 'I';
    return "$name'm sharing my live location via SecureRide:\n$mapsLink";
  }

  // Bottom sheet asking which channel to send the live-location link
  // through. Shown right after sharing turns on, so the user picks once
  // up front instead of the app guessing for them.
  Future<void> _showShareChannelSheet() async {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);

    Widget option(IconData icon, Color color, String label, VoidCallback onTap) {
      return ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: TextStyle(color: tp, fontWeight: FontWeight.w600)),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      );
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Text('Share location via', style: TextStyle(color: tp, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          option(Icons.sms_rounded, const Color(0xFF22C55E), 'SMS', _shareViaSms),
          option(Icons.chat_rounded, const Color(0xFF25D366), 'WhatsApp', _shareViaWhatsApp),
          option(Icons.email_rounded, const Color(0xFF1A73E8), 'Mail', _shareViaMail),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // Opens one SMS composer addressed to every saved contact's phone
  // number, prefilled with the live-location link. Silently does nothing
  // if there are no saved contacts, or if no SMS app is available to
  // handle it (e.g. some tablets/emulators) — sharing itself has already
  // succeeded by this point, so this staying quiet on failure is
  // intentional.
  Future<void> _shareViaSms() async {
    final auth = context.read<AuthProvider>().currentUser;
    final contacts = auth?.emergencyContacts ?? [];
    final numbers = contacts.map((c) => c.phone.trim()).where((p) => p.isNotEmpty).join(',');
    if (numbers.isEmpty) return;

    final uri = Uri(scheme: 'sms', path: numbers, queryParameters: {'body': _shareMessageBody()});
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      // See doc comment above — deliberately silent.
    }
  }

  // Opens WhatsApp with the live-location message prefilled. WhatsApp's
  // own link scheme only supports one recipient at a time, so this opens
  // WhatsApp's contact picker instead of guessing which saved contact to
  // pick — the user then chooses who (or which group) to send it to.
  Future<void> _shareViaWhatsApp() async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_shareMessageBody())}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('WhatsApp is not installed on this device.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      // Deliberately silent — sharing itself has already succeeded.
    }
  }

  // Opens a mail composer addressed to every saved contact's email,
  // prefilled with the live-location link. Silently does nothing if no
  // saved contact has an email on file.
  Future<void> _shareViaMail() async {
    final auth = context.read<AuthProvider>().currentUser;
    final contacts = auth?.emergencyContacts ?? [];
    final emails = contacts.map((c) => c.email.trim()).where((e) => e.isNotEmpty).join(',');
    if (emails.isEmpty) return;

    final uri = Uri(
      scheme: 'mailto',
      path: emails,
      queryParameters: {'subject': 'My Live Location - SecureRide', 'body': _shareMessageBody()},
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      // See doc comment above — deliberately silent.
    }
  }

  Future<void> _shareViaApps() async {
    final locationProvider = context.read<LocationProvider>();
    final pos = locationProvider.currentPosition ?? locationProvider.positionOrDefault;
    final mapsLink = 'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
    final auth = context.read<AuthProvider>().currentUser;
    final name = auth?.fullName ?? 'I';
    await SharePlus.instance.share(ShareParams(
      text: "$name'm sharing my live location via SecureRide:\n$mapsLink",
      subject: 'My Live Location - SecureRide',
    ));
  }

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
              await context.read<AuthProvider>().addEmergencyContact(name: name, phone: phone, relation: 'Other');
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
    final contacts = context.watch<AuthProvider>().currentUser?.emergencyContacts ?? [];
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final border = isDark ? const Color(0xFF2D2D44) : const Color(0xFFE5E7EB);
    final pos = location.positionOrDefault;
    final now = DateTime.now();
    const avatarColors = [0xFF1A73E8, 0xFF22C55E, 0xFF7C3AED, 0xFFF59E0B, 0xFFEF4444];

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
                      location.isSharing ? 'Currently sharing your location' : 'Share with approved contacts',
                      style: TextStyle(fontSize: 12, color: ts),
                    ),
                  ],
                )),
                location.isEnabling
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Switch(
                  value: location.isSharing,
                  onChanged: _isStopping ? null : (v) => _toggleSharing(v),
                  activeThumbColor: const Color(0xFF22C55E),
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
            Row(children: [
              Expanded(child: Text('Sharing With (${contacts.length})',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tp))),
              TextButton.icon(
                onPressed: _shareViaApps,
                icon: const Icon(Icons.ios_share_rounded, size: 16, color: Color(0xFF1A73E8)),
                label: const Text('Share via...', style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 10),

            if (contacts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Icon(Icons.people_outline, color: ts, size: 28),
                  const SizedBox(height: 6),
                  Text('No contacts added yet', style: TextStyle(color: ts, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ]),
              )
            else
              ...contacts.asMap().entries.map((entry) {
                final c = entry.value;
                final color = Color(avatarColors[entry.key % avatarColors.length]);
                return Container(
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
                      backgroundColor: color.withValues(alpha: 0.1),
                      child: Text(
                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: TextStyle(fontWeight: FontWeight.w600, color: tp, fontSize: 13)),
                        Text(c.phone,
                            style: TextStyle(fontSize: 11, color: ts)),
                      ],
                    )),
                    // Quick call button
                    IconButton(
                      icon: const Icon(Icons.phone_rounded, color: Color(0xFF22C55E), size: 20),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Calling ${c.name}...'),
                          backgroundColor: const Color(0xFF22C55E),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          margin: const EdgeInsets.all(16),
                          duration: const Duration(seconds: 2),
                        ));
                      },
                    ),
                    // Remove — real contacts need a real way to be removed,
                    // right from where they're added.
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 20),
                      onPressed: () async {
                        final ok = await context.read<AuthProvider>().deleteEmergencyContact(c.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? '${c.name} removed' : 'Could not remove contact. Try again.'),
                          backgroundColor: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          margin: const EdgeInsets.all(16),
                        ));
                      },
                    ),
                  ]),
                );
              }),

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
            if (location.isSharing) ...[
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
                    'Started At: ${(location.sharingStartedAt ?? now).hour.toString().padLeft(2, '0')}:${(location.sharingStartedAt ?? now).minute.toString().padLeft(2, '0')} - ${(location.sharingStartedAt ?? now).day} ${_monthName((location.sharingStartedAt ?? now).month)} ${(location.sharingStartedAt ?? now).year}',
                    style: TextStyle(fontSize: 12, color: ts),
                  ),
                ]),
              ),
              const SizedBox(height: 10),

              // Stop Sharing
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isStopping ? null : () => _toggleSharing(false),
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
                  onPressed: location.isEnabling ? null : () => _toggleSharing(true),
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

  String _monthName(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];
}