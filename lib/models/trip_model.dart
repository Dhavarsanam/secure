import 'package:cloud_firestore/cloud_firestore.dart';

enum TripStatus { active, completed, cancelled }

class TripModel {
  final String tripId;
  final String tripCode; // 6-digit unique code to join
  final String creatorUid;
  final String creatorName;
  final String creatorEmail;

  // Locations
  final String startLocationName;
  final double startLat;
  final double startLng;
  final String destinationName;
  final double destinationLat;
  final double destinationLng;

  // Trip Details
  final DateTime travelDate;
  final String passengerType;
  final String vehicleType;
  final int availableSeats;
  final int bookedSeats;

  // Members
  final List<String> memberUids;
  final List<String> memberEmails;

  // Status
  final TripStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Route (polyline points as list of [lat, lng])
  final List<List<double>>? routePoints;
  final double? distanceKm;
  final int? durationMinutes;

  TripModel({
    required this.tripId,
    required this.tripCode,
    required this.creatorUid,
    required this.creatorName,
    required this.creatorEmail,
    required this.startLocationName,
    required this.startLat,
    required this.startLng,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
    required this.travelDate,
    required this.passengerType,
    required this.vehicleType,
    required this.availableSeats,
    this.bookedSeats = 0,
    this.memberUids = const [],
    this.memberEmails = const [],
    this.status = TripStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.routePoints,
    this.distanceKm,
    this.durationMinutes,
  });

  int get remainingSeats => availableSeats - bookedSeats;
  bool get isFull => remainingSeats <= 0;

  factory TripModel.fromMap(Map<String, dynamic> map, String tripId) {
    return TripModel(
      tripId: tripId,
      tripCode: map['tripCode'] ?? '',
      creatorUid: map['creatorUid'] ?? '',
      creatorName: map['creatorName'] ?? '',
      creatorEmail: map['creatorEmail'] ?? '',
      startLocationName: map['startLocationName'] ?? '',
      startLat: (map['startLat'] ?? 0.0).toDouble(),
      startLng: (map['startLng'] ?? 0.0).toDouble(),
      destinationName: map['destinationName'] ?? '',
      destinationLat: (map['destinationLat'] ?? 0.0).toDouble(),
      destinationLng: (map['destinationLng'] ?? 0.0).toDouble(),
      travelDate: (map['travelDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      passengerType: map['passengerType'] ?? 'Solo',
      vehicleType: map['vehicleType'] ?? 'Car',
      availableSeats: map['availableSeats'] ?? 1,
      bookedSeats: map['bookedSeats'] ?? 0,
      memberUids: List<String>.from(map['memberUids'] ?? []),
      memberEmails: List<String>.from(map['memberEmails'] ?? []),
      status: TripStatus.values.firstWhere(
            (e) => e.name == (map['status'] ?? 'active'),
        orElse: () => TripStatus.active,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      routePoints: map['routePoints'] != null
          ? (map['routePoints'] as List)
          .map((p) => List<double>.from(p))
          .toList()
          : null,
      distanceKm: (map['distanceKm'])?.toDouble(),
      durationMinutes: map['durationMinutes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tripCode': tripCode,
      'creatorUid': creatorUid,
      'creatorName': creatorName,
      'creatorEmail': creatorEmail,
      'startLocationName': startLocationName,
      'startLat': startLat,
      'startLng': startLng,
      'destinationName': destinationName,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'travelDate': Timestamp.fromDate(travelDate),
      'passengerType': passengerType,
      'vehicleType': vehicleType,
      'availableSeats': availableSeats,
      'bookedSeats': bookedSeats,
      'memberUids': memberUids,
      'memberEmails': memberEmails,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'routePoints': routePoints,
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
    };
  }

  TripModel copyWith({
    String? tripId,
    String? tripCode,
    String? creatorUid,
    String? creatorName,
    String? creatorEmail,
    String? startLocationName,
    double? startLat,
    double? startLng,
    String? destinationName,
    double? destinationLat,
    double? destinationLng,
    DateTime? travelDate,
    String? passengerType,
    String? vehicleType,
    int? availableSeats,
    int? bookedSeats,
    List<String>? memberUids,
    List<String>? memberEmails,
    TripStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<List<double>>? routePoints,
    double? distanceKm,
    int? durationMinutes,
  }) {
    return TripModel(
      tripId: tripId ?? this.tripId,
      tripCode: tripCode ?? this.tripCode,
      creatorUid: creatorUid ?? this.creatorUid,
      creatorName: creatorName ?? this.creatorName,
      creatorEmail: creatorEmail ?? this.creatorEmail,
      startLocationName: startLocationName ?? this.startLocationName,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      destinationName: destinationName ?? this.destinationName,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      travelDate: travelDate ?? this.travelDate,
      passengerType: passengerType ?? this.passengerType,
      vehicleType: vehicleType ?? this.vehicleType,
      availableSeats: availableSeats ?? this.availableSeats,
      bookedSeats: bookedSeats ?? this.bookedSeats,
      memberUids: memberUids ?? this.memberUids,
      memberEmails: memberEmails ?? this.memberEmails,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      routePoints: routePoints ?? this.routePoints,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}
