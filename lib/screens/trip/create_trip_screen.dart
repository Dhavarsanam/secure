import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/constants/madurai_places.dart';
import '../../core/constants/tn_districts.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/helpers.dart';
import '../home/home_screen.dart';
import '../../utils/app_icon_colors.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});
  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

// One combined suggestion type so a Madurai locality and a TN district
// headquarters town can sit side by side in the same suggestions list.
class _PlaceSuggestion {
  final String name;
  final double lat;
  final double lng;
  final String subtitle; // 'Madurai' for city localities, or the district name for districts
  const _PlaceSuggestion({required this.name, required this.lat, required this.lng, required this.subtitle});
}

// Local, offline lookup — no network call. Merges the closest Madurai
// locality matches with the closest TN district matches so typing e.g.
// "Din" surfaces both a Madurai area (if any) and "Dindigul" together.
List<_PlaceSuggestion> _searchPlaces(String query) {
  final maduraiMatches = searchMaduraiPlaces(query, limit: 3)
      .map((p) => _PlaceSuggestion(name: p.name, lat: p.lat, lng: p.lng, subtitle: 'Madurai'));
  final districtMatches = searchTnDistricts(query, limit: 3)
      .map((d) => _PlaceSuggestion(name: d.name, lat: d.lat, lng: d.lng, subtitle: d.district));
  return [...maduraiMatches, ...districtMatches];
}

