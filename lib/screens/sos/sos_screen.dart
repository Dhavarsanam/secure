import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/emergency_contact_model.dart';
import '../../core/services/sos_service.dart';
import '../contacts/approved_contacts_screen.dart';
import '../../utils/app_icon_colors.dart';

const _kDanger = Color(0xFFDC2626);
const _kSuccess = Color(0xFF22C55E);
const _kPrimary = Color(0xFF1A73E8);

Color _relationColor(String r) {
  switch (r) {
    case 'Family': return _kDanger;
    case 'Friend': return const Color(0xFF7C3AED);
    default: return const Color(0xFF64748B);
  }
}

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final SosService _sosService = SosService();

  bool _isSosActive = false;
  bool _isTriggering = false;
  DateTime? _sosStartedAt;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Fetch the real live location as soon as the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // Place the call: true auto-call on Android (CALL_PHONE), else open dialer.
  Future<void> _callNumber(String rawPhone) async {
    final messenger = ScaffoldMessenger.of(context);
    final digits = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.length < 6) {
      messenger.showSnackBar(const SnackBar(content: Text('No valid number for this contact. Please update it.')));
      return;
    }
    // 1. Try direct auto-call on Android with CALL_PHONE permission
    try {
      final status = await Permission.phone.request();
      if (status.isGranted) {
        final placed = await FlutterPhoneDirectCaller.callNumber(digits);
        if (placed == true) return;
      }
    } catch (_) {/* fall through to dialer */}
    // 2. Fallback: open the dialer on iOS / web / permission denied
    try {
      final ok = await launchUrl(Uri.parse('tel:$digits'));
      if (!ok && mounted) messenger.showSnackBar(const SnackBar(content: Text('Could not place the call')));
    } catch (_) {
      if (mounted) messenger.showSnackBar(const SnackBar(content: Text('Could not place the call')));
    }
  }

  Future<void> _triggerSos() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final contacts = user?.emergencyContacts ?? [];
    if (user == null || contacts.isEmpty) {
      showDialog(context: context, builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('No Contacts!'),
        content: const Text('Add emergency contacts first to use SOS.'),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
            child: const Text('OK'))],
      ));
      return;
    }
    final ok = await showDialog<bool>(context: context, barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: _kDanger, size: 28), SizedBox(width: 8),
            Text('Send SOS Alert?', style: TextStyle(color: _kDanger))]),
          content: const Text('This will alert all your emergency contacts with your live location and start calling your primary contact.', style: TextStyle(height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: _kDanger, foregroundColor: Colors.white),
                child: const Text('Send SOS Now')),
          ],
        ));
    if (ok != true) return;

    setState(() => _isTriggering = true);

    final result = await _sosService.triggerSos(
      senderUid: user.uid,
      senderName: user.fullName,
      senderEmail: user.email,
      senderPhone: user.phoneNumber,
      approvedContacts: user.approvedContacts,
    );

    if (!mounted) return;
    setState(() => _isTriggering = false);

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not send SOS: ${result['error'] ?? 'Unknown error'}'),
          backgroundColor: _kDanger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16)));
      return;
    }

    setState(() {
      _isSosActive = true;
      _sosStartedAt = DateTime.now();
      _elapsed = Duration.zero;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _sosStartedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(_sosStartedAt!));
    });

    // Share via SMS to every emergency contact's phone number, reusing the
    // exact position triggerSos() already fetched (no second location call).
    final phoneNumbers = contacts.map((c) => c.phone).where((p) => p.isNotEmpty).toList();
    final smsOpened = await _sosService.shareSosViaSms(
      phoneNumbers: phoneNumbers,
      senderName: user.fullName,
      senderPhone: user.phoneNumber,
      lat: (result['lat'] as num).toDouble(),
      lng: (result['lng'] as num).toDouble(),
      address: result['address'] as String?,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(smsOpened
            ? '🚨 SOS Alert Sent! Opening SMS to your contacts...'
            : '🚨 SOS Alert saved, but could not open the SMS app.'),
        backgroundColor: _kDanger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16), duration: const Duration(seconds: 4)));

    // Auto-call the primary (first) emergency contact
    final primary = contacts.first;
    await _callNumber(primary.phone);

    // Refresh the on-screen live location too
    context.read<LocationProvider>().getCurrentLocation();
  }

  Future<void> _cancelSos() async {
    final ok = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cancel SOS?'),
          content: const Text('Are you safe? This will stop all emergency alerts.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, Keep Active')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: _kSuccess, foregroundColor: Colors.white),
                child: const Text("Yes, I'm Safe")),
          ],
        ));
    if (ok == true && mounted) {
      await _sosService.cancelSos();
      _ticker?.cancel();
      setState(() { _isSosActive = false; _sosStartedAt = null; _elapsed = Duration.zero; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ SOS Cancelled. Stay safe!'),
          backgroundColor: _kSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16)));
    }
  }

  void _showNeedHelp(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    showDialog(context: context, builder: (dctx) => AlertDialog(
      backgroundColor: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Need Help?', style: TextStyle(color: tp, fontSize: 18, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('If you\'re in immediate danger, press the SOS button. For anything else, reach us anytime:', style: TextStyle(color: ts, fontSize: 13, height: 1.4)),
        const SizedBox(height: 14),
        Row(children: [Icon(Icons.email_outlined, size: 18, color: _kPrimary), const SizedBox(width: 10),
          Text('Email: ', style: TextStyle(color: ts, fontSize: 13)),
          Expanded(child: Text('support@secureride.com', style: TextStyle(color: tp, fontSize: 13, fontWeight: FontWeight.w600)))]),
        const SizedBox(height: 8),
        Row(children: [Icon(Icons.call_outlined, size: 18, color: _kPrimary), const SizedBox(width: 10),
          Text('Helpline: ', style: TextStyle(color: ts, fontSize: 13)),
          Expanded(child: Text('+91 98765 43210', style: TextStyle(color: tp, fontSize: 13, fontWeight: FontWeight.w600)))]),
        const SizedBox(height: 8),
        Row(children: [Icon(Icons.access_time, size: 18, color: _kPrimary), const SizedBox(width: 10),
          Text('Hours: ', style: TextStyle(color: ts, fontSize: 13)),
          Expanded(child: Text('Mon–Sat, 9 AM – 8 PM', style: TextStyle(color: tp, fontSize: 13, fontWeight: FontWeight.w600)))]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Close', style: TextStyle(color: _kPrimary))),
        ElevatedButton.icon(
          onPressed: () { Navigator.pop(dctx); _callNumber('+919876543210'); },
          icon: const Icon(Icons.call, color: Colors.white, size: 16),
          label: const Text('Call Helpline'),
          style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
        ),
      ],
    ));
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final location = context.watch<LocationProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final contacts = auth.currentUser?.emergencyContacts ?? [];
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    // Real backend cadence: SosService sends the first location update at
    // trigger time, then one every 2 minutes after that while active.
    final updatesSent = _isSosActive ? 1 + (_elapsed.inMinutes ~/ 2) : 0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: _kDanger,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Emergency SOS', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isSosActive)
            Container(margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: const Row(children: [
                  Icon(Icons.circle, color: Colors.white, size: 8),
                  SizedBox(width: 4),
                  Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ]))
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: () => _showNeedHelp(context),
                icon: const Icon(Icons.call_outlined, size: 14, color: Colors.white),
                label: const Text('Need Help?', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const SizedBox(height: 16),

          // SOS Button — one circular button (call icon + "SOS" label),
          // with a pulsing ring while an alert is active. Sits on a dark,
          // red-tinted hero background (matches the reference design),
          // regardless of the app's light/dark mode setting.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  _kDanger.withValues(alpha: 0.22),
                  const Color(0xFF0B0B12),
                ],
              ),
            ),
            child: _SosCircleButton(
              isActive: _isSosActive,
              isLoading: _isTriggering,
              onTap: (_isTriggering || _isSosActive) ? null : _triggerSos,
            ),
          ),

          const SizedBox(height: 12),
          Text(
              _isSosActive ? '🚨 Emergency alert sent!\nContacts are being notified.' : 'Press the button in case of emergency',
              style: TextStyle(fontSize: 14, color: _isSosActive ? _kDanger : ts,
                  fontWeight: _isSosActive ? FontWeight.w600 : FontWeight.normal, height: 1.5),
              textAlign: TextAlign.center),

          if (_isSosActive) ...[
            const SizedBox(height: 6),
            Text('Active for ${_formatElapsed(_elapsed)} · Location updates sent: $updatesSent',
                style: const TextStyle(fontSize: 12, color: _kDanger)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                    onPressed: _cancelSos,
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text("I'm Safe — Cancel SOS"),
                    style: ElevatedButton.styleFrom(backgroundColor: _kSuccess, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
          ],

          const SizedBox(height: 28),

          // ---- Emergency Contacts (each tappable to call) ----
          Row(children: [
            const Icon(Icons.people_rounded, color: _kPrimary, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text('Emergency Contacts', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 14))),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApprovedContactsScreen())),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Manage', style: TextStyle(color: _kDanger, fontWeight: FontWeight.w600, fontSize: 13)),
                Icon(Icons.chevron_right_rounded, color: _kDanger, size: 18),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          if (contacts.isEmpty)
            Container(width: double.infinity, padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('No emergency contacts added yet!', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Tap Manage above to add someone we can call and alert.', style: TextStyle(color: ts, fontSize: 12)),
                ]))
          else
            ...contacts.map((c) => _ContactRow(contact: c, card: card, tp: tp, ts: ts, onCall: () => _callNumber(c.phone))),

          const SizedBox(height: 12),

          // Current Location — real GPS + reverse-geocoded address + mini live map
          _LiveLocationCard(location: location, card: card, tp: tp, ts: ts),

          const SizedBox(height: 24),

          // How SOS Works
          Row(children: [
            const Icon(Icons.info_outline, color: _kDanger, size: 18),
            const SizedBox(width: 8),
            Text('How SOS Works', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 14)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _HowItWorksItem(icon: Icons.call_rounded, color: _kDanger,
                title: 'Instant Call', desc: 'Calls your primary contact instantly', tp: tp, ts: ts)),
            Expanded(child: _HowItWorksItem(icon: Icons.location_on_rounded, color: const Color(0xFF7C3AED),
                title: 'Share Location', desc: 'Shares your live location', tp: tp, ts: ts)),
            Expanded(child: _HowItWorksItem(icon: Icons.notifications_active_rounded, color: const Color(0xFFF59E0B),
                title: 'Alert Contacts', desc: 'Sends alert with safety details', tp: tp, ts: ts)),
            Expanded(child: _HowItWorksItem(icon: Icons.verified_user_rounded, color: _kSuccess,
                title: 'Stay Protected', desc: "We stay alert until help arrives", tp: tp, ts: ts)),
          ]),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _kDanger.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16), border: Border.all(color: _kDanger.withValues(alpha: 0.2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.shield_outlined, color: _kDanger, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(
                  "Your alert will be sent to your emergency contacts immediately. We'll keep monitoring and keep you protected.",
                  style: TextStyle(fontSize: 12.5, color: ts, height: 1.5))),
            ]),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// The main SOS button — a single circle with a call icon + "SOS" label.
