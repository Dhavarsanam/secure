import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/location_model.dart';

class LocationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Check and request location permission
  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  // Get current position
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      return null;
    }
  }

  // Stream live position updates
  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10 meters
      ),
    );
  }

  // Share location to Firestore
  Future<bool> shareLocation({
    required String uid,
    required String userName,
    required String userEmail,
    required Position position,
    String? tripId,
  }) async {
    try {
      await _db.collection('locations').doc(uid).set({
        'uid': uid,
        'userName': userName,
        'userEmail': userEmail,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'tripId': tripId,
        'isSharing': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Stop sharing location
  Future<bool> stopSharing(String uid) async {
    try {
      await _db.collection('locations').doc(uid).update({
        'isSharing': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get shared locations of approved contacts
  Stream<List<LocationModel>> approvedContactsLocationStream(
      List<String> approvedEmails) {
    if (approvedEmails.isEmpty) {
      return Stream.value([]);
    }
    return _db
        .collection('locations')
        .where('userEmail', whereIn: approvedEmails)
        .where('isSharing', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => LocationModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Get trip members locations
  Stream<List<LocationModel>> tripMembersLocationStream(
      List<String> memberUids) {
    if (memberUids.isEmpty) return Stream.value([]);
    return _db
        .collection('locations')
        .where('uid', whereIn: memberUids)
        .where('isSharing', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => LocationModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Calculate distance between two positions (in km)
  double calculateDistance(
      double startLat,
      double startLng,
      double endLat,
      double endLng,
      ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) /
        1000;
  }
}
