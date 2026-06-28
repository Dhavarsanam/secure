import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/services/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _svc = WeatherService();
  WeatherData? _weather;
  List<TrafficAlert> _traffic = [];
  bool _loading = true;
  final _ctrl = TextEditingController();

  // Madurai 5-day forecast
  final List<Map<String, dynamic>> _forecast = [
    {'day': 'Today', 'icon': '☀️', 'high': 34, 'low': 26, 'rain': '5%'},
    {'day': 'Tue',   'icon': '🌤️', 'high': 33, 'low': 25, 'rain': '10%'},
    {'day': 'Wed',   'icon': '🌦️', 'high': 31, 'low': 24, 'rain': '40%'},
    {'day': 'Thu',   'icon': '🌧️', 'high': 29, 'low': 23, 'rain': '75%'},
    {'day': 'Fri',   'icon': '⛅', 'high': 32, 'low': 25, 'rain': '20%'},
  ];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Fathima College for Women, Madurai coordinates
    final w = await _svc.getWeather(lat: 9.9601, lng: 78.0766);
    setState(() {
      _weather = w;
      _traffic = _svc.getDummyTrafficAlerts();
      _loading = false;
    });
  }

  Future<void> _searchCity(String city) async {
    if (city.trim().isEmpty) return;
    setState(() => _loading = true);
    final w = await _svc.getWeatherByCity(city.trim());
    setState(() { _weather = w; _loading = false; });
  }

  Color _ac(String l) {
    switch (l) {
      case 'danger': return const Color(0xFFDC2626);
      case 'warning': return const Color(0xFFF59E0B);
      case 'caution': return const Color(0xFF3B82F6);
      default: return const Color(0xFF22C55E);
    }
  }

  Color _tc(String s) {
    switch (s) {
      case 'high': return const Color(0xFFDC2626);
      case 'medium': return const Color(0xFFF59E0B);
      default: return const Color(0xFF22C55E);
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
      case 'mist':
      case 'fog': return Icons.foggy;
      default: return Icons.wb_sunny_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        title: const Text('Weather & Traffic', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8)))
          : RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Search
            TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Search city...',
                hintStyle: TextStyle(color: ts),
                prefixIcon: Icon(Icons.search, color: ts),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF1A73E8)),
                  onPressed: () => _searchCity(_ctrl.text),
                ),
                filled: true, fillColor: card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: TextStyle(color: tp),
              onSubmitted: _searchCity,
            ),
            const SizedBox(height: 16),

            if (_weather != null) ...[
              // Main weather card
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
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_weather!.city, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(_weather!.description.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1)),
                    ]),
                    const Spacer(),
                    Icon(_weatherIcon(_weather!.condition), color: Colors.white, size: 52),
                  ]),
                  const SizedBox(height: 16),
                  Text('${_weather!.temperature.toStringAsFixed(1)}°C',
                      style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                  Text('Feels like ${_weather!.feelsLike.toStringAsFixed(1)}°C',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.water_drop_outlined, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text('${_weather!.humidity}% Humidity', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    const SizedBox(width: 20),
                    const Icon(Icons.air, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text('${_weather!.windSpeed} m/s Wind', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),

              // Safety alert
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _ac(_weather!.alertLevel).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _ac(_weather!.alertLevel).withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(_weather!.alertLevel == 'safe' ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: _ac(_weather!.alertLevel), size: 24),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_weather!.alertMessage,
                      style: TextStyle(color: _ac(_weather!.alertLevel), fontWeight: FontWeight.w600, fontSize: 13, height: 1.4))),
                ]),
              ),
              const SizedBox(height: 20),

              // 5-Day Forecast
              Text('5-Day Forecast', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _forecast.map((f) => Column(children: [
                    Text(f['day'], style: TextStyle(fontSize: 11, color: ts, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(f['icon'], style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text('${f['high']}°', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 13)),
                    Text('${f['low']}°', style: TextStyle(color: ts, fontSize: 11)),
                    Text(f['rain'], style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 10)),
                  ])).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Traffic Alerts
            Row(children: [
              Text('Traffic Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('${_traffic.length} alerts', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 10),

            ..._traffic.map((a) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: card, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                border: Border(left: BorderSide(color: _tc(a.severity), width: 4)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _tc(a.severity).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(
                      a.type == 'accident' ? Icons.car_crash_rounded
                          : a.type == 'construction' ? Icons.construction_rounded
                          : Icons.traffic_rounded,
                      color: _tc(a.severity), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(a.title, style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 14)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _tc(a.severity).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(a.severity.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _tc(a.severity))),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 12, color: ts),
                    const SizedBox(width: 2),
                    Expanded(child: Text(a.location, style: TextStyle(fontSize: 11, color: ts))),
                  ]),
                  const SizedBox(height: 4),
                  Text(a.description, style: TextStyle(fontSize: 12, color: ts, height: 1.4)),
                ])),
              ]),
            )),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}
