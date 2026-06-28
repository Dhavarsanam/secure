import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String uid;
  final String userName;
  final String userEmail;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final String? tripId;
  final bool isSharing;
  final DateTime timestamp;

  LocationModel({
    required this.uid,
    required this.userName,
    required this.userEmail,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.tripId,
    this.isSharing = true,
    required this.timestamp,
  });

  factory LocationModel.fromMap(Map<String, dynamic> map, String uid) {
    return LocationModel(
      uid: uid,
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      accuracy: map['accuracy']?.toDouble(),
      speed: map['speed']?.toDouble(),
      heading: map['heading']?.toDouble(),
      tripId: map['tripId'],
      isSharing: map['isSharing'] ?? true,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'userName': userName,
      'userEmail': userEmail,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'tripId': tripId,
      'isSharing': isSharing,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  LocationModel copyWith({
    String? uid,
    String? userName,
    String? userEmail,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? speed,
    double? heading,
    String? tripId,
    bool? isSharing,
    DateTime? timestamp,
  }) {
    return LocationModel(
      uid: uid ?? this.uid,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      tripId: tripId ?? this.tripId,
      isSharing: isSharing ?? this.isSharing,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'LocationModel(uid: $uid, lat: $latitude, lng: $longitude, sharing: $isSharing)';
  }
}
