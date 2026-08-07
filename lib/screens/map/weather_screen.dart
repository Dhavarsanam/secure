import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/trip_provider.dart';
import '../../core/services/weather_service.dart';
import '../../core/services/traffic_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/geocoding_service.dart';
import '../../core/constants/madurai_places.dart';
import '../../utils/app_icon_colors.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _weatherService = WeatherService();
  final TrafficService _trafficService = TrafficService();
  final LocationService _locationService = LocationService();
  final GeocodingService _geocodingService = GeocodingService();
  final _cityController = TextEditingController();

  Position? _position;
  WeatherData? _weather;
  bool _weatherLoading = true;
  String? _weatherError;

  TrafficInfo? _traffic;
  bool _trafficLoading = false;
  String? _trafficError;
  bool _noActiveTrip = false;
  String? _trafficHotspotName;

  Timer? _refreshTimer;
  String? _lastTripKey;

  @override
  void initState() {
    super.initState();
    _loadAll();
    // Live periodic refresh — weather + traffic both update automatically
    // while this screen is open, without the user doing anything.
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) => _loadAll(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadAll({bool silent = false}) async {
    if (!silent) setState(() { _weatherLoading = true; _weatherError = null; });
    final pos = await _locationService.getCurrentPosition();
    if (pos == null) {
      if (mounted) setState(() { _weatherLoading = false; _weatherError = 'Unable to get your current location.'; });
    } else {
      _position = pos;
      final cityName = await _geocodingService.reverseGeocode(pos.latitude, pos.longitude);
      final weather = await _weatherService.getWeather(lat: pos.latitude, lng: pos.longitude, cityName: cityName);
      if (mounted) {
        setState(() {
          _weatherLoading = false;
          _weather = weather;
          _weatherError = weather == null ? 'Weather data currently unavailable' : null;
        });
      }
    }
    await _loadTraffic();
  }

  Future<void> _loadTraffic() async {
    if (!mounted) return;
    final trips = context.read<TripProvider>();
    final activeTrip = trips.activeTrip;

    if (activeTrip == null) {
      setState(() { _noActiveTrip = true; _traffic = null; _trafficError = null; _trafficLoading = false; });
      return;
    }

    setState(() { _trafficLoading = true; _trafficError = null; _noActiveTrip = false; });

    // Always based on the trip's own selected route (source → destination),
    // not the device's live GPS fix — so the alert is tied to the route the
    // user actually picked, and still works without location permission.
    final info = await _trafficService.getRouteTraffic(
      originLat: activeTrip.startLat,
      originLng: activeTrip.startLng,
      destLat: activeTrip.destinationLat,
      destLng: activeTrip.destinationLng,
    );

    if (!mounted) return;

    // Name the real, nearby Madurai area along the route (midpoint between
    // source and destination) from our curated local place list — always
    // available, no network round-trip, no generic fallback text.
    final midLat = (activeTrip.startLat + activeTrip.destinationLat) / 2;
    final midLng = (activeTrip.startLng + activeTrip.destinationLng) / 2;
    final hotspot = nearestMaduraiPlace(midLat, midLng).name;

    setState(() {
      _trafficLoading = false;
      _traffic = info;
      _trafficError = info == null ? 'Traffic data currently unavailable' : null;
      _trafficHotspotName = hotspot;
    });
  }

  Future<void> _searchCity() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) return;
    setState(() { _weatherLoading = true; _weatherError = null; });
    final place = await _weatherService.geocodeCity(city);
    if (place == null) {
      setState(() { _weatherLoading = false; _weatherError = 'Could not find "$city"'; });
      return;
    }
    final weather = await _weatherService.getWeather(lat: place.lat, lng: place.lng, cityName: place.name);
    setState(() {
      _weatherLoading = false;
      _weather = weather;
      _weatherError = weather == null ? 'Weather data currently unavailable' : null;
    });
  }

  Color _alertColor(String level) {
    switch (level) {
      case 'danger': return const Color(0xFFDC2626);
      case 'warning': return const Color(0xFFF59E0B);
      case 'caution': return const Color(0xFF3B82F6);
      default: return const Color(0xFF22C55E);
    }
  }

  Color _trafficLevelColor(String level) {
    switch (level) {
      case 'Heavy Traffic': return const Color(0xFFDC2626);
      case 'Moderate Traffic': return const Color(0xFFF59E0B);
      default: return const Color(0xFF22C55E);
    }
  }

  IconData _trafficLevelIcon(String level) {
    switch (level) {
      case 'Heavy Traffic': return Icons.warning_amber_rounded;
      case 'Moderate Traffic': return Icons.traffic_rounded;
      default: return Icons.check_circle;
    }
  }

  // Friendly, dynamic traffic alert — always reflects the real level and
  // the real nearby area for the selected route. Never a static message.
  String _trafficMessage(TrafficInfo info, String? hotspot) {
    switch (info.level) {
      case 'Heavy Traffic':
        return 'Heavy traffic near ${hotspot ?? "your route"}. Drive safely and expect slight delays.';
      case 'Moderate Traffic':
        return 'Moderate traffic near ${hotspot ?? "your route"}. Expect a slightly longer trip — stay alert.';
      default:
        return 'No traffic on your route. Enjoy a smooth and safe ride.';
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'high': return const Color(0xFFDC2626);
      case 'medium': return const Color(0xFFF59E0B);
      default: return const Color(0xFF22C55E);
    }
  }

  IconData _incidentIcon(String type) {
    switch (type) {
      case 'Accident': return Icons.car_crash_rounded;
      case 'Construction': return Icons.construction_rounded;
      case 'Road Closure': return Icons.block_rounded;
      case 'Road Block': return Icons.warning_amber_rounded;
      case 'Heavy Traffic': return Icons.traffic_rounded;
      default: return Icons.access_time_rounded;
    }
  }

  IconData _weatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear': return Icons.wb_sunny_rounded;
      case 'clouds': return Icons.cloud_rounded;
      case 'rain':
      case 'drizzle': return Icons.water_drop_rounded;
      case 'thunderstorm': return Icons.thunderstorm_rounded;
      case 'snow': return Icons.ac_unit_rounded;
      case 'fog': return Icons.foggy;
      default: return Icons.wb_cloudy_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final trips = context.watch<TripProvider>();
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    // React to destination changes automatically — new/changed active trip
    // triggers a fresh traffic fetch without the user asking.
    final activeTrip = trips.activeTrip;
    final tripKey = activeTrip == null ? null : '${activeTrip.tripId}_${activeTrip.destinationLat}_${activeTrip.destinationLng}';
    if (tripKey != _lastTripKey) {
      _lastTripKey = tripKey;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadTraffic(); });
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        title: const Text('Weather & Traffic', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: appIconColor(Icons.refresh)), onPressed: () => _loadAll()),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadAll(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Search
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                hintText: 'Search city...',
                hintStyle: TextStyle(color: ts),
                prefixIcon: Icon(Icons.search, color: appIconColor(Icons.search)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF1A73E8)),
                  onPressed: _searchCity,
                ),
                filled: true, fillColor: card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: TextStyle(color: tp),
              onSubmitted: (_) => _searchCity(),
            ),

            const SizedBox(height: 16),

            // ---------------- WEATHER ----------------
            if (_weatherLoading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8))))
            else if (_weatherError != null)
              _ErrorCard(message: _weatherError!, card: card, tp: tp, ts: ts, onRetry: () => _loadAll())
            else if (_weather != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _weather!.isStormy
                          ? [const Color(0xFF374151), const Color(0xFF1F2937)]
                          : _weather!.isRaining
                          ? [const Color(0xFF1E3A5F), const Color(0xFF1A73E8)]
                          : [const Color(0xFF1A73E8), const Color(0xFF0EA5E9)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: const Color(0xFF1A73E8).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_weather!.city, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(_weather!.description.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1)),
                      ])),
                      Icon(_weatherIcon(_weather!.condition), color: Colors.white, size: 52),
                    ]),
                    const SizedBox(height: 16),
                    Text('${_weather!.temperature.toStringAsFixed(1)}°C', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                    Text('Feels like ${_weather!.feelsLike.toStringAsFixed(1)}°C', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(children: [
                      _WeatherStat(icon: Icons.water_drop_outlined, value: '${_weather!.humidity}%', label: 'Humidity'),
                      const SizedBox(width: 20),
                      _WeatherStat(icon: Icons.air, value: '${_weather!.windSpeed.toStringAsFixed(0)} km/h', label: 'Wind'),
                      const SizedBox(width: 20),
                      _WeatherStat(icon: Icons.umbrella_outlined, value: '${_weather!.rainChance}%', label: 'Rain'),
                    ]),
                  ]),
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _alertColor(_weather!.alertLevel).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _alertColor(_weather!.alertLevel).withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(_weather!.alertLevel == 'safe' ? Icons.check_circle : Icons.warning_amber_rounded, color: _alertColor(_weather!.alertLevel), size: 24),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_weather!.alertMessage, style: TextStyle(color: _alertColor(_weather!.alertLevel), fontWeight: FontWeight.w600, fontSize: 13, height: 1.4))),
                  ]),
                ),

                if (_weather!.forecast.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('5-Day Forecast', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _weather!.forecast.map((f) => _ForecastItem(day: f.day, icon: f.emoji, high: f.high, low: f.low, rain: '${f.rainChance}%', tp: tp, ts: ts)).toList(),
                    ),
                  ),
                ],
              ],

            const SizedBox(height: 24),

            // ---------------- TRAFFIC ----------------
            Row(children: [
              Text('Traffic Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
              if (_traffic != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _trafficLevelColor(_traffic!.level).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(_traffic!.level, style: TextStyle(color: _trafficLevelColor(_traffic!.level), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
            const SizedBox(height: 10),

            if (_noActiveTrip)
              _InfoCard(icon: Icons.route_outlined, message: 'Start a trip to see live traffic alerts for your selected route.', card: card, tp: tp, ts: ts)
            else if (_trafficLoading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8))))
            else if (_trafficError != null)
                _ErrorCard(message: _trafficError!, card: card, tp: tp, ts: ts, onRetry: _loadTraffic)
              else if (_traffic != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _trafficLevelColor(_traffic!.level).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _trafficLevelColor(_traffic!.level).withValues(alpha: 0.3)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(_trafficLevelIcon(_traffic!.level), color: _trafficLevelColor(_traffic!.level), size: 24),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                          _trafficMessage(_traffic!, _trafficHotspotName),
                          style: TextStyle(color: _trafficLevelColor(_traffic!.level), fontWeight: FontWeight.w600, fontSize: 13, height: 1.4))),
                    ]),
                  ),
                  if (_traffic!.incidents.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ..._traffic!.incidents.map((i) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: card, borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                        border: Border(left: BorderSide(color: _severityColor(i.severity), width: 4)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: _severityColor(i.severity).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Icon(_incidentIcon(i.type), color: _severityColor(i.severity), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.type, style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(i.description, style: TextStyle(fontSize: 12, color: ts, height: 1.4)),
                        ])),
                      ]),
                    )),
                  ],
                ],

            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}

