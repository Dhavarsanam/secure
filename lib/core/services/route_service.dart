import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;

  RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class RouteService {
  // Get free API key from: https://openrouteservice.org/
  static const String _apiKey = String.fromEnvironment(
    'ORS_API_KEY',
    defaultValue: 'YOUR_ORS_API_KEY',
  );

  static const String _baseUrl =
      'https://api.openrouteservice.org/v2/directions/driving-car';

  // Get route between two points
  Future<RouteResult?> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?api_key=$_apiKey'
            '&start=$startLng,$startLat'
            '&end=$endLng,$endLat',
      );

      final response = await http.get(
        url,
        headers: {'Accept': 'application/json, application/geo+json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseRouteResponse(data);
      }

      // If API key not set — return straight line fallback
      return _straightLineFallback(startLat, startLng, endLat, endLng);
    } catch (e) {
      // Network error — return straight line fallback
      return _straightLineFallback(startLat, startLng, endLat, endLng);
    }
  }

  // Parse ORS API response
  RouteResult? _parseRouteResponse(Map<String, dynamic> data) {
    try {
      final features = data['features'] as List;
      if (features.isEmpty) return null;

      final feature = features.first;
      final geometry = feature['geometry'];
      final coordinates = geometry['coordinates'] as List;
      final properties = feature['properties'];
      final summary = properties['summary'];

      final points = coordinates
          .map((coord) => LatLng(
        (coord[1] as num).toDouble(),
        (coord[0] as num).toDouble(),
      ))
          .toList();

      final distanceKm = (summary['distance'] as num).toDouble() / 1000;
      final durationMinutes = ((summary['duration'] as num) / 60).round();

      return RouteResult(
        points: points,
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
      );
    } catch (e) {
      return null;
    }
  }

  // Straight line fallback when API unavailable
  RouteResult _straightLineFallback(
      double startLat,
      double startLng,
      double endLat,
      double endLng,
      ) {
    final points = [
      LatLng(startLat, startLng),
      LatLng(endLat, endLng),
    ];

    // Approximate distance using Haversine
    final distance = const Distance();
    final distanceKm =
    distance.as(LengthUnit.Kilometer, points.first, points.last);
    final durationMinutes = (distanceKm / 40 * 60).round(); // 40 km/h avg

    return RouteResult(
      points: points,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
    );
  }

  // Convert RouteResult points to Firestore-storable format
  List<List<double>> pointsToList(List<LatLng> points) {
    return points.map((p) => [p.latitude, p.longitude]).toList();
  }

  // Convert Firestore list back to LatLng points
  List<LatLng> listToPoints(List<List<double>> list) {
    return list.map((p) => LatLng(p[0], p[1])).toList();
  }
}
