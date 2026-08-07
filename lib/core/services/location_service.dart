import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/location_model.dart';

// Classifies why the last permission/location check failed, so the UI can
// decide *what action to offer* (open device location settings vs open the
// app's own permission settings) instead of just showing a message the
// user has to act on manually.
enum LocationFailureReason {
  none,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  other,
}

class LocationService {
  // Turns a Firestore failure into a message that actually points at the
  // cause, instead of the generic (and often wrong) "check your internet
  // connection" — a permission-denied write, for example, has nothing to
  // do with connectivity and was previously indistinguishable from one.
  String _describeFirestoreError(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Firestore security rules are blocking this write. Check the rules for the "locations" collection in the Firebase console.';
        case 'unavailable':
          return 'Could not reach Firestore. Check your internet connection and try again.';
        case 'not-found':
          return 'Firestore database not found for this project. Make sure Firestore is created (enabled) in the Firebase console.';
        case 'unauthenticated':
          return 'You are not signed in. Please log in again.';
        default:
          return 'Firestore error (${e.code}): ${e.message ?? "unknown error"}.';
      }
    }
    return 'Unexpected error saving to Firestore: $e';
  }

  // Lazily resolved — never touched at construction time, so creating a
  // LocationService (e.g. from GuardianAiService or SosService) never
  // crashes even if Firebase.initializeApp() hasn't run yet / failed.
  FirebaseFirestore? _dbInstance;
  bool _firestoreUnavailable = false;

  // Human-readable reason the last getCurrentPosition()/checkPermission()
  // call failed, so the UI can show something more useful than a generic
  // "couldn't get location" message.
  String? lastErrorMessage;

  // Companion to lastErrorMessage — tells the UI whether a "Settings"
  // action button should be offered, and which settings screen it should
  // open. Defaults to `other` (no actionable redirect) until a specific
  // known case sets it.
  LocationFailureReason lastErrorReason = LocationFailureReason.none;

  // Opens the device's system location (GPS) settings screen so the user
  // can flip location on without leaving the app to hunt for it manually.
  // Returns false if the platform doesn't support it (e.g. web) or the
  // call fails for any reason.
  Future<bool> openDeviceLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  // Opens this app's own settings page (Android: App Info > Permissions,
  // iOS: Settings > SecureRide) — needed once permission is "denied
  // forever", since requestPermission() will no longer show the system
  // dialog at that point and the only way to grant it is from there.
  Future<bool> openAppPermissionSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore? get _db {
    if (_firestoreUnavailable) return null;
    try {
      return _dbInstance ??= FirebaseFirestore.instance;
    } catch (_) {
      _firestoreUnavailable = true;
      return null;
    }
  }

  // Check and request location permission
  Future<bool> checkPermission() async {
    lastErrorReason = LocationFailureReason.none;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        lastErrorMessage = 'Location is turned off on your phone.';
        lastErrorReason = LocationFailureReason.serviceDisabled;
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          lastErrorMessage = 'Location permission denied. Please allow location access for SecureRide.';
          lastErrorReason = LocationFailureReason.permissionDenied;
          return false;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        lastErrorMessage = 'Location permission is blocked for SecureRide. Enable it from App Settings.';
        lastErrorReason = LocationFailureReason.permissionDeniedForever;
        return false;
      }
      return true;
    } catch (e) {
      // On web this can throw a raw browser/plugin error (e.g. the site
      // was previously blocked, or the permission API isn't available)
      // instead of returning deniedForever — without this catch that
      // exception would propagate all the way up and the toggle would
      // silently fail with no visible feedback at all.
      lastErrorMessage = 'Could not check location permission. If you\'re on the browser, check the site settings (padlock icon next to the address bar) and allow Location.';
      lastErrorReason = LocationFailureReason.other;
      return false;
    }
  }

  // Fast path: the device's cached last-known fix, near-instant (no GPS
  // wait). Used to paint the screen immediately while a fresh accurate
  // fix is still being obtained in the background.
  Future<Position?> getLastKnownPosition() async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) return null;
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  // Get current position
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 6),
      );
    } catch (_) {
      // High-accuracy GPS fix can time out indoors / with a weak signal.
      // Fall back to the device's last known fix rather than failing
      // outright — it's usually close enough for "share my location".
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) return lastKnown;
      } catch (_) {
        // ignore, fall through to the medium-accuracy retry below
      }

      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (_) {
        lastErrorMessage = 'Could not get a GPS fix. Move to an open area (near a window/outdoors) and try again.';
        return null;
      }
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
    final db = _db;
    if (db == null) return false;
    try {
      await db.collection('locations').doc(uid).set({
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
      lastErrorMessage = _describeFirestoreError(e);
      return false;
    }
  }

  // Read the sharing status currently stored on the backend for this user.
  // Used to reconcile local/persisted toggle state with the source of
  // truth on app start (e.g. the app was killed mid-write, or sharing
  // was stopped from another device) instead of trusting local state blindly.
  // Returns null if the doc doesn't exist or Firestore is unreachable —
  // callers should fall back to locally persisted state in that case.
  Future<Map<String, dynamic>?> fetchSharingStatus(String uid) async {
    final db = _db;
    if (db == null) return null;
    try {
      final snap = await db.collection('locations').doc(uid).get();
      if (!snap.exists) return null;
      return snap.data();
    } catch (_) {
      return null;
    }
  }

  // Stop sharing location
  Future<bool> stopSharing(String uid) async {
    final db = _db;
    if (db == null) return false;
    try {
      await db.collection('locations').doc(uid).update({
        'isSharing': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      lastErrorMessage = _describeFirestoreError(e);
      return false;
    }
  }

  // Get shared locations of approved contacts
  Stream<List<LocationModel>> approvedContactsLocationStream(
      List<String> approvedEmails) {
    if (approvedEmails.isEmpty) {
      return Stream.value([]);
    }
    final db = _db;
    if (db == null) return Stream.value([]);
    return db
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
    final db = _db;
    if (db == null) return Stream.value([]);
    return db
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