class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _WeatherStat({required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: Colors.white70, size: 16),
    const SizedBox(width: 4),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ]),
  ]);
}

class _ForecastItem extends StatelessWidget {
  final String day, icon, rain;
  final int high, low;
  final Color tp, ts;
  const _ForecastItem({required this.day, required this.icon, required this.rain, required this.high, required this.low, required this.tp, required this.ts});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(day, style: TextStyle(fontSize: 11, color: ts, fontWeight: FontWeight.w500)),
    const SizedBox(height: 4),
    Text(icon, style: const TextStyle(fontSize: 22)),
    const SizedBox(height: 4),
    Text('$high°', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 13)),
    Text('$low°', style: TextStyle(color: ts, fontSize: 11)),
    const SizedBox(height: 2),
    Text(rain, style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 10)),
  ]);
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Color card, tp, ts;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.card, required this.tp, required this.ts, required this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
    child: Column(children: [
      Icon(Icons.cloud_off_rounded, color: ts, size: 32),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: TextStyle(color: tp, fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
    ]),
  );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color card, tp, ts;
  const _InfoCard({required this.icon, required this.message, required this.card, required this.tp, required this.ts});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
    child: Column(children: [
      Icon(icon, color: ts, size: 32),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: TextStyle(color: ts, fontSize: 13, height: 1.4)),
    ]),
  );
}