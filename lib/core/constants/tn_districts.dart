/// All 38 Tamil Nadu districts, at headquarters-town level, with real
/// coordinates. Companion dataset to `madurai_places.dart` — use this when a
/// search/selection needs to cover the whole state rather than just Madurai
/// city localities.
class TnDistrict {
  final String name;      // District headquarters town
  final String district;  // District name (same as name for most, differs for a few)
  final double lat;
  final double lng;

  const TnDistrict(this.name, this.district, this.lat, this.lng);
}

const List<TnDistrict> tnDistricts = [
  TnDistrict('Ariyalur', 'Ariyalur', 11.1401, 79.0782),
  TnDistrict('Chengalpattu', 'Chengalpattu', 12.6934, 79.9773),
  TnDistrict('Chennai', 'Chennai', 13.0827, 80.2707),
  TnDistrict('Coimbatore', 'Coimbatore', 11.0168, 76.9558),
  TnDistrict('Cuddalore', 'Cuddalore', 11.7480, 79.7714),
  TnDistrict('Dharmapuri', 'Dharmapuri', 12.1211, 78.1582),
  TnDistrict('Dindigul', 'Dindigul', 10.3624, 77.9695),
  TnDistrict('Erode', 'Erode', 11.3410, 77.7172),
  TnDistrict('Kallakurichi', 'Kallakurichi', 11.7401, 78.9597),
  TnDistrict('Kanchipuram', 'Kanchipuram', 12.8342, 79.7036),
  TnDistrict('Nagercoil', 'Kanyakumari', 8.1780, 77.4346),
  TnDistrict('Karur', 'Karur', 10.9601, 78.0766),
  TnDistrict('Krishnagiri', 'Krishnagiri', 12.5186, 78.2137),
  TnDistrict('Madurai', 'Madurai', 9.9252, 78.1198),
  TnDistrict('Mayiladuthurai', 'Mayiladuthurai', 11.1017, 79.6549),
  TnDistrict('Nagapattinam', 'Nagapattinam', 10.7672, 79.8449),
  TnDistrict('Namakkal', 'Namakkal', 11.2189, 78.1677),
  TnDistrict('Udhagamandalam (Ooty)', 'Nilgiris', 11.4102, 76.6950),
  TnDistrict('Perambalur', 'Perambalur', 11.2342, 78.8807),
  TnDistrict('Pudukkottai', 'Pudukkottai', 10.3813, 78.8213),
  TnDistrict('Ramanathapuram', 'Ramanathapuram', 9.3639, 78.8395),
  TnDistrict('Ranipet', 'Ranipet', 12.9249, 79.3308),
  TnDistrict('Salem', 'Salem', 11.6643, 78.1460),
  TnDistrict('Sivaganga', 'Sivaganga', 9.8433, 78.4809),
  TnDistrict('Tenkasi', 'Tenkasi', 8.9601, 77.3152),
  TnDistrict('Thanjavur', 'Thanjavur', 10.7870, 79.1378),
  TnDistrict('Theni', 'Theni', 10.0104, 77.4768),
  TnDistrict('Thoothukudi', 'Thoothukudi', 8.7642, 78.1348),
  TnDistrict('Tiruchirappalli', 'Tiruchirappalli', 10.7905, 78.7047),
  TnDistrict('Tirunelveli', 'Tirunelveli', 8.7139, 77.7567),
  TnDistrict('Tirupattur', 'Tirupattur', 12.4950, 78.5732),
  TnDistrict('Tiruppur', 'Tiruppur', 11.1085, 77.3411),
  TnDistrict('Tiruvallur', 'Tiruvallur', 13.1439, 79.9083),
  TnDistrict('Tiruvannamalai', 'Tiruvannamalai', 12.2253, 79.0747),
  TnDistrict('Tiruvarur', 'Tiruvarur', 10.7661, 79.6345),
  TnDistrict('Vellore', 'Vellore', 12.9165, 79.1325),
  TnDistrict('Villupuram', 'Villupuram', 11.9401, 79.4861),
  TnDistrict('Virudhunagar', 'Virudhunagar', 9.5851, 77.9624),
];

/// Returns the 2–3 best-matching districts for [query] (matches on either
/// the headquarters town name or the district name), ranked so that
/// names starting with the query come before names that merely contain it.
List<TnDistrict> searchTnDistricts(String query, {int limit = 3}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];

  final startsWith = <TnDistrict>[];
  final contains = <TnDistrict>[];

  for (final d in tnDistricts) {
    final name = d.name.toLowerCase();
    final district = d.district.toLowerCase();
    if (name.startsWith(q) || district.startsWith(q)) {
      startsWith.add(d);
    } else if (name.contains(q) || district.contains(q)) {
      contains.add(d);
    }
  }

  return [...startsWith, ...contains].take(limit).toList();
}