// Shows a spinner mid-trigger, and a slow pulsing outer ring once an
// alert is active (button itself disabled while active — cancel via the
// "I'm Safe" button instead).
class _SosCircleButton extends StatefulWidget {
  final bool isActive;
  final bool isLoading;
  final VoidCallback? onTap;
  const _SosCircleButton({required this.isActive, required this.isLoading, required this.onTap});

  @override
  State<_SosCircleButton> createState() => _SosCircleButtonState();
}

class _SosCircleButtonState extends State<_SosCircleButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(alignment: Alignment.center, children: [
          // Outer ring — pulses outward continuously while active, static otherwise
          if (widget.isActive)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final t = _pulse.value;
                return Container(
                  width: 190 + t * 50,
                  height: 190 + t * 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kDanger.withValues(alpha: (1 - t) * 0.55), width: 2),
                  ),
                );
              },
            )
          else
            Container(
              width: 216,
              height: 216,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _kDanger.withValues(alpha: 0.25), width: 2)),
            ),
          // Main filled circle
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [Color(0xFFF87171), _kDanger], radius: 0.9),
              boxShadow: [BoxShadow(color: _kDanger.withValues(alpha: 0.45), blurRadius: 30, spreadRadius: 6)],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.call_rounded, color: Colors.white, size: 40),
                SizedBox(height: 6),
                Text('SOS', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// One column in the "How SOS Works" 4-item row: a tinted circular icon
// plus a short bold title and a small description underneath.
class _HowItWorksItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, desc;
  final Color tp, ts;
  const _HowItWorksItem({required this.icon, required this.color, required this.title, required this.desc, required this.tp, required this.ts});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, maxLines: 1,
            style: TextStyle(color: tp, fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(height: 3),
        Text(desc, textAlign: TextAlign.center, maxLines: 3,
            style: TextStyle(color: ts, fontSize: 9.5, height: 1.25)),
      ]),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final EmergencyContact contact;
  final Color card, tp, ts;
  final VoidCallback onCall;
  const _ContactRow({required this.contact, required this.card, required this.tp, required this.ts, required this.onCall});
  @override
  Widget build(BuildContext context) {
    final rc = _relationColor(contact.relation);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
      child: Row(children: [
        CircleAvatar(radius: 20, backgroundColor: rc.withValues(alpha: 0.12),
            child: Text(contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                style: TextStyle(color: rc, fontWeight: FontWeight.bold))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(contact.name, style: TextStyle(color: tp, fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: rc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(contact.relation, style: TextStyle(color: rc, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
          Text(contact.phone.isEmpty ? 'No number' : contact.phone, style: TextStyle(color: ts, fontSize: 12)),
        ])),
        GestureDetector(
          onTap: onCall,
          child: Container(width: 42, height: 42,
              decoration: BoxDecoration(color: _kSuccess, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _kSuccess.withValues(alpha: 0.4), blurRadius: 8)]),
              child: const Icon(Icons.call_rounded, color: Colors.white, size: 20)),
        ),
      ]),
    );
  }
}

