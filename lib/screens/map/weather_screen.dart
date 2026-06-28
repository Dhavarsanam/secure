import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/services/weather_service.dart';
import '../../utils/app_icon_colors.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _weatherService = WeatherService();
  WeatherData? _weatherData;
  List<TrafficAlert> _trafficAlerts = [];
  bool _isLoading = true;
  final _cityController = TextEditingController();

  // Dummy 5-day forecast
  final List<Map<String, dynamic>> _forecast = [
    {'day': 'Today', 'icon': '🌤️', 'high': 33, 'low': 26, 'rain': '10%'},
    {'day': 'Tue', 'icon': '🌧️', 'high': 30, 'low': 24, 'rain': '80%'},
    {'day': 'Wed', 'icon': '⛈️', 'high': 28, 'low': 23, 'rain': '90%'},
    {'day': 'Thu', 'icon': '🌦️', 'high': 31, 'low': 25, 'rain': '40%'},
    {'day': 'Fri', 'icon': '☀️', 'high': 34, 'low': 27, 'rain': '5%'},
  ];

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    setState(() => _isLoading = true);
    final location = context.read<LocationProvider>();
    final pos = location.positionOrDefault;
    final weather = await _weatherService.getWeather(lat: pos.latitude, lng: pos.longitude);
    final traffic = _weatherService.getDummyTrafficAlerts();
    setState(() {
      _weatherData = weather;
      _trafficAlerts = traffic;
      _isLoading = false;
    });
  }

  Future<void> _searchCity() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) return;
    setState(() => _isLoading = true);
    final weather = await _weatherService.getWeatherByCity(city);
    setState(() { _weatherData = weather; _isLoading = false; });
  }

  Color _alertColor(String level) {
    switch (level) {
      case 'danger': return const Color(0xFFDC2626);
      case 'warning': return const Color(0xFFF59E0B);
      case 'caution': return const Color(0xFF3B82F6);
      default: return const Color(0xFF22C55E);
    }
  }

  Color _trafficColor(String severity) {
    switch (severity) {
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
      default: return Icons.wb_cloudy_rounded;
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
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: appIconColor(Icons.refresh)), onPressed: _loadWeather),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8)))
          : RefreshIndicator(
        onRefresh: _loadWeather,
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

            // Main Weather Card
            if (_weatherData != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _weatherData!.isStormy
                        ? [const Color(0xFF374151), const Color(0xFF1F2937)]
                        : _weatherData!.isRaining
                        ? [const Color(0xFF1E3A5F), const Color(0xFF1A73E8)]
                        : [const Color(0xFF1A73E8), const Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF1A73E8).withValues(alpha: 0.3),
                    blurRadius: 20, offset: const Offset(0, 8),
                  )],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_weatherData!.city,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(_weatherData!.description.toUpperCase(),
                          style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1)),
                    ]),
                    const Spacer(),
                    Icon(_weatherIcon(_weatherData!.condition), color: Colors.white, size: 52),
                  ]),
                  const SizedBox(height: 16),
                  Text('${_weatherData!.temperature.toStringAsFixed(1)}°C',
                      style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                  Text('Feels like ${_weatherData!.feelsLike.toStringAsFixed(1)}°C',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(children: [
                    _WeatherStat(icon: Icons.water_drop_outlined, value: '${_weatherData!.humidity}%', label: 'Humidity'),
                    const SizedBox(width: 24),
                    _WeatherStat(icon: Icons.air, value: '${_weatherData!.windSpeed} m/s', label: 'Wind'),
                  ]),
                ]),
              ),

              const SizedBox(height: 12),

              // Safety Alert
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _alertColor(_weatherData!.alertLevel).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _alertColor(_weatherData!.alertLevel).withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(
                    _weatherData!.alertLevel == 'safe' ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: _alertColor(_weatherData!.alertLevel), size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_weatherData!.alertMessage,
                      style: TextStyle(color: _alertColor(_weatherData!.alertLevel),
                          fontWeight: FontWeight.w600, fontSize: 13, height: 1.4))),
                ]),
              ),

              const SizedBox(height: 20),

              // 5-Day Forecast
              Text('5-Day Forecast', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _forecast.map((f) => _ForecastItem(
                    day: f['day'], icon: f['icon'],
                    high: f['high'], low: f['low'], rain: f['rain'],
                    tp: tp, ts: ts,
                  )).toList(),
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
                child: Text('${_trafficAlerts.length} alerts',
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 10),

            ..._trafficAlerts.map((alert) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: card, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                border: Border(left: BorderSide(color: _trafficColor(alert.severity), width: 4)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _trafficColor(alert.severity).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    alert.type == 'accident' ? Icons.car_crash_rounded
                        : alert.type == 'construction' ? Icons.construction_rounded
                        : alert.type == 'congestion' ? Icons.traffic_rounded
                        : Icons.block_rounded,
                    color: _trafficColor(alert.severity), size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(alert.title, style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 14)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _trafficColor(alert.severity).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(alert.severity.toUpperCase(),
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _trafficColor(alert.severity))),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 12, color: appIconColor(Icons.location_on_outlined)),
                    const SizedBox(width: 2),
                    Text(alert.location, style: TextStyle(fontSize: 11, color: ts)),
                  ]),
                  const SizedBox(height: 4),
                  Text(alert.description, style: TextStyle(fontSize: 12, color: ts, height: 1.4)),
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

class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _WeatherStat({required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
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
