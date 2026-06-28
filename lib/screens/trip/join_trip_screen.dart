import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/theme_provider.dart';
import '../home/home_screen.dart';
import '../../utils/app_icon_colors.dart';

class JoinTripScreen extends StatefulWidget {
  const JoinTripScreen({super.key});
  @override
  State<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends State<JoinTripScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _tripPreview;

  Future<void> _search() async {
    if (_codeCtrl.text.trim().isEmpty) return;
    setState(() { _isLoading = true; _tripPreview = null; });
    await Future.delayed(const Duration(milliseconds: 800));
    // Dummy trip preview (spec: Madurai → Chennai, Ramesh driver, Verified)
    setState(() {
      _isLoading = false;
      _tripPreview = {
        'code': _codeCtrl.text.trim().toUpperCase(),
        'from': 'Madurai',
        'to': 'Chennai',
        'date': '20 May 2025',
        'time': '10:00 AM',
        'driver': 'Ramesh',
        'isVerified': true,
        'vehicle': 'Sedan',
        'seats': '3 Seats',
        'fare': '₹250',
        'status': 'active',
      };
    });
  }

  Future<void> _join() async {
    if (_tripPreview == null) return;
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final result = await context.read<TripProvider>().joinTrip(
      tripCode: _codeCtrl.text.trim(),
      uid: auth.currentUser?.uid ?? '',
      email: auth.currentUser?.email ?? '',
      name: auth.currentUser?.fullName ?? '',
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 18), SizedBox(width: 8), Text('Joined trip successfully!')]),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16)));
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
    }
  }

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final border = isDark ? const Color(0xFF2D2D44) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
          title: const Text('Join Trip', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),

          // Code input
          Text('Enter Trip Code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(color: tp, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2),
              decoration: InputDecoration(
                  hintText: 'e.g. FCW001',
                  hintStyle: TextStyle(color: ts, letterSpacing: 1),
                  prefixIcon: const Icon(Icons.vpn_key_rounded, color: Color(0xFF1A73E8), size: 20),
                  filled: true, fillColor: card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
            )),
            const SizedBox(width: 10),
            ElevatedButton(
                onPressed: _isLoading ? null : _search,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), elevation: 0),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Search', style: TextStyle(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 24),

          // Trip Preview (spec: Driver name, Verified badge, Details)
          if (_tripPreview != null) ...[
            Text('Trip Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tp)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
              child: Column(children: [
                // Driver info with verified badge (spec requirement)
                Row(children: [
                  CircleAvatar(radius: 22, backgroundColor: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                      child: Text(_tripPreview!['driver'][0], style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_tripPreview!['driver'], style: TextStyle(fontWeight: FontWeight.bold, color: tp)),
                    if (_tripPreview!['isVerified'])
                      Row(children: [
                        const Icon(Icons.verified_rounded, color: Color(0xFF1A73E8), size: 14),
                        const SizedBox(width: 3),
                        const Text('Verified Driver', style: TextStyle(color: Color(0xFF1A73E8), fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                  ]),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Active', style: TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.bold))),
                ]),
                const Divider(height: 20),

                // Route
                Row(children: [
                  const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF1A73E8), size: 14),
                  const SizedBox(width: 6),
                  Text(_tripPreview!['from'], style: TextStyle(color: tp, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, color: appIconColor(Icons.arrow_forward_rounded), size: 14),
                  const SizedBox(width: 6),
                  Text(_tripPreview!['to'], style: TextStyle(color: tp, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 10),

                // Details row
                Row(children: [
                  _detail(Icons.calendar_today_outlined, _tripPreview!['date'], ts),
                  const SizedBox(width: 12),
                  _detail(Icons.access_time_rounded, _tripPreview!['time'], ts),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  _detail(Icons.directions_car_outlined, _tripPreview!['vehicle'], ts),
                  const SizedBox(width: 12),
                  _detail(Icons.people_outline_rounded, _tripPreview!['seats'], ts),
                  const SizedBox(width: 12),
                  _detail(Icons.currency_rupee_rounded, _tripPreview!['fare'], const Color(0xFF22C55E)),
                ]),
                const SizedBox(height: 16),

                // Join button (spec: "Join Trip")
                SizedBox(width: double.infinity, height: 48,
                    child: ElevatedButton(
                        onPressed: _isLoading ? null : _join,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        child: const Text('Join Trip', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
              ]),
            ),
          ],

          if (_tripPreview == null && !_isLoading) ...[
            const SizedBox(height: 40),
            Center(child: Column(children: [
              Icon(Icons.vpn_key_outlined, size: 64, color: appIconColor(Icons.vpn_key_outlined)),
              const SizedBox(height: 12),
              Text('Enter a trip code to search', style: TextStyle(color: ts, fontSize: 14)),
            ])),
          ],
        ]),
      ),
    );
  }

  Widget _detail(IconData icon, String text, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: color), const SizedBox(width: 3),
    Text(text, style: TextStyle(fontSize: 11, color: color)),
  ]);
}