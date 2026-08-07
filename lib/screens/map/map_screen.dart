import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../providers/location_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/traffic_service.dart';
import '../../core/services/location_service.dart';
import '../sos/sos_screen.dart';
import 'live_location_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapCtrl = MapController();
  final FirestoreService _firestoreService = FirestoreService();
  final TrafficService _trafficService = TrafficService();
  final LocationService _locationService = LocationService();
  bool _isTripActive = true;
  String? _driverPhone;
  String? _loadedForTripId;

  // ---- Live distance/ETA to the destination, refreshed periodically ----
  double? _liveDistanceKm;
  Duration? _liveEta;
  bool _trafficLoading = false;
  String? _loadedTrafficForTripId;
  Timer? _trafficTimer;

  // ---- Live average speed, derived from the rider's real GPS fixes ----
  StreamSubscription<dynamic>? _speedSub;
  final List<double> _speedSamplesKmh = [];
  double? _avgSpeedKmh;
  dynamic _lastSpeedPos; // last Position used to derive a speed sample
  DateTime? _lastSpeedPosTime;

  @override
  void initState() {
    super.initState();
    _startSpeedTracking();
  }

  @override
  void dispose() {
    _trafficTimer?.cancel();
    _speedSub?.cancel();
    super.dispose();
  }

  // Real-time average speed, built from the rider's actual live GPS fixes
  // and the trip's own geometry — not a placeholder.
  //
  // Primary source: distance between consecutive live position fixes
  // (Haversine, via LocationService.calculateDistance) divided by the
  // elapsed time between them. This is what makes it "fully dynamic" —
  // it works purely off live location + trip data, so it still functions
  // on web/desktop browsers where the Geolocation API's native
  // Position.speed field is commonly null or stuck at 0.
  //
  // Secondary source: the device's own Position.speed (m/s -> km/h), used
  // only when it's present and paired with a tight speedAccuracy — on
  // devices where it IS supported, it's a more direct GPS-chip reading.
  //
  // Both feed the same rolling window (last 20 samples) so the displayed
  // value is a smoothed real-time average, not a single noisy instant.
  Future<void> _startSpeedTracking() async {
    final hasPermission = await _locationService.checkPermission();
    if (!hasPermission || !mounted) return;
    _speedSub = _locationService.positionStream().listen((pos) {
      if (!mounted) return;
      final now = DateTime.now();
      double? sampleKmh;

      final deviceKmh = pos.speed * 3.6;
      if (!deviceKmh.isNaN && deviceKmh > 0 && pos.speedAccuracy >= 0 && pos.speedAccuracy < 5) {
        sampleKmh = deviceKmh;
      }

      if (sampleKmh == null && _lastSpeedPos != null && _lastSpeedPosTime != null) {
        final elapsedSeconds = now.difference(_lastSpeedPosTime!).inMilliseconds / 1000.0;
        // Need a real time gap between fixes, otherwise distance/time blows up.
        if (elapsedSeconds >= 1) {
          final distanceKm = _locationService.calculateDistance(
            _lastSpeedPos!.latitude, _lastSpeedPos!.longitude, pos.latitude, pos.longitude,
          );
          final derivedKmh = distanceKm / (elapsedSeconds / 3600);
          // Discard GPS-jump artifacts (e.g. a jittery indoor fix) rather
          // than let one bad reading skew the rolling average.
          if (derivedKmh.isFinite && derivedKmh >= 0 && derivedKmh < 200) {
            sampleKmh = derivedKmh;
          }
        }
      }

      _lastSpeedPos = pos;
      _lastSpeedPosTime = now;
      if (sampleKmh == null) return; // not enough data yet from this fix

      setState(() {
        _speedSamplesKmh.add(sampleKmh!);
        if (_speedSamplesKmh.length > 20) _speedSamplesKmh.removeAt(0);
        _avgSpeedKmh = _speedSamplesKmh.reduce((a, b) => a + b) / _speedSamplesKmh.length;
      });
    }, onError: (_) {});
  }

  // Clears the rolling speed window so a new trip starts its average from
  // scratch instead of carrying over samples from a previous trip/route.
  void _resetSpeedTracking() {
    _speedSamplesKmh.clear();
    _avgSpeedKmh = null;
    _lastSpeedPos = null;
    _lastSpeedPosTime = null;
  }

  // Real route distance + ETA from the rider's CURRENT live position to the
  // trip destination (via TrafficService — OSRM road-network routing, or
  // HERE live traffic if configured). Refreshed every 25s so it keeps
  // tracking as the rider actually moves, instead of a one-time snapshot.
  Future<void> _refreshTraffic(dynamic trip) async {
    if (trip == null || !mounted) return;
    final location = context.read<LocationProvider>();
    final pos = location.positionOrDefault;
    setState(() => _trafficLoading = true);
    final info = await _trafficService.getRouteTraffic(
      originLat: pos.latitude,
      originLng: pos.longitude,
      destLat: trip.destinationLat,
      destLng: trip.destinationLng,
    );
    if (!mounted) return;
    setState(() {
      _trafficLoading = false;
      if (info != null) {
        _liveDistanceKm = info.distanceKm;
        _liveEta = info.eta;
      }
    });
  }

  void _startTrafficPolling(dynamic trip) {
    _refreshTraffic(trip);
    _trafficTimer?.cancel();
    _trafficTimer = Timer.periodic(const Duration(seconds: 25), (_) => _refreshTraffic(trip));
  }

  String _formatEta(Duration d) {
    if (d.inMinutes < 1) return '<1 min';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes} min';
  }

  // Looks up the trip creator's real phone number from Firestore so the
  // call button dials the actual driver instead of a dummy number.
  Future<void> _loadDriverPhone(String creatorUid) async {
    final user = await _firestoreService.getUser(creatorUid);
    if (!mounted) return;
    setState(() => _driverPhone = user?.phoneNumber);
  }

  Future<void> _callDriver() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_driverPhone == null || _driverPhone!.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Driver phone number not available')));
      return;
    }
    final uri = Uri.parse('tel:$_driverPhone');
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Could not open dialer')));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Could not open dialer')));
      }
    }
  }

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
    final trip = context.watch<TripProvider>().activeTrip;
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final pos = location.positionOrDefault;

    // Fetch the real driver's phone number once per trip (not on every rebuild)
    if (trip != null && _loadedForTripId != trip.tripId) {
      _loadedForTripId = trip.tripId;
      _driverPhone = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDriverPhone(trip.creatorUid));
    }

    // Start/refresh live distance+ETA polling once per trip.
    if (trip != null && _loadedTrafficForTripId != trip.tripId) {
      _loadedTrafficForTripId = trip.tripId;
      _liveDistanceKm = null;
      _liveEta = null;
      _resetSpeedTracking();
      WidgetsBinding.instance.addPostFrameCallback((_) => _startTrafficPolling(trip));
    } else if (trip == null && _loadedTrafficForTripId != null) {
      _loadedTrafficForTripId = null;
      _trafficTimer?.cancel();
      _liveDistanceKm = null;
      _liveEta = null;
      _resetSpeedTracking();
    }

    final hasTrip = trip != null;
    final driverName = trip?.creatorName ?? '';
    final from = trip?.startLocationName ?? '';
    final to = trip?.destinationName ?? '';
    final startTime = trip != null ? DateFormat('hh:mm a').format(trip.travelDate) : '';
    final endTime = (trip != null && trip.durationMinutes != null)
        ? '~${DateFormat('hh:mm a').format(trip.travelDate.add(Duration(minutes: trip.durationMinutes!)))}'
        : '--';
    final dest = trip != null
        ? LatLng(trip.destinationLat, trip.destinationLng)
        : LatLng(pos.latitude, pos.longitude);

    return Scaffold(
      body: Stack(children: [
        // Full screen map (now visible behind a draggable sheet)
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(initialCenter: LatLng(pos.latitude, pos.longitude), initialZoom: 13),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.secureride.app'),
            if (hasTrip)
              PolylineLayer(polylines: [
                Polyline(points: [LatLng(pos.latitude, pos.longitude), dest],
                    color: const Color(0xFF1A73E8), strokeWidth: 4),
              ]),
            MarkerLayer(markers: [
              Marker(point: LatLng(pos.latitude, pos.longitude), width: 44, height: 44,
                  child: Container(
                      decoration: BoxDecoration(color: const Color(0xFF1A73E8), shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color(0xFF1A73E8).withValues(alpha: 0.4), blurRadius: 8)]),
                      child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 22))),
              if (hasTrip)
                Marker(point: dest, width: 44, height: 44,
                    child: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 44)),
            ]),
          ],
        ),

        // Top overlay: header + compact "Your Trip is Active" banner
        Positioned(top: 0, left: 0, right: 0,
            child: SafeArea(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFF1A73E8), borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)]),
                      child: const Row(children: [
                        Icon(Icons.map_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('Live Map', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ])),
                  const Spacer(),
                  GestureDetector(
                      onTap: () => _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 15),
                      child: Container(width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)]),
                          child: const Icon(Icons.my_location_rounded, color: Color(0xFF1A73E8), size: 22))),
                ]),
                if (hasTrip) ...[
                  const SizedBox(height: 8),
                  // Compact active banner (single row to save map space)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)],
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 15),
                      const SizedBox(width: 6),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Your Trip is Active',
                            style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(height: 1),
                        Row(children: [
                          Flexible(child: Text('$from → $to', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: tp, fontWeight: FontWeight.w600, fontSize: 13))),
                        ]),
                      ])),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _mapCtrl.move(
                            LatLng((pos.latitude + dest.latitude) / 2, (pos.longitude + dest.longitude) / 2), 10),
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFF1A73E8), borderRadius: BorderRadius.circular(8)),
                            child: const Text('View Details', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                      ),
                    ]),
                  ),
                ],
              ]),
            ))),

        // ---- Draggable info sheet (map stays full-screen behind it) ----
        DraggableScrollableSheet(
          initialChildSize: 0.42,
          minChildSize: 0.14,
          maxChildSize: 0.92,
          snap: false,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(color: card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, -4))]),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: [
                // Drag handle
                Center(child: Container(width: 44, height: 5,
                    decoration: BoxDecoration(color: ts.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 14),

                if (!hasTrip) ...[
                  // ---- No active trip ----
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(children: [
                      Icon(Icons.explore_off_rounded, color: ts, size: 40),
                      const SizedBox(height: 10),
                      Text('No Active Trip', style: TextStyle(color: tp, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Join a trip using a trip code, or create one, to see it here.',
                          textAlign: TextAlign.center, style: TextStyle(color: ts, fontSize: 12)),
                    ]),
                  ),
                ] else ...[
                  // ---- Driver info ----
                  Row(children: [
                    CircleAvatar(radius: 24, backgroundColor: const Color(0xFF22C55E).withValues(alpha: 0.15),
                        child: Text(driverName.isNotEmpty ? driverName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 18))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Driver', style: TextStyle(color: ts, fontSize: 11)),
                      Row(children: [
                        Text(driverName, style: TextStyle(color: tp, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 6),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.verified_rounded, color: Color(0xFF1A73E8), size: 12),
                              SizedBox(width: 2),
                              Text('Verified', style: TextStyle(color: Color(0xFF1A73E8), fontSize: 10, fontWeight: FontWeight.w600)),
                            ])),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.confirmation_number_outlined, color: ts, size: 13),
                        const SizedBox(width: 3),
                        Text('Trip Code: ${trip.tripCode}', style: TextStyle(color: ts, fontSize: 12)),
                      ]),
                    ])),
                    GestureDetector(
                      onTap: _callDriver,
                      child: Container(width: 46, height: 46,
                          decoration: BoxDecoration(color: const Color(0xFF1A73E8), shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: const Color(0xFF1A73E8).withValues(alpha: 0.4), blurRadius: 8)]),
                          child: const Icon(Icons.call_rounded, color: Colors.white, size: 22)),
                    ),
                  ]),
                  Divider(height: 24, color: ts.withValues(alpha: 0.2)),

                  // ---- Route (En Route) ----
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(from, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tp, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(startTime, style: TextStyle(color: ts, fontSize: 11)),
                    ])),
                    Column(children: [
                      const SizedBox(height: 2),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(height: 1, width: 24, color: const Color(0xFF1A73E8).withValues(alpha: 0.4)),
                        const Icon(Icons.directions_car_rounded, color: Color(0xFF1A73E8), size: 18),
                        Container(height: 1, width: 24, color: const Color(0xFF1A73E8).withValues(alpha: 0.4)),
                      ]),
                    ]),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(to, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tp, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(endTime, style: TextStyle(color: ts, fontSize: 11)),
                    ])),
                  ]),
                  const SizedBox(height: 14),

                  // ---- Live stats: Distance, ETA, Avg Speed, Seats ----
                  // Distance/ETA come from TrafficService using the rider's
                  // CURRENT position -> destination (refreshed every 25s), so
                  // they shrink as the trip progresses instead of staying
                  // fixed at the planned totals. Avg Speed is the rolling
                  // average of real GPS speed readings. Seats always reflects
                  // the trip's live booked/available counts.
                  Row(children: [
                    Expanded(child: _StatBox(
                        value: _liveDistanceKm != null
                            ? '${_liveDistanceKm!.toStringAsFixed(1)} km'
                            : (_trafficLoading ? '…' : (trip.distanceKm != null ? '${trip.distanceKm!.toStringAsFixed(1)} km' : '—')),
                        label: 'Distance', bg: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04), tp: tp, ts: ts)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatBox(
                        value: _liveEta != null ? _formatEta(_liveEta!) : (_trafficLoading ? '…' : '—'),
                        label: 'ETA', bg: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04), tp: tp, ts: ts)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatBox(
                        value: _avgSpeedKmh != null ? '${_avgSpeedKmh!.toStringAsFixed(0)} km/h' : 'N/A',
                        label: 'Avg Speed', bg: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04), tp: tp, ts: ts)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatBox(
                        value: '${trip.bookedSeats}/${trip.availableSeats}',
                        label: 'Seats', bg: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04), tp: tp, ts: ts)),
                  ]),
                  const SizedBox(height: 14),

                ],

                // ---- SOS + Share Location ----
                Row(children: [
                  Expanded(child: SizedBox(height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosScreen())),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.sos_rounded, size: 20),
                        SizedBox(width: 6),
                        Text('SOS Emergency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: SizedBox(height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveLocationScreen())),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.share_location_rounded, size: 18),
                          SizedBox(width: 6),
                          Text('Share Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ]),
                        Text('Live Tracking', style: TextStyle(fontSize: 9, color: Colors.white70)),
                      ]),
                    ),
                  )),
                ]),

                if (hasTrip && _isTripActive) ...[
                  const SizedBox(height: 6),
                  Center(child: TextButton(
                    onPressed: () => _confirmEndTrip(context),
                    child: Text('End Trip', style: TextStyle(color: ts, fontSize: 12, fontWeight: FontWeight.w600)),
                  )),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final Color bg, tp, ts;
  const _StatBox({required this.value, required this.label, required this.bg, required this.tp, required this.ts});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tp))),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: ts)),
    ]),
  );
}