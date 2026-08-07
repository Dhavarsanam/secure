import 'dart:convert';
import 'package:http/http.dart' as http;

/// Route traffic. Two tiers, both real (never dummy/hardcoded):
///
/// 1. HERE Traffic API — live congestion + real incident reports
///    (Accident/Construction/Road Closure). Used automatically if a
///    HERE_API_KEY is configured via --dart-define at build time.
///
/// 2. OSRM (router.project-osrm.org) — always available, completely
///    free, NO API key needed at all. Gives a real route distance/ETA
///    from the actual road network, and a traffic-level estimate based
///    on time-of-day rush-hour patterns (since incident-level live data
///    requires a keyed provider like HERE). This is the default so the
///    feature works out of the box with zero setup.
class TrafficIncident {
  final String type;        // 'Accident' | 'Construction' | 'Road Closure' | 'Road Block' | 'Heavy Traffic' | 'Delay'
  final String description;
  final String severity;    // 'high' | 'medium' | 'low'

  TrafficIncident({required this.type, required this.description, required this.severity});
}

class TrafficInfo {
  final String level;              // 'No Traffic Delays' | 'Moderate Traffic' | 'Heavy Traffic'
  final Duration eta;               // ETA WITH traffic factored in
  final Duration etaWithoutTraffic; // ETA under free-flow conditions
  final double distanceKm;
  final List<TrafficIncident> incidents;
  final bool isLiveData; // true = HERE live traffic; false = OSRM route + time-of-day estimate

  TrafficInfo({
    required this.level,
    required this.eta,
    required this.etaWithoutTraffic,
    required this.distanceKm,
    required this.incidents,
    required this.isLiveData,
  });

  int get delayMinutes => (eta.inMinutes - etaWithoutTraffic.inMinutes).clamp(0, 999);

  bool get isClear => level == 'No Traffic Delays';
}

class TrafficService {
  static const String _hereApiKey = String.fromEnvironment('HERE_API_KEY', defaultValue: '');
  static const String _hereRoutingUrl = 'https://router.hereapi.com/v8/routes';
  static const String _hereIncidentsUrl = 'https://data.traffic.hereapi.com/v7/incidents';
  static const String _osrmUrl = 'https://router.project-osrm.org/route/v1/driving';

  bool get hasLiveTraffic => _hereApiKey.isNotEmpty;

