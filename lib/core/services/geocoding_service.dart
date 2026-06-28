import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceResult {
  final String displayName;
  final String shortName;
  final double lat;
  final double lng;

  PlaceResult({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lng,
  });
}

class GeocodingService {
  // Nominatim — free, no API key needed!
  static const String _nominatimUrl =
      'https://nominatim.openstreetmap.org';

  static const Map<String, String> _headers = {
    'User-Agent': 'SecureRide/1.0',
    'Accept-Language': 'en',
  };

  // Search places by query
  Future<List<PlaceResult>> searchPlaces(String query) async {
    if (query.trim().length < 3) return [];

    try {
      final url = Uri.parse(
        '$_nominatimUrl/search'
            '?q=${Uri.encodeComponent(query)}'
            '&format=json'
            '&limit=5'
            '&addressdetails=1',
      );

      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) {
          final address = item['address'] ?? {};
          final shortName = _buildShortName(address, item['display_name']);
          return PlaceResult(
            displayName: item['display_name'] ?? '',
            shortName: shortName,
            lat: double.parse(item['lat']),
            lng: double.parse(item['lon']),
          );
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Reverse geocoding — coordinates to address
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        '$_nominatimUrl/reverse'
            '?lat=$lat&lon=$lng'
            '&format=json'
            '&addressdetails=1',
      );

      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] ?? {};
        return _buildShortName(address, data['display_name']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get coordinates from place name
  Future<LatLng?> getCoordinates(String placeName) async {
    final results = await searchPlaces(placeName);
    if (results.isNotEmpty) {
      return LatLng(results.first.lat, results.first.lng);
    }
    return null;
  }

  // Build short readable name from address components
  String _buildShortName(Map address, String fallback) {
    final parts = <String>[];

    if (address['road'] != null) parts.add(address['road']);
    if (address['suburb'] != null) parts.add(address['suburb']);
    if (address['city'] != null) {
      parts.add(address['city']);
    } else if (address['town'] != null) {
      parts.add(address['town']);
    } else if (address['village'] != null) {
      parts.add(address['village']);
    }
    if (address['state'] != null) parts.add(address['state']);

    if (parts.isEmpty) {
      // Fallback — take first 2 parts of display name
      final split = fallback.split(',');
      return split.take(2).join(',').trim();
    }

    return parts.take(3).join(', ');
  }
}
