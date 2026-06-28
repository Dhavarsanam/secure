import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/trip_model.dart';
import '../../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── USER ───────────────────────────────────────────

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) return UserModel.fromMap(doc.data()!, uid);
      return null;
    } catch (e) {
      return null;
    }
  }

  Stream<UserModel?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) return UserModel.fromMap(doc.data()!, uid);
      return null;
    });
  }

  Future<bool> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _db.collection('users').doc(uid).update(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Add approved contact
  Future<bool> addApprovedContact(String uid, String contactEmail) async {
    try {
      await _db.collection('users').doc(uid).update({
        'approvedContacts': FieldValue.arrayUnion([contactEmail]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Remove approved contact
  Future<bool> removeApprovedContact(String uid, String contactEmail) async {
    try {
      await _db.collection('users').doc(uid).update({
        'approvedContacts': FieldValue.arrayRemove([contactEmail]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Check if email is registered user
  Future<bool> isRegisteredUser(String email) async {
    try {
      final query = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ─── TRIPS ───────────────────────────────────────────

  // Create trip
  Future<String?> createTrip(TripModel trip) async {
    try {
      final doc = await _db.collection('trips').add(trip.toMap());
      return doc.id;
    } catch (e) {
      return null;
    }
  }

  // Get trip by ID
  Future<TripModel?> getTrip(String tripId) async {
    try {
      final doc = await _db.collection('trips').doc(tripId).get();
      if (doc.exists) return TripModel.fromMap(doc.data()!, doc.id);
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get trip by code
  Future<TripModel?> getTripByCode(String tripCode) async {
    try {
      final query = await _db
          .collection('trips')
          .where('tripCode', isEqualTo: tripCode.toUpperCase())
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return TripModel.fromMap(query.docs.first.data(), query.docs.first.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get my trips (created + joined)
  Stream<List<TripModel>> myTripsStream(String uid) {
    return _db
        .collection('trips')
        .where('memberUids', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => TripModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Join trip
  Future<bool> joinTrip(String tripId, String uid, String email) async {
    try {
      await _db.collection('trips').doc(tripId).update({
        'memberUids': FieldValue.arrayUnion([uid]),
        'memberEmails': FieldValue.arrayUnion([email]),
        'bookedSeats': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update trip status
  Future<bool> updateTripStatus(String tripId, TripStatus status) async {
    try {
      await _db.collection('trips').doc(tripId).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update trip route
  Future<bool> updateTripRoute(
      String tripId, {
        required List<List<double>> routePoints,
        required double distanceKm,
        required int durationMinutes,
      }) async {
    try {
      await _db.collection('trips').doc(tripId).update({
        'routePoints': routePoints,
        'distanceKm': distanceKm,
        'durationMinutes': durationMinutes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── SOS ALERTS ──────────────────────────────────────

  Future<String?> createSosAlert(Map<String, dynamic> alertData) async {
    try {
      final doc = await _db.collection('sos_alerts').add(alertData);
      return doc.id;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateSosAlert(String alertId, Map<String, dynamic> data) async {
    try {
      await _db.collection('sos_alerts').doc(alertId).update(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resolveSosAlert(String alertId) async {
    try {
      await _db.collection('sos_alerts').doc(alertId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
