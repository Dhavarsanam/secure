import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_model.dart';

class LocationProvider extends ChangeNotifier {
  LatLng? _currentPosition;
  bool _isSharing = false;
  bool _isLoading = false;
  List<LocationModel> _sharedLocations = [];
  String? _currentAddress;

  LatLng? get currentPosition => _currentPosition;
  bool get isSharing => _isSharing;
  bool get isLoading => _isLoading;
  List<LocationModel> get sharedLocations => _sharedLocations;
  String? get currentAddress => _currentAddress;

  // Fathima College of Arts and Science for Women, Madurai
  final LatLng _defaultPosition = const LatLng(9.9601, 78.0766);

  Future<bool> getCurrentLocation() async {
    _setLoading(true);
    await Future.delayed(const Duration(seconds: 1));
    // TODO: Replace with real GPS via LocationService
    _currentPosition = _defaultPosition;
    _currentAddress = 'Fathima College for Women, Madurai, Tamil Nadu';
    _setLoading(false);
    return true;
  }

  Future<bool> startSharing({
    required String uid,
    required String userName,
    required String userEmail,
    String? tripId,
  }) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 500));
    _isSharing = true;
    _setLoading(false);
    return true;
  }

  Future<void> stopSharing(String uid) async {
    _isSharing = false;
    notifyListeners();
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