// Maximum seats allowed per vehicle type — the seat counter is clamped
// to this so the app never lets someone pick more seats than the
// vehicle can actually hold.
int maxSeatsForVehicle(String vehicleType) {
  switch (vehicleType) {
    case 'Car': return 4;
    case 'Bike': return 1;
    case 'Auto': return 3;
    case 'Van': return 8;
    case 'Bus': return 25;
    default: return 4;
  }
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _startCtrl = TextEditingController();
  final _destCtrl = TextEditingController();

  double? _startLat, _startLng;
  double? _destLat, _destLng;

  List<_PlaceSuggestion> _startSuggestions = [];
  List<_PlaceSuggestion> _destSuggestions = [];

  DateTime? _travelDate;
  String _passengerType = AppStrings.passengerTypes.first;
  String _vehicleType = AppStrings.vehicleTypes.first;
  // Starts at 0 — the user has to actively add seats with the + button
  // rather than a default already being picked for them.
  int _seats = 0;
  bool _isCreating = false;

  @override
  void dispose() {
    _startCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  void _onStartChanged(String q) {
    setState(() {
      _startLat = null;
      _startLng = null;
      _startSuggestions = _searchPlaces(q);
    });
  }

  void _onDestChanged(String q) {
    setState(() {
      _destLat = null;
      _destLng = null;
      _destSuggestions = _searchPlaces(q);
    });
  }

  void _pickStart(_PlaceSuggestion p) {
    setState(() {
      _startCtrl.text = p.name;
      _startLat = p.lat; _startLng = p.lng;
      _startSuggestions = [];
    });
    FocusScope.of(context).unfocus();
  }

  void _pickDest(_PlaceSuggestion p) {
    setState(() {
      _destCtrl.text = p.name;
      _destLat = p.lat; _destLng = p.lng;
      _destSuggestions = [];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _travelDate ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_travelDate ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() {
      _travelDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _create() async {
    if (_startLat == null || _startLng == null) {
      _showError('Pick a start location from the suggestions.');
      return;
    }
    if (_destLat == null || _destLng == null) {
      _showError('Pick a destination from the suggestions.');
      return;
    }
    if (_travelDate == null) {
      _showError('Choose a travel date and time.');
      return;
    }
    if (_travelDate!.isBefore(DateTime.now())) {
      _showError('Travel date and time must be in the future.');
      return;
    }
    if (_seats <= 0) {
      _showError('Add at least 1 available seat.');
      return;
    }

    setState(() => _isCreating = true);
    final auth = context.read<AuthProvider>();
    final result = await context.read<TripProvider>().createTrip(
      creatorUid: auth.currentUser?.uid ?? '',
      creatorName: auth.currentUser?.fullName ?? '',
      creatorEmail: auth.currentUser?.email ?? '',
      startLocationName: _startCtrl.text.trim(),
      startLat: _startLat!, startLng: _startLng!,
      destinationName: _destCtrl.text.trim(),
      destinationLat: _destLat!, destinationLng: _destLng!,
      travelDate: _travelDate!,
      passengerType: _passengerType,
      vehicleType: _vehicleType,
      availableSeats: _seats,
    );
    if (!mounted) return;
    setState(() => _isCreating = false);

    if (result['success'] == true) {
      _showSuccessDialog(result['tripCode'] as String);
    } else {
      _showError(result['error']?.toString() ?? 'Could not create trip. Try again.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16)));
  }

  void _showSuccessDialog(String code) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dctx) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 26),
          const SizedBox(width: 8),
          Text('Trip Created!', style: TextStyle(color: tp, fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Share this code so others can join your trip:', style: TextStyle(color: ts, fontSize: 13)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(dctx).showSnackBar(SnackBar(
                  content: const Text('Trip code copied!'),
                  backgroundColor: const Color(0xFF1A73E8),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2)));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3))),
              child: Column(children: [
                Text(code, style: const TextStyle(color: Color(0xFF1A73E8), fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 3)),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.copy_rounded, size: 13, color: appIconColor(Icons.copy_rounded)),
                  const SizedBox(width: 4),
                  Text('Tap to copy', style: TextStyle(color: ts, fontSize: 11)),
                ]),
              ]),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dctx);
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
            },
            child: const Text('Done', style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _suggestionsList(List<_PlaceSuggestion> list, void Function(_PlaceSuggestion) onPick, Color card, Color tp, Color ts) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: list.map((p) => ListTile(
          dense: true,
          leading: Icon(
              p.subtitle == 'Madurai' ? Icons.location_on_outlined : Icons.map_outlined,
              size: 18, color: appIconColor(Icons.location_on_outlined)),
          title: Text(p.name, style: TextStyle(color: tp, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(p.subtitle == 'Madurai' ? 'Madurai' : '${p.subtitle} District',
              style: TextStyle(color: ts, fontSize: 11)),
          onTap: () => onPick(p),
        )).toList(),
      ),
    );
  }

  String _formatDateTime(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hour12:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final border = isDark ? const Color(0xFF2D2D44) : const Color(0xFFE5E7EB);

    InputDecoration fieldDecoration({required String hint, required IconData icon, Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: ts, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF1A73E8), size: 20),
        suffixIcon: suffix,
        filled: true, fillColor: card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 14));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
          title: const Text('Create Trip', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Start location
          Text('Start Location', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 10),
          TextField(
            controller: _startCtrl,
            style: TextStyle(color: tp, fontSize: 14),
            onChanged: _onStartChanged,
            decoration: fieldDecoration(
              hint: 'Search start location',
              icon: Icons.radio_button_checked_rounded,
            ),
          ),
          _suggestionsList(_startSuggestions, _pickStart, card, tp, ts),
          const SizedBox(height: 16),

          // Destination
          Text('Destination', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 10),
          TextField(
            controller: _destCtrl,
            style: TextStyle(color: tp, fontSize: 14),
            onChanged: _onDestChanged,
            decoration: fieldDecoration(
              hint: 'Search destination',
              icon: Icons.location_on_rounded,
            ),
          ),
          _suggestionsList(_destSuggestions, _pickDest, card, tp, ts),
          const SizedBox(height: 16),

          // Travel date & time
          Text('Travel Date & Time', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickDateTime,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, color: Color(0xFF1A73E8), size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_travelDate == null ? 'Select date & time' : _formatDateTime(_travelDate!),
                    style: TextStyle(color: _travelDate == null ? ts : tp, fontSize: 14, fontWeight: FontWeight.w500))),
                Icon(Icons.chevron_right_rounded, color: ts, size: 20),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Passenger type
          Text('Passenger Type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: AppStrings.passengerTypes.map((type) {
            final selected = _passengerType == type;
            return GestureDetector(
              onTap: () => setState(() => _passengerType = type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: selected ? const Color(0xFF1A73E8) : card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? const Color(0xFF1A73E8) : border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Helpers.getPassengerIcon(type), size: 15, color: selected ? Colors.white : ts),
                  const SizedBox(width: 6),
                  Text(type, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : tp)),
                ]),
              ),
            );
          }).toList()),
          const SizedBox(height: 16),

          // Vehicle type
          Text('Vehicle Type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: AppStrings.vehicleTypes.map((type) {
            final selected = _vehicleType == type;
            return GestureDetector(
              onTap: () => setState(() {
                _vehicleType = type;
                // Clamp current seat count down if it no longer fits the
                // newly selected vehicle's max capacity.
                final max = maxSeatsForVehicle(type);
                if (_seats > max) _seats = max;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: selected ? const Color(0xFF1A73E8) : card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? const Color(0xFF1A73E8) : border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Helpers.getVehicleIcon(type), size: 15, color: selected ? Colors.white : ts),
                  const SizedBox(width: 6),
                  Text(type, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : tp)),
                ]),
              ),
            );
          }).toList()),
          const SizedBox(height: 16),

          // Available seats — starts at 0, and +/- adjust it live, always
          // clamped between 0 and the current vehicle's max capacity.
          Text('Available Seats', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 10),
          Builder(builder: (_) {
            final maxSeats = maxSeatsForVehicle(_vehicleType);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$_seats seat${_seats == 1 ? '' : 's'}', style: TextStyle(color: tp, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Max $maxSeats for $_vehicleType', style: TextStyle(color: ts, fontSize: 11)),
                  ]),
                ),
                _SeatStepButton(
                  icon: Icons.remove_rounded,
                  enabled: _seats > 0,
                  onTap: () => setState(() => _seats = (_seats - 1).clamp(0, maxSeats)),
                  tp: tp, border: border, card: card,
                ),
                const SizedBox(width: 12),
                _SeatStepButton(
                  icon: Icons.add_rounded,
                  enabled: _seats < maxSeats,
                  onTap: () => setState(() => _seats = (_seats + 1).clamp(0, maxSeats)),
                  tp: tp, border: border, card: card,
                ),
              ]),
            );
          }),
          const SizedBox(height: 28),

          // Create button
          SizedBox(width: double.infinity, height: 50,
              child: ElevatedButton(
                  onPressed: _isCreating ? null : _create,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: _isCreating
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create Trip', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// Round +/- button used by the Available Seats counter. Disabled state
// (greyed out, no tap) when the count is already at its min/max bound.
class _SeatStepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color tp, border, card;
  const _SeatStepButton({required this.icon, required this.enabled, required this.onTap, required this.tp, required this.border, required this.card});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36, height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF1A73E8) : card,
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? const Color(0xFF1A73E8) : border),
        ),
        child: Icon(icon, size: 18, color: enabled ? Colors.white : border),
      ),
    );
  }
}