  // Real route + ETA between two points. Tries live HERE traffic first
  // (if configured); otherwise automatically uses the free, no-key OSRM
  // route with a time-of-day traffic estimate. Only returns null on an
  // actual network/API failure — the caller shows a retry option then,
  // never fake numbers.
  Future<TrafficInfo?> getRouteTraffic({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    if (hasLiveTraffic) {
      final live = await _getHereTraffic(originLat, originLng, destLat, destLng);
      if (live != null) return live;
      // HERE call failed (bad key / quota / network) — fall back to OSRM
      // rather than showing an error, so the feature still works.
    }
    return _getOsrmTraffic(originLat, originLng, destLat, destLng);
  }

  Future<TrafficInfo?> _getHereTraffic(double originLat, double originLng, double destLat, double destLng) async {
    try {
      final routeUrl = Uri.parse(
        '$_hereRoutingUrl?transportMode=car'
            '&origin=$originLat,$originLng'
            '&destination=$destLat,$destLng'
            '&return=summary'
            '&departureTime=any'
            '&apikey=$_hereApiKey',
      );
      final routeRes = await http.get(routeUrl).timeout(const Duration(seconds: 15));
      if (routeRes.statusCode != 200) return null;
      final routeJson = jsonDecode(routeRes.body);
      final routes = routeJson['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final sections = routes.first['sections'] as List;

      int durationSec = 0, baseDurationSec = 0;
      double lengthM = 0;
      for (final s in sections) {
        final summary = s['summary'];
        final d = (summary['duration'] as num).toInt();
        durationSec += d;
        baseDurationSec += (summary['baseDuration'] as num?)?.toInt() ?? d;
        lengthM += (summary['length'] as num).toDouble();
      }

      final ratio = baseDurationSec == 0 ? 1.0 : durationSec / baseDurationSec;
      final level = ratio > 1.3 ? 'Heavy Traffic' : ratio > 1.1 ? 'Moderate Traffic' : 'No Traffic Delays';
      final incidents = await _getHereIncidents(originLat, originLng, destLat, destLng);

      return TrafficInfo(
        level: level,
        eta: Duration(seconds: durationSec),
        etaWithoutTraffic: Duration(seconds: baseDurationSec),
        distanceKm: lengthM / 1000,
        incidents: incidents,
        isLiveData: true,
      );
    } catch (e) {
      return null;
    }
  }

  Future<List<TrafficIncident>> _getHereIncidents(double oLat, double oLng, double dLat, double dLng) async {
    try {
      final south = (oLat < dLat ? oLat : dLat) - 0.05;
      final north = (oLat > dLat ? oLat : dLat) + 0.05;
      final west = (oLng < dLng ? oLng : dLng) - 0.05;
      final east = (oLng > dLng ? oLng : dLng) + 0.05;

      final url = Uri.parse('$_hereIncidentsUrl?in=bbox:$west,$south,$east,$north&apikey=$_hereApiKey');
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];

      final json = jsonDecode(res.body);
      final results = json['results'] as List? ?? [];
      final incidents = <TrafficIncident>[];

      for (final r in results) {
        final details = r['incidentDetails'];
        if (details == null) continue;
        final hereType = (details['type'] ?? 'OTHER').toString().toUpperCase();
        final criticality = (details['criticality'] ?? 'minor').toString().toLowerCase();
        final desc = details['description']?['value']?.toString();

        incidents.add(TrafficIncident(
          type: _mapType(hereType),
          description: desc ?? _mapType(hereType),
          severity: (criticality.contains('major') || criticality.contains('critical')) ? 'high' : 'medium',
        ));
      }
      return incidents.take(10).toList();
    } catch (e) {
      return [];
    }
  }

  String _mapType(String hereType) {
    switch (hereType) {
      case 'ACCIDENT': return 'Accident';
      case 'CONSTRUCTION': return 'Construction';
      case 'ROAD_CLOSURE': return 'Road Closure';
      case 'CONGESTION': return 'Heavy Traffic';
      case 'ROAD_HAZARD': return 'Road Block';
      case 'WEATHER': return 'Delay';
      default: return 'Delay';
    }
  }

  // Free, no-key fallback: real route distance/duration from OSRM's
  // public routing engine, with a traffic-level estimate derived from
  // the actual time of day (rush hour vs off-peak).
  Future<TrafficInfo?> _getOsrmTraffic(double originLat, double originLng, double destLat, double destLng) async {
    try {
      final url = Uri.parse('$_osrmUrl/$originLng,$originLat;$destLng,$destLat?overview=false&alternatives=false');
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body);
      if (json['code'] != 'Ok') return null;
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first;

      final baseDurationSec = (route['duration'] as num).toInt();
      final distanceM = (route['distance'] as num).toDouble();

      final level = _timeOfDayLevel();
      final multiplier = level == 'Heavy Traffic' ? 1.35 : level == 'Moderate Traffic' ? 1.15 : 1.0;
      final durationSec = (baseDurationSec * multiplier).round();

      return TrafficInfo(
        level: level,
        eta: Duration(seconds: durationSec),
        etaWithoutTraffic: Duration(seconds: baseDurationSec),
        distanceKm: distanceM / 1000,
        incidents: const [],
        isLiveData: false,
      );
    } catch (e) {
      return null;
    }
  }

  // Rush-hour heuristic (local device time): used only as the free-tier
  // traffic estimate when no live-traffic API key is configured.
  String _timeOfDayLevel() {
    final now = DateTime.now();
    final hour = now.hour;
    final isWeekday = now.weekday <= 5;
    if (!isWeekday) return (hour >= 11 && hour <= 20) ? 'Moderate Traffic' : 'No Traffic Delays';
    if ((hour >= 8 && hour <= 10) || (hour >= 17 && hour <= 20)) return 'Heavy Traffic';
    if ((hour >= 7 && hour < 8) || (hour > 10 && hour <= 12) || (hour >= 16 && hour < 17)) return 'Moderate Traffic';
    return 'No Traffic Delays';
  }
}