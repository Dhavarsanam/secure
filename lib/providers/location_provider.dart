import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';
import '../core/services/location_service.dart';
import '../core/services/geocoding_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final GeocodingService _geocodingService = GeocodingService();

  LatLng? _currentPosition;
  bool _isSharing = false;
  bool _isLoading = false;
  // True only while a startSharing() call is in flight — kept separate from
  // _isLoading (which also covers getCurrentLocation()) so the toggle's
  // spinner is driven by the provider itself, not local widget state, and
  // never appears while stopping/disabling.
  bool _isEnabling = false;
  List<LocationModel> _sharedLocations = [];
  String? _currentAddress;
  DateTime? _sharingStartedAt;

  static const _prefsSharingKey = 'location_sharing_active';
  static const _prefsSharingUidKey = 'location_sharing_uid';
  static const _prefsSharingStartedKey = 'location_sharing_started_at';

  LatLng? get currentPosition => _currentPosition;
  bool get isSharing => _isSharing;
  bool get isLoading => _isLoading;
  bool get isEnabling => _isEnabling;
  List<LocationModel> get sharedLocations => _sharedLocations;
  String? get currentAddress => _currentAddress;
  DateTime? get sharingStartedAt => _sharingStartedAt;

  // Specific reason the last startSharing()/stopSharing() call failed (GPS
  // off, permission denied, weak signal, Firestore write failed, etc.) —
  // set right before the call returns false. UI reads this instead of
  // showing one generic message for every failure.
  String? get lastError => _locationService.lastErrorMessage;

  // Which settings screen (if any) the UI should offer to open for the
  // last failure — device location settings, this app's permission
  // settings, or nothing actionable.
  LocationFailureReason get lastErrorReason => _locationService.lastErrorReason;

  Future<bool> openDeviceLocationSettings() => _locationService.openDeviceLocationSettings();
  Future<bool> openAppPermissionSettings() => _locationService.openAppPermissionSettings();

  // Restores the toggle's state when the screen/app opens. Local storage
  // gives an instant answer (so the switch doesn't flash "off" while we
  // wait on the network); the backend read that follows is the source of
  // truth and corrects local state if it's stale (e.g. sharing was stopped
  // from another device, or the app was killed mid-write last time).
  Future<void> restoreSharingState(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUid = prefs.getString(_prefsSharingUidKey);
      if (storedUid == uid && prefs.getBool(_prefsSharingKey) == true) {
        _isSharing = true;
        final startedIso = prefs.getString(_prefsSharingStartedKey);
        _sharingStartedAt = startedIso != null ? DateTime.tryParse(startedIso) : null;
        notifyListeners();
      }
    } catch (_) {
      // No local prefs available — fall through to the backend check below.
    }

    final backendData = await _locationService.fetchSharingStatus(uid);
    if (backendData == null) return; // offline / no doc yet — trust local state
    final backendIsSharing = backendData['isSharing'] == true;
    if (backendIsSharing != _isSharing) {
      _isSharing = backendIsSharing;
      if (!backendIsSharing) _sharingStartedAt = null;
      await _persistSharingState(uid, backendIsSharing);
      notifyListeners();
    }
  }

  Future<void> _persistSharingState(String uid, bool sharing) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (sharing) {
        await prefs.setBool(_prefsSharingKey, true);
        await prefs.setString(_prefsSharingUidKey, uid);
        await prefs.setString(_prefsSharingStartedKey, (_sharingStartedAt ?? DateTime.now()).toIso8601String());
      } else {
        await prefs.remove(_prefsSharingKey);
        await prefs.remove(_prefsSharingUidKey);
        await prefs.remove(_prefsSharingStartedKey);
      }
    } catch (_) {
      // Persistence is best-effort; the in-memory state (and Firestore,
      // once reachable) remain the source of truth either way.
    }
  }

  // Fathima College of Arts and Science for Women, Madurai
  final LatLng _defaultPosition = const LatLng(9.9601, 78.0766);

  // Real GPS fix (via geolocator, through LocationService) + a real
  // reverse-geocoded address (via GeocodingService/Nominatim). Returns
  // false on permission/GPS failure — check `lastError` for why.
  //
  // Two-stage for speed: shows the device's cached last-known position
  // immediately (near-instant), then swaps in the fresh accurate fix and
  // address as soon as each arrives — so the screen never sits blank
  // while waiting on GPS + a network reverse-geocode call.
  Future<bool> getCurrentLocation() async {
    _setLoading(true);

    final quick = await _locationService.getLastKnownPosition();
    if (quick != null) {
      _currentPosition = LatLng(quick.latitude, quick.longitude);
      notifyListeners(); // paint instantly; _isLoading stays true
    }

    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      _setLoading(false);
      return _currentPosition != null; // keep the quick fix on screen if that's all we got
    }
    _currentPosition = LatLng(position.latitude, position.longitude);
    notifyListeners(); // show the accurate fix right away; address still loading

    _currentAddress = await _geocodingService.reverseGeocode(position.latitude, position.longitude);
    _setLoading(false);
    return true;
  }

  // Starts real live-location sharing: fetches actual GPS position and
  // writes it (plus isSharing: true) to Firestore so approved contacts
  // can see it via approvedContactsLocationStream / tripMembersLocationStream.
  Future<bool> startSharing({
    required String uid,
    required String userName,
    required String userEmail,
    String? tripId,
  }) async {
    _isEnabling = true;
    notifyListeners();
    try {
      // getCurrentPosition() checks/requests permission internally first —
      // sharing is never attempted before permission is actually granted.
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        return false; // permission denied / GPS off — _isSharing untouched
      }
      _currentPosition = LatLng(position.latitude, position.longitude);
      final ok = await _locationService.shareLocation(
        uid: uid,
        userName: userName,
        userEmail: userEmail,
        position: position,
        tripId: tripId,
      );
      if (ok) {
        _isSharing = true;
        _sharingStartedAt = DateTime.now();
        await _persistSharingState(uid, true);
      }
      // On failure, _locationService.shareLocation() has already set
      // lastErrorMessage to the specific reason (permission-denied,
      // unavailable, etc.) — leave it as-is instead of overwriting it
      // with a generic message. _isSharing is left untouched either way.
      return ok;
    } finally {
      _isEnabling = false;
      notifyListeners();
    }
  }

  Future<bool> stopSharing(String uid) async {
    final ok = await _locationService.stopSharing(uid);
    if (ok) {
      _isSharing = false;
      _sharingStartedAt = null;
      await _persistSharingState(uid, false);
    }
    // On failure, _locationService.stopSharing() has already set the
    // specific reason in lastErrorMessage — _isSharing is left untouched
    // (still "sharing") rather than silently flipping off.
    notifyListeners();
    return ok;
  }

  // Dummy shared locations — nearby Madurai
  void loadDummySharedLocations() {
    _sharedLocations = [
      LocationModel(
        uid: 'contact_001',
        userName: 'Priya S',
        userEmail: 'priya@example.com',
        latitude: 9.9252,   // Madurai Junction
        longitude: 78.1198,
        isSharing: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
      LocationModel(
        uid: 'contact_002',
        userName: 'Ravi K',
        userEmail: 'ravi@example.com',
        latitude: 9.9195,   // Meenakshi Amman Temple
        longitude: 78.1193,
        isSharing: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ];
    notifyListeners();
  }

  void updatePosition(LatLng position, {String? address}) {
    _currentPosition = position;
    if (address != null) _currentAddress = address;
    notifyListeners();
  }

  LatLng get positionOrDefault => _currentPosition ?? _defaultPosition;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}