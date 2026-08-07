/// A small, curated dataset of well-known Madurai localities with their
/// real coordinates. Used to power fast, offline-style location suggestions
/// for the Create Trip screen (no network call, no long dropdown — just the
/// closest 2–3 matching places as the user types).
///
/// Coordinates are the accepted lat/lng for each locality/landmark and are
/// what get saved on the trip, so Traffic, Weather and Route features work
/// off real Madurai coordinates.
class MaduraiPlace {
  final String name;
  final double lat;
  final double lng;

  const MaduraiPlace(this.name, this.lat, this.lng);
}

const List<MaduraiPlace> maduraiPlaces = [
  MaduraiPlace('Madurai Junction', 9.9174, 78.1195),
  MaduraiPlace('Periyar Bus Stand', 9.9159, 78.1112),
  MaduraiPlace('Mattuthavani (MGR Bus Stand)', 9.9450, 78.1557),
  MaduraiPlace('Arapalayam Bus Stand', 9.9280, 78.0975),
  MaduraiPlace('Goripalayam', 9.9330, 78.1290),
  MaduraiPlace('Simmakkal', 9.9227, 78.1235),
  MaduraiPlace('Anna Nagar', 9.9350, 78.1180),
  MaduraiPlace('Yanaikkal', 9.9236, 78.1235),
  MaduraiPlace('Tallakulam', 9.9300, 78.1280),
  MaduraiPlace('Alwarpuram', 9.9286, 78.1351),
  MaduraiPlace('Sellur', 9.9280, 78.1350),
  MaduraiPlace('Jaihindpuram', 9.9051, 78.1078),
  MaduraiPlace('Vasantha Nagar', 9.9075, 78.0999),
  MaduraiPlace('Madakulam', 9.9161, 78.0900),
  MaduraiPlace('Palanganatham', 9.9080, 78.0870),
  MaduraiPlace('K K Nagar', 9.9430, 78.1350),
  MaduraiPlace('K Pudur', 9.8990, 78.1150),
  MaduraiPlace('S S Colony', 9.9370, 78.1050),
  MaduraiPlace('Narimedu', 9.9310, 78.1130),
  MaduraiPlace('Koodal Nagar', 9.9130, 78.0950),
  MaduraiPlace('Teppakulam', 9.9200, 78.1230),
  MaduraiPlace('Pasumalai', 9.8950, 78.0950),
  MaduraiPlace('Thiruparankundram', 9.8390, 78.0790),
  MaduraiPlace('Villapuram', 9.8950, 78.1450),
  MaduraiPlace('Chinthamani', 9.9160, 78.1170),
  MaduraiPlace('Meenakshi Amman Temple', 9.9195, 78.1193),
];

/// Returns the 2–3 best-matching places for [query], ranked so that names
/// starting with the query come before names that merely contain it.
List<MaduraiPlace> searchMaduraiPlaces(String query, {int limit = 3}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];

  final startsWith = <MaduraiPlace>[];
  final contains = <MaduraiPlace>[];

  for (final place in maduraiPlaces) {
    final name = place.name.toLowerCase();
    if (name.startsWith(q)) {
      startsWith.add(place);
    } else if (name.contains(q)) {
      contains.add(place);
    }
  }

  return [...startsWith, ...contains].take(limit).toList();
}

/// Returns the curated Madurai place closest to [lat]/[lng]. Used to turn a
/// raw route point (e.g. the midpoint between a trip's source and
/// destination) into a friendly, real, nearby area name — e.g. "Goripalayam"
/// — for traffic alert messages, without depending on a live network call.
MaduraiPlace nearestMaduraiPlace(double lat, double lng) {
  MaduraiPlace nearest = maduraiPlaces.first;
  double bestDistanceSq = double.infinity;

  for (final place in maduraiPlaces) {
    final dLat = lat - place.lat;
    final dLng = lng - place.lng;
    final distanceSq = dLat * dLat + dLng * dLng;
    if (distanceSq < bestDistanceSq) {
      bestDistanceSq = distanceSq;
      nearest = place;
    }
  }
  return nearest;
}