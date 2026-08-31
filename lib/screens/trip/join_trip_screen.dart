import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../core/services/firestore_service.dart';
import '../../models/trip_model.dart';
import '../home/home_screen.dart';
import 'safety_score_screen.dart';

// ---- Fixed dark-navy palette for this screen (matches the approved design) ----
const _bg = Color(0xFF0A0E27);
const _bgGlow = Color(0xFF132048);
const _card = Color(0xFF10162E);
const _cardBorder = Color(0xFF232F58);
const _blue = Color(0xFF2F6BF0);
const _blueSoft = Color(0xFF6FA1FF);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);
const _textSecondary = Color(0xFF8C99C4);

// Per-card accent colour, cycled by position so the Suggested Trips list
// always reads as varied and colourful like the approved design.
const List<Color> _cardAccents = [_blue, Color(0xFF3B82F6), Color(0xFF22D3C9), Color(0xFF9B5DE5), Color(0xFFC026D3)];

// Dashed curve connecting the two route pins in the header banner.
class _DashedCurvePainter extends CustomPainter {
  const _DashedCurvePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.82)
      ..cubicTo(size.width * 0.32, size.height * 1.05, size.width * 0.6, -size.height * 0.15, size.width, size.height * 0.1);

    const dashWidth = 6.0;
    const dashSpace = 5.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dashWidth), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCurvePainter oldDelegate) => false;
}

// Location names stored on a trip can be a full address (e.g. "Fathima
// College for Women, Madurai, Tamil Nadu"). For the Suggested Trips list
// we only want the district/city — e.g. "Madurai" — not the full address.
// Indian state names are stripped, then the last remaining comma-separated
// part is used as the district.
const List<String> _indianStates = [
  'tamil nadu', 'kerala', 'karnataka', 'andhra pradesh', 'telangana',
  'puducherry', 'maharashtra', 'goa', 'gujarat', 'rajasthan', 'punjab',
  'haryana', 'delhi', 'uttar pradesh', 'bihar', 'west bengal', 'odisha',
  'madhya pradesh', 'chhattisgarh', 'jharkhand', 'assam', 'india',
];

String districtName(String fullName) {
  final parts = fullName.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  final filtered = parts.where((p) => !_indianStates.contains(p.toLowerCase())).toList();
  if (filtered.isEmpty) return fullName.trim();
  return filtered.last;
}

// Fallback sample routes — the exact places from the reference design
// (Bangalore→Chennai, Coimbatore→Trichy, Salem→Hyderabad, Vellore→Pondicherry,
// Erode→Bengaluru). These only fill in when there aren't 5 real trips in
// Firestore yet, so the page always looks populated like the approved
// design. They're clearly marked "Demo route" and can't be joined, since
// there's no real trip behind them.
final List<TripModel> _sampleRouteTrips = [
  ('Bangalore', 'Chennai', 'Car', 4, 2),
  ('Coimbatore', 'Trichy', 'Van', 5, 3),
  ('Salem', 'Hyderabad', 'SUV', 4, 1),
  ('Vellore', 'Pondicherry', 'Bus', 6, 4),
  ('Erode', 'Bengaluru', 'Car', 4, 2),
].asMap().entries.map((entry) {
  final i = entry.key;
  final r = entry.value;
  final now = DateTime.now();
  final travel = DateTime(now.year, now.month, now.day, 8, 0).add(Duration(days: i + 1));
  return TripModel(
    tripId: 'sample-${r.$1}-${r.$2}',
    tripCode: 'DEMO${r.$1.substring(0, 2).toUpperCase()}',
    creatorUid: '', creatorName: 'Demo', creatorEmail: '',
    startLocationName: r.$1, startLat: 0, startLng: 0,
    destinationName: r.$2, destinationLat: 0, destinationLng: 0,
    travelDate: travel,
    passengerType: 'Solo', vehicleType: r.$3,
    availableSeats: r.$4, bookedSeats: r.$5,
    status: TripStatus.active,
    createdAt: now, updatedAt: now,
  );
}).toList();

