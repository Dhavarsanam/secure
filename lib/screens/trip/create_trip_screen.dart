import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/theme_provider.dart';
import '../home/home_screen.dart';
import '../../utils/app_icon_colors.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});
  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromCtrl = TextEditingController(text: 'Fathima College for Women, Madurai');
  final _toCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  String _vehicleType = 'Sedan';
  int _seats = 3;
  double _farePerSeat = 250;
  bool _isLoading = false;

  // Spec: SUV, Sedan, Van vehicle icons
  final List<Map<String, dynamic>> _vehicles = [
    {'name': 'Bike', 'icon': Icons.two_wheeler_rounded},
    {'name': 'Sedan', 'icon': Icons.directions_car_rounded},
    {'name': 'SUV', 'icon': Icons.directions_car_filled_rounded},
    {'name': 'Van', 'icon': Icons.airport_shuttle_rounded},
    {'name': 'Auto', 'icon': Icons.electric_rickshaw_rounded},
    {'name': 'Bus', 'icon': Icons.directions_bus_rounded},
  ];

  @override
  void dispose() { _fromCtrl.dispose(); _toCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final result = await context.read<TripProvider>().createTrip(
      creatorUid: auth.currentUser?.uid ?? '',
      creatorName: auth.currentUser?.fullName ?? '',
      creatorEmail: auth.currentUser?.email ?? '',
      startLocationName: _fromCtrl.text.trim(),
      startLat: 9.9601, startLng: 78.0766,
      destinationName: _toCtrl.text.trim(),
      destinationLat: 9.9252, destinationLng: 78.1198,
      travelDate: DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute),
      passengerType: 'Women Only',
      vehicleType: _vehicleType,
      availableSeats: _seats,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result['success']) {
      final code = result['tripCode'];
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 26), SizedBox(width: 8), Text('Trip Created!')]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Share this code with passengers:'),
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8), letterSpacing: 4))),
            ]),
            actions: [ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Go to Dashboard'))],
          ));
    }
  }

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
          title: const Text('Create Trip', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          _section('Route Details', tp),

          // From field
          _label('From', ts),
          TextFormField(controller: _fromCtrl, style: TextStyle(color: tp, fontSize: 14),
              decoration: _deco('From location', Icons.radio_button_checked_rounded, const Color(0xFF1A73E8), card, border),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),

          // To field
          _label('To', ts),
          TextFormField(controller: _toCtrl, style: TextStyle(color: tp, fontSize: 14),
              decoration: _deco('Destination', Icons.location_on_rounded, const Color(0xFFEF4444), card, border),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 20),

          _section('Travel Details', tp),

          // Date picker
          _label('Date', ts),
          GestureDetector(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date,
                    firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                if (d != null) setState(() => _date = d);
              },
              child: Container(padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded, color: Color(0xFF1A73E8), size: 20),
                    const SizedBox(width: 10),
                    Text('${_date.day} ${_monthName(_date.month)} ${_date.year}', style: TextStyle(color: tp, fontSize: 14)),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, color: ts),
                  ]))),
          const SizedBox(height: 12),

          // Time picker
          _label('Time', ts),
          GestureDetector(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _time);
                if (t != null) setState(() => _time = t);
              },
              child: Container(padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
                  child: Row(children: [
                    const Icon(Icons.access_time_rounded, color: Color(0xFF1A73E8), size: 20),
                    const SizedBox(width: 10),
                    Text(_time.format(context), style: TextStyle(color: tp, fontSize: 14)),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, color: ts),
                  ]))),
          const SizedBox(height: 20),

          _section('Vehicle Type', tp),
          // Spec: SUV 🚙, Sedan 🚗, Van 🚐 icons
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.6,
              children: _vehicles.map((v) {
                final sel = _vehicleType == v['name'];
                return GestureDetector(
                    onTap: () => setState(() => _vehicleType = v['name'] as String),
                    child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                            color: sel ? const Color(0xFF1A73E8) : card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: sel ? const Color(0xFF1A73E8) : border, width: sel ? 2 : 1)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(v['icon'] as IconData, color: sel ? Colors.white : const Color(0xFF1A73E8), size: 24),
                          const SizedBox(height: 4),
                          Text(v['name'] as String, style: TextStyle(color: sel ? Colors.white : tp, fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                        ])));
              }).toList()),
          const SizedBox(height: 20),

          _section('Seats & Fare', tp),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Available Seats', ts),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
                  child: Row(children: [
                    IconButton(icon: Icon(Icons.remove_rounded, size: 18, color: appIconColor(Icons.remove_rounded)), color: const Color(0xFF1A73E8),
                        onPressed: () => setState(() => _seats = (_seats - 1).clamp(1, 10))),
                    Expanded(child: Text('$_seats', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tp))),
                    IconButton(icon: Icon(Icons.add_rounded, size: 18, color: appIconColor(Icons.add_rounded)), color: const Color(0xFF1A73E8),
                        onPressed: () => setState(() => _seats = (_seats + 1).clamp(1, 10))),
                  ])),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Fare per seat (₹)', ts),
              TextFormField(
                initialValue: _farePerSeat.toStringAsFixed(0),
                keyboardType: TextInputType.number,
                style: TextStyle(color: tp, fontSize: 14),
                decoration: _deco('₹ Amount', Icons.currency_rupee_rounded, const Color(0xFF22C55E), card, border),
                onChanged: (v) => _farePerSeat = double.tryParse(v) ?? 250,
              ),
            ])),
          ]),
          const SizedBox(height: 28),

          // Verified Driver badge (spec requirement)
          Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.2))),
              child: Row(children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF22C55E), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Verified Driver — trips are safe & trusted',
                    style: TextStyle(fontSize: 12, color: ts))),
              ])),
          const SizedBox(height: 20),

          // Continue button (spec shows "Continue")
          SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
          const SizedBox(height: 20),
        ])),
      ),
    );
  }

  Widget _section(String title, Color tp) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tp)));

  Widget _label(String text, Color ts) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 12, color: ts, fontWeight: FontWeight.w500)));

  InputDecoration _deco(String hint, IconData icon, Color iconColor, Color card, Color border) => InputDecoration(
      hintText: hint, prefixIcon: Icon(icon, color: iconColor, size: 18),
      filled: true, fillColor: card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));

  String _monthName(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];
}