import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WeatherData {
  final String city;
  final String condition;
  final String description;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final String icon;
  final bool isRaining;
  final bool isFoggy;
  final bool isStormy;

  WeatherData({
    required this.city,
    required this.condition,
    required this.description,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.icon,
    this.isRaining = false,
    this.isFoggy = false,
    this.isStormy = false,
  });

  String get alertLevel {
    if (isStormy) return 'danger';
    if (isRaining && windSpeed > 10) return 'warning';
    if (isRaining || isFoggy) return 'caution';
    return 'safe';
  }

  String get alertMessage {
    if (isStormy) return '⛈️ Storm Alert! Avoid travelling if possible.';
    if (isRaining && windSpeed > 10) return '🌧️ Heavy rain & strong winds. Drive carefully.';
    if (isRaining) return '🌦️ Light rain expected. Carry an umbrella.';
    if (isFoggy) return '🌫️ Foggy conditions. Reduce speed & use headlights.';
    return '✅ Weather is clear. Safe to travel!';
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final weather = json['weather'][0];
    final main = json['main'];
    final wind = json['wind'];
    final conditionId = weather['id'] as int;
    return WeatherData(
      city: json['name'] ?? 'Unknown',
      condition: weather['main'] ?? '',
      description: weather['description'] ?? '',
      temperature: (main['temp'] as num).toDouble() - 273.15,
      feelsLike: (main['feels_like'] as num).toDouble() - 273.15,
      humidity: main['humidity'] as int,
      windSpeed: (wind['speed'] as num).toDouble(),
      icon: weather['icon'] ?? '01d',
      isRaining: conditionId >= 200 && conditionId < 700,
      isFoggy: conditionId >= 700 && conditionId < 800,
      isStormy: conditionId >= 200 && conditionId < 300,
    );
  }

  // Dummy — Madurai weather
  factory WeatherData.dummy() {
    return WeatherData(
      city: 'Madurai',
      condition: 'Clear',
      description: 'clear sky',
      temperature: 34.2,
      feelsLike: 38.0,
      humidity: 65,
      windSpeed: 3.5,
      icon: '01d',
      isRaining: false,
      isFoggy: false,
      isStormy: false,
    );
  }
}

class TrafficAlert {
  final String title;
  final String description;
  final String severity;
  final String location;
  final String type;

  TrafficAlert({
    required this.title,
    required this.description,
    required this.severity,
    required this.location,
    required this.type,
  });
}

class WeatherService {
  static const String _apiKey =
  String.fromEnvironment('WEATHER_API_KEY', defaultValue: '');
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  Future<WeatherData> getWeather({required double lat, required double lng}) async {
    if (_apiKey.isEmpty) return WeatherData.dummy();
    try {
      final url = Uri.parse('$_baseUrl/weather?lat=$lat&lon=$lng&appid=$_apiKey');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return WeatherData.fromJson(jsonDecode(response.body));
      return WeatherData.dummy();
    } catch (e) {
      return WeatherData.dummy();
    }
  }

  Future<WeatherData> getWeatherByCity(String city) async {
    if (_apiKey.isEmpty) return WeatherData.dummy();
    try {
      final url = Uri.parse('$_baseUrl/weather?q=$city&appid=$_apiKey');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return WeatherData.fromJson(jsonDecode(response.body));
      return WeatherData.dummy();
    } catch (e) {
      return WeatherData.dummy();
    }
  }

  // Dummy traffic alerts — Madurai locations
  List<TrafficAlert> getDummyTrafficAlerts() {
    return [
      TrafficAlert(
        title: 'Heavy Traffic',
        description: 'Severe congestion near Periyar Bus Stand. Expect 20-30 min delay.',
        severity: 'high',
        location: 'Periyar Bus Stand, Madurai',
        type: 'congestion',
      ),
      TrafficAlert(
        title: 'Road Construction',
        description: 'Lane closure on Bypass Road near Mattuthavani. Use alternate route.',
        severity: 'medium',
        location: 'Bypass Road, Madurai',
        type: 'construction',
      ),
      TrafficAlert(
        title: 'Minor Accident',
        description: 'Minor accident reported near Meenakshi Temple Junction. Right lane blocked.',
        severity: 'low',
        location: 'Meenakshi Temple Junction, Madurai',
        type: 'accident',
      ),
    ];
  }
}