bool isSampleTrip(TripModel t) => t.tripId.startsWith('sample-');

class JoinTripScreen extends StatefulWidget {
  const JoinTripScreen({super.key});
  @override
  State<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends State<JoinTripScreen> {
  final _codeCtrl = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
  bool _isJoining = false;
  TripModel? _tripPreview;
  String? _errorMessage;

  // Suggested trips are fetched fresh (real, currently-open trips from
  // Firestore — never dummy data) every time this page opens, deduped by
  // district-level route, and shuffled — so the person sees a fresh random
  // set each visit. The refresh icon re-runs the exact same real fetch.
  List<TripModel>? _suggestedTrips;
  bool _suggestionsLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSuggestions());
  }

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  Future<void> _loadSuggestions() async {
    setState(() => _suggestionsLoading = true);
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    final pool = await _firestoreService.getAvailableTripsForSuggestions(uid);
    if (!mounted) return;

    // Keep only one trip per unique DISTRICT route (e.g. "Madurai → Chennai")
    // so two trips that differ only in exact address (college gate vs bus
    // stand, same city) don't show up as two separate suggestions.
    final seenRoutes = <String>{};
    final uniqueByRoute = <TripModel>[];
    for (final t in pool) {
      final routeKey = '${districtName(t.startLocationName).toLowerCase()}→${districtName(t.destinationName).toLowerCase()}';
      if (seenRoutes.add(routeKey)) uniqueByRoute.add(t);
    }

    uniqueByRoute.shuffle(Random());
    final realTrips = uniqueByRoute.take(5).toList();

    // Fill any remaining slots (up to 5 total) with the sample routes,
    // skipping any sample whose route already matches a real trip shown.
    final shownRouteKeys = realTrips.map((t) =>
    '${districtName(t.startLocationName).toLowerCase()}→${districtName(t.destinationName).toLowerCase()}').toSet();
    final fillers = _sampleRouteTrips.where((s) {
      final key = '${s.startLocationName.toLowerCase()}→${s.destinationName.toLowerCase()}';
      return !shownRouteKeys.contains(key);
    }).take(5 - realTrips.length);

    setState(() {
      _suggestedTrips = [...realTrips, ...fillers];
      _suggestionsLoading = false;
    });
  }

  // Real Firestore lookup by the trip code the user typed in — no dummy
  // preview data. Shows the actual creator, route, date and seats for
  // that specific trip; any real trip (active/completed/cancelled) is
  // found by its code, "not found" only means the code doesn't exist.
  Future<void> _search() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() { _isLoading = true; _tripPreview = null; _errorMessage = null; });
    final trip = await _firestoreService.getTripByCode(code.toUpperCase());
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (trip == null) {
        _errorMessage = 'Trip not found. Check the code and try again.';
      } else {
        _tripPreview = trip;
      }
    });
  }

  Future<void> _join() async {
    if (_tripPreview == null) return;
    setState(() => _isJoining = true);
    final auth = context.read<AuthProvider>();
    final result = await context.read<TripProvider>().joinTrip(
      tripCode: _tripPreview!.tripCode,
      uid: auth.currentUser?.uid ?? '',
      email: auth.currentUser?.email ?? '',
      name: auth.currentUser?.fullName ?? '',
    );
    if (!mounted) return;
    setState(() => _isJoining = false);
    if (result['success'] == true) {
      context.read<TripProvider>().setActiveTrip(result['trip']);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 18), SizedBox(width: 8), Text('Joined trip successfully!')]),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16)));
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['error']?.toString() ?? 'Could not join this trip.'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16)));
    }
  }

  IconData _vehicleIcon(String vehicle) {
    switch (vehicle) {
      case 'Van': return Icons.airport_shuttle_rounded;
      case 'SUV': return Icons.directions_car_filled_rounded;
      case 'Bike': return Icons.two_wheeler_rounded;
      case 'Auto': return Icons.electric_rickshaw_rounded;
      case 'Bus': return Icons.directions_bus_rounded;
      default: return Icons.directions_car_rounded;
    }
  }

  String _monthShort(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildHeaderBanner(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildCodeCard(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: _red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _red.withValues(alpha: 0.3))),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded, color: _red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: _red, fontSize: 12.5, fontWeight: FontWeight.w500))),
                        ]),
                      ),
                    ],
                    if (_tripPreview != null) ...[
                      const SizedBox(height: 14),
                      _buildTripPreviewCard(),
                    ],
                    const SizedBox(height: 22),
                    _buildOrDivider(),
                    const SizedBox(height: 22),
                    _buildSuggestionsHeader(),
                    const SizedBox(height: 14),
                    _buildSuggestionsList(),
                    const SizedBox(height: 20),
                    _buildSafetyFooterCard(context),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_bgGlow, _bg], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        // Decorative skyline silhouette, behind the route line
        Positioned(
          right: 26, top: 46,
          child: Opacity(
            opacity: 0.14,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(7, (i) => Container(
                width: 12, height: 14.0 + (i % 4) * 12,
                margin: const EdgeInsets.only(left: 3),
                color: Colors.white))),
          ),
        ),
        // Dashed curved route between the two pins
        const Positioned(
          left: 130, right: 12, top: 44, height: 90,
          child: CustomPaint(painter: _DashedCurvePainter(), size: Size.infinite),
        ),
        // Start pin (lower-left)
        Positioned(left: 96, top: 108, child: _routePin(_blueSoft)),
        // Destination pin (upper-right)
        Positioned(right: 8, top: 22, child: _routePin(_blue)),

        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24)),
          const SizedBox(height: 10),
          const Text('Join Trip', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Find a trip and share the ride', style: TextStyle(color: _textSecondary, fontSize: 13)),
        ]),
      ]),
    );
  }

  Widget _routePin(Color color) => Container(
    width: 32, height: 32,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 12, spreadRadius: 1)]),
    child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
  );

  Widget _buildCodeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: _cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Enter Trip Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 3),
        const Text('Ask the trip creator for their trip code', style: TextStyle(color: _textSecondary, fontSize: 12.5)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 1.5),
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'e.g. MDU4A21',
                hintStyle: const TextStyle(color: _textSecondary, letterSpacing: 1, fontWeight: FontWeight.normal),
                filled: true, fillColor: _bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _search,
            style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16), elevation: 0),
            icon: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.search_rounded, size: 18),
            label: Text(_isLoading ? '' : 'Search', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildTripPreviewCard() {
    final t = _tripPreview!;
    final statusColor = t.status == TripStatus.active ? _green : (t.status == TripStatus.cancelled ? _red : _textSecondary);
    final seatsLeft = (t.availableSeats - t.bookedSeats).clamp(0, 999);
    final statusLabel = '${t.status.name[0].toUpperCase()}${t.status.name.substring(1)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person_rounded, color: _blueSoft, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(t.creatorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold))),
        ]),
        const Divider(height: 20, color: _cardBorder),

        Row(children: [
          const Icon(Icons.location_on_rounded, color: _blue, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(t.startLocationName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.location_on_rounded, color: _red, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(t.destinationName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 12),

        Row(children: [
          _detail(Icons.calendar_today_outlined, '${t.travelDate.day} ${_monthShort(t.travelDate.month)} ${t.travelDate.year}'),
          const SizedBox(width: 12),
          _detail(_vehicleIcon(t.vehicleType), t.vehicleType),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          _detail(Icons.people_outline_rounded, '$seatsLeft seats left'),
          const SizedBox(width: 12),
          _detail(Icons.tag_rounded, t.tripCode),
        ]),
        const SizedBox(height: 16),

        SizedBox(width: double.infinity, height: 48,
            child: ElevatedButton(
                onPressed: (_isJoining || t.status != TripStatus.active || t.availableSeats - t.bookedSeats <= 0) ? null : _join,
                style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white,
                    disabledBackgroundColor: _cardBorder,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: _isJoining
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                    t.status != TripStatus.active
                        ? 'Trip $statusLabel'
                        : (t.availableSeats - t.bookedSeats) <= 0 ? 'Trip Full' : 'Join Trip',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
      ]),
    );
  }

  Widget _detail(IconData icon, String text) => Expanded(
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: _textSecondary), const SizedBox(width: 3),
      Flexible(child: Text(text, style: const TextStyle(fontSize: 11, color: _textSecondary), overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _buildOrDivider() {
    return Row(children: [
      const Expanded(child: Divider(color: _cardBorder)),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        width: 34, height: 34,
        decoration: BoxDecoration(color: _bg, shape: BoxShape.circle, border: Border.all(color: _blue, width: 1.5)),
        child: const Center(child: Text('OR', style: TextStyle(color: _blueSoft, fontWeight: FontWeight.bold, fontSize: 11))),
      ),
      const Expanded(child: Divider(color: _cardBorder)),
    ]);
  }

  Widget _buildSuggestionsHeader() {
    return const Text('Suggestion Trips', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildSuggestionsList() {
    if (_suggestionsLoading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator(color: _blue)));
    }
    final suggestions = _suggestedTrips ?? [];
    if (suggestions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder)),
        child: const Column(children: [
          Icon(Icons.explore_off_outlined, size: 36, color: _textSecondary),
          SizedBox(height: 8),
          Text('No open trips right now', style: TextStyle(color: _textSecondary, fontSize: 13)),
        ]),
      );
    }
    return Column(children: suggestions.asMap().entries.map((entry) {
      final i = entry.key;
      final t = entry.value;
      return _SuggestionCard(
        trip: t,
        accent: _cardAccents[i % _cardAccents.length],
        onTap: () {
          // Tapping a suggestion just fills the code field — the person
          // can hit Search to see full details and join from there.
          setState(() { _codeCtrl.text = t.tripCode; _tripPreview = null; _errorMessage = null; });
        },
      );
    }).toList());
  }

  Widget _buildSafetyFooterCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyScoreScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder)),
        child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: _blue.withValues(alpha: 0.16), shape: BoxShape.circle),
              child: const Icon(Icons.verified_user_rounded, color: _blueSoft, size: 22)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your safety is our priority', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 3),
              Text('Share your live location and trip details with trusted contacts.',
                  style: TextStyle(color: _textSecondary, fontSize: 11.5)),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 24),
        ]),
      ),
    );
  }
}

