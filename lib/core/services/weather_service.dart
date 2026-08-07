import 'dart:convert';
import 'package:http/http.dart' as http;

/// Weather via Open-Meteo (https://open-meteo.com) — completely free,
/// no API key required, so this works out of the box for every user.
class DailyForecast {
  final String day;   // 'Mon', 'Tue', ...
  final int high, low;
  final int rainChance;
  final String emoji;
  DailyForecast({required this.day, required this.high, required this.low, required this.rainChance, required this.emoji});
}

class WeatherData {
  final String city;
  final String condition;      // Clear, Clouds, Rain, Thunderstorm, Snow, Fog
  final String description;    // human-readable e.g. "light rain"
  final double temperature;    // °C
  final double feelsLike;      // °C
  final int humidity;          // %
  final double windSpeed;      // km/h
  final int rainChance;        // % chance of precipitation
  final bool isRaining;
  final bool isFoggy;
  final bool isStormy;
  final List<DailyForecast> forecast;

  WeatherData({
    required this.city,
    required this.condition,
    required this.description,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.rainChance,
    this.isRaining = false,
    this.isFoggy = false,
    this.isStormy = false,
    this.forecast = const [],
  });

  String get alertLevel {
    if (isStormy) return 'danger';
    if (isRaining && windSpeed > 20) return 'warning';
    if (isRaining || isFoggy) return 'caution';
    return 'safe';
  }

  String get alertMessage {
    if (isStormy) return '⛈️ Storm Alert! Avoid travelling if possible.';
    if (isRaining && windSpeed > 20) return '🌧️ Heavy rain & strong winds. Drive carefully.';
    if (isRaining) return '🌦️ Rain expected ($rainChance% chance). Carry an umbrella.';
    if (isFoggy) return '🌫️ Foggy conditions. Reduce speed & use headlights.';
    return '✅ Weather is clear. Safe to travel!';
  }

  // Maps Open-Meteo's WMO weather codes to a condition + description.
  // https://open-meteo.com/en/docs (WMO Weather interpretation codes)
  static ({String condition, String description, bool rain, bool fog, bool storm}) _fromCode(int code) {
    if (code == 0) return (condition: 'Clear', description: 'clear sky', rain: false, fog: false, storm: false);
    if (code <= 3) return (condition: 'Clouds', description: 'partly cloudy', rain: false, fog: false, storm: false);
    if (code == 45 || code == 48) return (condition: 'Fog', description: 'foggy', rain: false, fog: true, storm: false);
    if (code >= 51 && code <= 57) return (condition: 'Drizzle', description: 'light drizzle', rain: true, fog: false, storm: false);
    if (code >= 61 && code <= 67) return (condition: 'Rain', description: 'rain', rain: true, fog: false, storm: false);
    if (code >= 71 && code <= 77) return (condition: 'Snow', description: 'snow', rain: false, fog: false, storm: false);
    if (code >= 80 && code <= 82) return (condition: 'Rain', description: 'rain showers', rain: true, fog: false, storm: false);
    if (code == 85 || code == 86) return (condition: 'Snow', description: 'snow showers', rain: false, fog: false, storm: false);
    if (code >= 95) return (condition: 'Thunderstorm', description: 'thunderstorm', rain: true, fog: false, storm: true);
    return (condition: 'Clouds', description: 'cloudy', rain: false, fog: false, storm: false);
  }

  factory WeatherData.fromOpenMeteo({
    required Map<String, dynamic> current,
    required Map<String, dynamic>? hourly,
    required Map<String, dynamic>? daily,
    required String city,
  }) {
    final code = (current['weather_code'] as num?)?.toInt() ?? 0;
    final c = _fromCode(code);

    int rainChance = 0;
    if (hourly != null) {
      final times = List<String>.from(hourly['time'] ?? const []);
      final probs = List<num>.from(hourly['precipitation_probability'] ?? const []);
      final nowTime = current['time'] as String?;
      final idx = nowTime != null ? times.indexOf(nowTime) : -1;
      if (idx != -1 && idx < probs.length) {
        rainChance = probs[idx].toInt();
      } else if (probs.isNotEmpty) {
        rainChance = probs.first.toInt();
      }
    }

    final forecast = <DailyForecast>[];
    if (daily != null) {
      final dates = List<String>.from(daily['time'] ?? const []);
      final codes = List<num>.from(daily['weather_code'] ?? const []);
      final highs = List<num>.from(daily['temperature_2m_max'] ?? const []);
      final lows = List<num>.from(daily['temperature_2m_min'] ?? const []);
      final rains = List<num>.from(daily['precipitation_probability_max'] ?? const []);
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (var i = 0; i < dates.length; i++) {
        final date = DateTime.tryParse(dates[i]);
        final dayLabel = i == 0 ? 'Today' : (date != null ? weekdays[date.weekday - 1] : dates[i]);
        final dc = _fromCode(codes[i].toInt());
        forecast.add(DailyForecast(
          day: dayLabel,
          high: highs[i].round(),
          low: lows[i].round(),
          rainChance: i < rains.length ? rains[i].toInt() : 0,
          emoji: dc.storm ? '⛈️' : dc.rain ? '🌧️' : dc.fog ? '🌫️' : dc.condition == 'Clear' ? '☀️' : '☁️',
        ));
      }
    }

    return WeatherData(
      city: city,
      condition: c.condition,
      description: c.description,
      temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      feelsLike: (current['apparent_temperature'] as num?)?.toDouble() ?? 0,
      humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      rainChance: rainChance,
      isRaining: c.rain,
      isFoggy: c.fog,
      isStormy: c.storm,
      forecast: forecast,
    );
  }
}

class WeatherService {
  static const String _forecastUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String _geocodeUrl = 'https://geocoding-api.open-meteo.com/v1/search';

  // Real-time weather for a lat/lng. Returns null (never dummy data) if
  // the request fails — the caller shows "Weather data currently
  // unavailable" with a retry option.
  Future<WeatherData?> getWeather({required double lat, required double lng, String? cityName}) async {
    try {
      final url = Uri.parse(
        '$_forecastUrl?latitude=$lat&longitude=$lng'
            '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m'
            '&hourly=precipitation_probability'
            '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max'
            '&forecast_days=5&timezone=auto',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      return WeatherData.fromOpenMeteo(
        current: json['current'],
        hourly: json['hourly'],
        daily: json['daily'],
        city: cityName ?? 'Current location',
      );
    } catch (e) {
      return null;
    }
  }

  // City name -> coordinates, via Open-Meteo's free geocoding API
  // (separate from the routing/place-search GeocodingService used
  // elsewhere in the app for trip locations).
  Future<({double lat, double lng, String name})?> geocodeCity(String city) async {
    try {
      final url = Uri.parse('$_geocodeUrl?name=${Uri.encodeComponent(city)}&count=1&language=en&format=json');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      final results = json['results'] as List?;
      if (results == null || results.isEmpty) return null;
      final r = results.first;
      final name = [r['name'], r['admin1'], r['country']].where((e) => e != null).join(', ');
      return (lat: (r['latitude'] as num).toDouble(), lng: (r['longitude'] as num).toDouble(), name: name);
    } catch (e) {
      return null;
    }
  }
}