import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/trip_model.dart';
import '../../models/user_model.dart';
import '../../models/sos_alert_model.dart';
import '../../models/user_activity_model.dart';

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

  // Get trip by code — fetch by code ALONE. Previously this also filtered
  // status == 'active', so a valid code for a completed/cancelled trip
  // would wrongly come back as "not found" instead of showing that trip's
  // real status. Status is already handled correctly downstream (preview
  // card shows Active/Completed/Cancelled, join button disables itself).
  Future<TripModel?> getTripByCode(String tripCode) async {
    try {
      final query = await _db
          .collection('trips')
          .where('tripCode', isEqualTo: tripCode.toUpperCase())
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

  // Real, currently-open trips other users created — for the "Suggested
  // Trips" list on Join Trip. Excludes the current user's own trips and
  // trips they've already joined, and only includes ones with free seats.
  Stream<List<TripModel>> suggestedTripsStream(String uid, {int limit = 6}) {
    // Single-field filter only (no orderBy on a different field) so this
    // never needs a Firestore composite index — sort client-side instead.
    return _db
        .collection('trips')
        .where('status', isEqualTo: 'active')
        .limit(50)
        .snapshots()
        .map((snap) {
      final trips = snap.docs
          .map((doc) => TripModel.fromMap(doc.data(), doc.id))
          .where((t) =>
      t.creatorUid != uid &&
          !t.memberUids.contains(uid) &&
          (t.availableSeats - t.bookedSeats) > 0)
          .toList();
      trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return trips.take(limit).toList();
    });
  }

  // Real, currently-open trips other users created — one-shot fetch (not a
  // live stream) so the Join Trip screen can pick a random 4-5 to show and
  // keep that same set until the screen is re-opened, instead of the list
  // re-shuffling under the user's finger on every Firestore update.
  Future<List<TripModel>> getAvailableTripsForSuggestions(String uid, {int poolLimit = 50}) async {
    try {
      final snap = await _db
          .collection('trips')
          .where('status', isEqualTo: 'active')
          .limit(poolLimit)
          .get();
      return snap.docs
          .map((doc) => TripModel.fromMap(doc.data(), doc.id))
          .where((t) =>
      t.creatorUid != uid &&
          !t.memberUids.contains(uid) &&
          (t.availableSeats - t.bookedSeats) > 0)
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Join trip — fully atomic. The seat-availability check and the
  // bookedSeats increment happen inside a single Firestore transaction, so
  // two users tapping "Join" on the very last seat at the same instant can
  // never both succeed: Firestore retries the transaction on write
  // conflicts, so whichever one commits first sees the true seat count and
  // the other correctly sees the trip as full — no overbooking is possible.
  Future<Map<String, dynamic>> joinTrip(String tripId, String uid, String email) async {
    try {
      await _db.runTransaction((transaction) async {
        final docRef = _db.collection('trips').doc(tripId);
        final snap = await transaction.get(docRef);

        if (!snap.exists) {
          throw Exception('This trip no longer exists.');
        }
        final data = snap.data()!;

        if ((data['status'] ?? 'active') != 'active') {
          throw Exception('This trip is no longer active.');
        }

        final memberUids = List<String>.from(data['memberUids'] ?? []);
        if (memberUids.contains(uid)) {
          throw Exception('You already joined this trip.');
        }

        final availableSeats = (data['availableSeats'] ?? 0) as int;
        final bookedSeats = (data['bookedSeats'] ?? 0) as int;
        if (bookedSeats >= availableSeats) {
          throw Exception('This trip is already full.');
        }

        transaction.update(docRef, {
          'memberUids': FieldValue.arrayUnion([uid]),
          'memberEmails': FieldValue.arrayUnion([email]),
          'bookedSeats': bookedSeats + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
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

  // Live count of SOS alerts a user has triggered — used for the
  // real-time Safety Score's "SOS Discipline" factor.
  Stream<int> sosAlertCountStream(String uid) {
    return _db
        .collection('sos_alerts')
        .where('senderUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // Live list of a user's SOS alerts (full records) — feeds the
  // Notifications screen so SOS entries are real, not static demo data.
  Stream<List<SosAlertModel>> sosAlertsStream(String uid) {
    return _db
        .collection('sos_alerts')
        .where('senderUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SosAlertModel.fromMap(d.data(), d.id)).toList());
  }

  // ─── USER ACTIVITY (login / logout / live-location shared) ───
  // Written the instant each real event happens (see AuthProvider), so
  // the Notifications feed can render "Login Successfully", "Logout",
  // and "Live Location Shared" from actual backend records — never
  // static/dummy entries.

  Future<bool> logActivity(String uid, UserActivityType type) async {
    try {
      await _db.collection('user_activity').add({
        'uid': uid,
        'type': type.name,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Live list of a user's recent account/session activity — most recent
  // 20 is plenty for the notifications feed.
  Stream<List<UserActivityModel>> userActivityStream(String uid) {
    return _db
        .collection('user_activity')
        .where('uid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => UserActivityModel.fromMap(d.data(), d.id))
        .toList());
  }
}