// Suggestion card matching the approved design: pin → dashed line → pin
// timeline, route text, and a colourful decorative "scene" panel on the
// right (no seats/date/vehicle/button clutter, matching the photo exactly).
// Tapping the whole card fills the trip code so the person can Search/Join
// through the existing flow above.
class _SuggestionCard extends StatelessWidget {
  final TripModel trip;
  final Color accent;
  final VoidCallback onTap;
  const _SuggestionCard({required this.trip, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 3))]),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // pin → dashed line → pin timeline
          SizedBox(
            width: 20,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.location_on_rounded, color: accent, size: 20),
              SizedBox(height: 16, child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(3, (_) => Container(width: 2, height: 3, color: _textSecondary.withValues(alpha: 0.5))))),
              Icon(Icons.location_on_rounded, color: accent, size: 20),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Flexible(child: Text(districtName(trip.startLocationName),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.5), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: _textSecondary, size: 16),
                const SizedBox(width: 8),
                Flexible(child: Text(districtName(trip.destinationName),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.5), overflow: TextOverflow.ellipsis)),
              ]),
              if (isSampleTrip(trip)) const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text('Demo route', style: TextStyle(color: _textSecondary, fontSize: 10.5, fontStyle: FontStyle.italic)),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(Icons.auto_awesome_rounded, color: accent.withValues(alpha: 0.85), size: 20),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 22),
        ]),
      ),
    );
  }
}