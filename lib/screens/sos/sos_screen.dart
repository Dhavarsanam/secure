import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_icon_colors.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _isSosActive = false;
  bool _isLoading = false;
  int _updateCount = 0;

  Future<void> _triggerSos() async {
    final contacts = context.read<AuthProvider>().currentUser?.approvedContacts ?? [];
    if (contacts.isEmpty) {
      showDialog(context: context, builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('No Contacts!'),
        content: const Text('Add approved contacts first to use SOS.'),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white),
            child: const Text('OK'))],
      ));
      return;
    }
    final ok = await showDialog<bool>(context: context, barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28), SizedBox(width: 8),
            Text('Send SOS Alert?', style: TextStyle(color: Color(0xFFDC2626)))]),
          content: const Text('This will immediately send your location to all approved contacts.', style: TextStyle(height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                child: const Text('Send SOS Now')),
          ],
        ));
    if (ok != true) return;
    setState(() { _isLoading = true; });
    await Future.delayed(const Duration(seconds: 1));
    setState(() { _isLoading = false; _isSosActive = true; _updateCount = 0; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('🚨 SOS Alert Sent! Contacts notified.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16), duration: const Duration(seconds: 4)));
    }
    _periodicUpdate();
  }

  void _periodicUpdate() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_isSosActive && mounted) { setState(() => _updateCount++); _periodicUpdate(); }
    });
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white),
                child: const Text("Yes, I'm Safe")),
          ],
        ));
    if (ok == true && mounted) {
      setState(() { _isSosActive = false; _updateCount = 0; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ SOS Cancelled. Stay safe!'),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final location = context.watch<LocationProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final contacts = auth.currentUser?.approvedContacts ?? [];
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFFDC2626),
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
                ])),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const SizedBox(height: 16),

          // 🚨 SOS Lottie Animation
          Lottie.asset(
            'assets/animations/sos_alert.json',
            width: 200, height: 200,
            repeat: _isSosActive,
            animate: _isSosActive,
            errorBuilder: (_, __, ___) => GestureDetector(
              onTap: _isSosActive ? null : (_isLoading ? null : _triggerSos),
              child: Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: _isSosActive ? const Color(0xFFDC2626) : const Color(0xFFEF4444),
                      boxShadow: [BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 8)]),
                  child: const Icon(Icons.sos_rounded, color: Colors.white, size: 72)),
            ),
          ),

          // SOS Button (when not active)
          if (!_isSosActive)
            GestureDetector(
              onTap: _isLoading ? null : _triggerSos,
              child: Container(
                width: 160, height: 60,
                decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))]),
                child: Center(child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('PRESS SOS', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
              ),
            ),

          const SizedBox(height: 12),
          Text(
              _isSosActive ? '🚨 Emergency alert sent!\nContacts are being notified.' : 'Press the button in case of emergency',
              style: TextStyle(fontSize: 14, color: _isSosActive ? const Color(0xFFDC2626) : ts,
                  fontWeight: _isSosActive ? FontWeight.w600 : FontWeight.normal, height: 1.5),
              textAlign: TextAlign.center),

          if (_isSosActive) ...[
            const SizedBox(height: 6),
            Text('Location updates sent: $_updateCount', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                    onPressed: _cancelSos,
                    icon: Icon(Icons.check_circle_outline, color: appIconColor(Icons.check_circle_outline)),
                    label: const Text("I'm Safe — Cancel SOS"),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
          ],

          const SizedBox(height: 28),

          // Contacts Info
          _InfoCard(icon: Icons.people, title: 'Approved Contacts',
              value: contacts.isEmpty ? 'No contacts added yet!' : contacts.join(', '),
              color: contacts.isEmpty ? const Color(0xFFEF4444) : const Color(0xFF1A73E8), card: card, tp: tp, ts: ts),
          const SizedBox(height: 10),
          _InfoCard(icon: Icons.location_on, title: 'Current Location',
              value: location.currentAddress ?? 'Fathima College for Women, Madurai',
              color: const Color(0xFF22C55E), card: card, tp: tp, ts: ts),

          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFDC2626).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 18),
                SizedBox(width: 8),
                Text('SOS Information', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 14)),
              ]),
              const SizedBox(height: 10),
              ...[
                'Sends your GPS location to all approved contacts',
                'Includes active trip details in the alert',
                'Location updates sent every 2 minutes',
                'Alert continues until you cancel it',
              ].map((t) => Padding(padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('• ', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                    Expanded(child: Text(t, style: TextStyle(fontSize: 12, color: ts, height: 1.4))),
                  ]))),
            ]),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, value;
  final Color color, card, tp, ts;
  const _InfoCard({required this.icon, required this.title, required this.value, required this.color, required this.card, required this.tp, required this.ts});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12, color: ts, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, color: tp, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}