// Live location card: shows the real reverse-geocoded address plus a
// small live OpenStreetMap preview centered on the real GPS fix, with a
// working Refresh button — no placeholder text or fixed coordinates.
class _LiveLocationCard extends StatelessWidget {
  final LocationProvider location;
  final Color card, tp, ts;
  const _LiveLocationCard({required this.location, required this.card, required this.tp, required this.ts});

  @override
  Widget build(BuildContext context) {
    final pos = location.currentPosition;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.location_on, color: appIconColor(Icons.location_on), size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text('Current Location', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 14))),
          GestureDetector(
            onTap: location.isLoading ? null : () => location.getCurrentLocation(),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (location.isLoading)
                const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: _kDanger))
              else
                const Icon(Icons.refresh_rounded, color: _kDanger, size: 16),
              const SizedBox(width: 4),
              const Text('Refresh', style: TextStyle(color: _kDanger, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          location.isLoading && pos == null
              ? 'Fetching your live location…'
              : (location.currentAddress ?? (pos != null
              ? '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'
              : (location.lastError ?? 'Location unavailable. Tap Refresh to try again.'))),
          style: TextStyle(color: ts, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 150,
            child: pos == null
                ? Container(
              color: ts.withValues(alpha: 0.08),
              alignment: Alignment.center,
              child: location.isLoading
                  ? const CircularProgressIndicator(strokeWidth: 2.5, color: _kDanger)
                  : Text('Location not available', style: TextStyle(color: ts, fontSize: 12)),
            )
                : FlutterMap(
              options: MapOptions(initialCenter: pos, initialZoom: 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.secureride.app',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: pos, width: 40, height: 40,
                    child: Container(
                      decoration: BoxDecoration(color: _kDanger, shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: _kDanger.withValues(alpha: 0.45), blurRadius: 10)]),
                      child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}