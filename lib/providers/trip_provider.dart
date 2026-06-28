import 'package:flutter/material.dart';
import '../models/trip_model.dart';

class TripProvider extends ChangeNotifier {
  List<TripModel> _myTrips = [];
  TripModel? _activeTrip;
  bool _isLoading = false;

  List<TripModel> get myTrips => _myTrips;
  TripModel? get activeTrip => _activeTrip;
  bool get isLoading => _isLoading;

  List<TripModel> get activeTrips => _myTrips.where((t) => t.status == TripStatus.active).toList();
  List<TripModel> get completedTrips => _myTrips.where((t) => t.status == TripStatus.completed).toList();

  // Spec EXACT dummy data:
  // Total: 5, Completed: 4
  // FCW001 Madurai→Chennai Active
  // FCW002 Chennai→Trichy Completed
  // FCW003 Trichy→Madurai Cancelled
  void loadDummyTrips(String uid) {
    _myTrips = [
      TripModel(
        tripId: 'trip_001', tripCode: 'FCW001', creatorUid: uid,
        creatorName: 'Nisha F', creatorEmail: 'nisha@fcw.edu',
        startLocationName: 'Fathima College for Women, Madurai',
        startLat: 9.9601, startLng: 78.0766,
        destinationName: 'Madurai Junction',
        destinationLat: 9.9252, destinationLng: 78.1198,
        travelDate: DateTime(2025, 5, 20, 10, 0),
        passengerType: 'Women Only', vehicleType: 'Van',
        availableSeats: 6, bookedSeats: 3,
        memberUids: [uid], memberEmails: ['nisha@fcw.edu'],
        status: TripStatus.active,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
        distanceKm: 8.2, durationMinutes: 22,
      ),
      TripModel(
        tripId: 'trip_002', tripCode: 'FCW002', creatorUid: uid,
        creatorName: 'Nisha F', creatorEmail: 'nisha@fcw.edu',
        startLocationName: 'Chennai Central',
        startLat: 13.0827, startLng: 80.2707,
        destinationName: 'Trichy Bus Stand',
        destinationLat: 10.7905, destinationLng: 78.7047,
        travelDate: DateTime(2025, 5, 18, 9, 0),
        passengerType: 'Women Only', vehicleType: 'Sedan',
        availableSeats: 4, bookedSeats: 4,
        memberUids: [uid], memberEmails: ['nisha@fcw.edu'],
        status: TripStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        distanceKm: 320.0, durationMinutes: 270,
      ),
      TripModel(
        tripId: 'trip_003', tripCode: 'FCW003', creatorUid: uid,
        creatorName: 'Nisha F', creatorEmail: 'nisha@fcw.edu',
        startLocationName: 'Trichy Bus Stand',
        startLat: 10.7905, startLng: 78.7047,
        destinationName: 'Madurai Junction',
        destinationLat: 9.9252, destinationLng: 78.1198,
        travelDate: DateTime(2025, 5, 15, 8, 0),
        passengerType: 'Women Only', vehicleType: 'Car',
        availableSeats: 4, bookedSeats: 2,
        memberUids: [uid], memberEmails: ['nisha@fcw.edu'],
        status: TripStatus.cancelled,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now().subtract(const Duration(days: 8)),
        distanceKm: 130.0, durationMinutes: 150,
      ),
      TripModel(
        tripId: 'trip_004', tripCode: 'FCW004', creatorUid: uid,
        creatorName: 'Nisha F', creatorEmail: 'nisha@fcw.edu',
        startLocationName: 'Madurai Airport',
        startLat: 9.8349, startLng: 78.0937,
        destinationName: 'Fathima College for Women',
        destinationLat: 9.9601, destinationLng: 78.0766,
        travelDate: DateTime(2025, 5, 10, 14, 0),
        passengerType: 'Women Only', vehicleType: 'Car',
        availableSeats: 4, bookedSeats: 3,
        memberUids: [uid], memberEmails: ['nisha@fcw.edu'],
        status: TripStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        updatedAt: DateTime.now().subtract(const Duration(days: 12)),
        distanceKm: 15.6, durationMinutes: 35,
      ),
      TripModel(
        tripId: 'trip_005', tripCode: 'FCW005', creatorUid: uid,
        creatorName: 'Nisha F', creatorEmail: 'nisha@fcw.edu',
        startLocationName: 'Periyar Bus Stand, Madurai',
        startLat: 9.9194, startLng: 78.1202,
        destinationName: 'Fathima College for Women',
        destinationLat: 9.9601, destinationLng: 78.0766,
        travelDate: DateTime(2025, 5, 5, 9, 30),
        passengerType: 'Women Only', vehicleType: 'Auto',
        availableSeats: 3, bookedSeats: 2,
        memberUids: [uid], memberEmails: ['nisha@fcw.edu'],
        status: TripStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        updatedAt: DateTime.now().subtract(const Duration(days: 18)),
        distanceKm: 7.4, durationMinutes: 20,
      ),
    ];
    notifyListeners();
  }

  Future<Map<String, dynamic>> createTrip({
    required String creatorUid, required String creatorName, required String creatorEmail,
    required String startLocationName, required double startLat, required double startLng,
    required String destinationName, required double destinationLat, required double destinationLng,
    required DateTime travelDate, required String passengerType, required String vehicleType, required int availableSeats,
  }) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 800));
    final code = _generateCode();
    final trip = TripModel(
        tripId: 'trip_${DateTime.now().millisecondsSinceEpoch}', tripCode: code,
        creatorUid: creatorUid, creatorName: creatorName, creatorEmail: creatorEmail,
        startLocationName: startLocationName, startLat: startLat, startLng: startLng,
        destinationName: destinationName, destinationLat: destinationLat, destinationLng: destinationLng,
        travelDate: travelDate, passengerType: passengerType, vehicleType: vehicleType,
        availableSeats: availableSeats, bookedSeats: 1,
        memberUids: [creatorUid], memberEmails: [creatorEmail],
        status: TripStatus.active, createdAt: DateTime.now(), updatedAt: DateTime.now());
    _myTrips.insert(0, trip);
    _activeTrip = trip;
    _setLoading(false);
    return {'success': true, 'trip': trip, 'tripCode': code};
  }

  Future<Map<String, dynamic>> joinTrip({
    required String tripCode, required String uid, required String email, required String name,
  }) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 800));
    final trip = TripModel(
        tripId: 'trip_joined_${DateTime.now().millisecondsSinceEpoch}',
        tripCode: tripCode.toUpperCase(),
        creatorUid: 'other_uid', creatorName: 'Ramesh K', creatorEmail: 'ramesh@example.com',
        startLocationName: 'Madurai', startLat: 9.9252, startLng: 78.1198,
        destinationName: 'Chennai', destinationLat: 13.0827, destinationLng: 80.2707,
        travelDate: DateTime.now().add(const Duration(days: 1)),
        passengerType: 'Women Only', vehicleType: 'Sedan',
        availableSeats: 4, bookedSeats: 2,
        memberUids: ['other_uid', uid], memberEmails: ['ramesh@example.com', email],
        status: TripStatus.active, createdAt: DateTime.now(), updatedAt: DateTime.now(),
        distanceKm: 460.0, durationMinutes: 390);
    _myTrips.insert(0, trip);
    _setLoading(false);
    return {'success': true, 'trip': trip};
  }

  Future<void> completeTrip(String tripId) async {
    final i = _myTrips.indexWhere((t) => t.tripId == tripId);
    if (i != -1) { _myTrips[i] = _myTrips[i].copyWith(status: TripStatus.completed); if (_activeTrip?.tripId == tripId) _activeTrip = null; notifyListeners(); }
  }

  Future<void> cancelTrip(String tripId) async {
    final i = _myTrips.indexWhere((t) => t.tripId == tripId);
    if (i != -1) { _myTrips[i] = _myTrips[i].copyWith(status: TripStatus.cancelled); if (_activeTrip?.tripId == tripId) _activeTrip = null; notifyListeners(); }
  }

  void setActiveTrip(TripModel? trip) { _activeTrip = trip; notifyListeners(); }

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    int temp = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    for (int i = 0; i < 6; i++) { code += chars[temp % chars.length]; temp ~/= chars.length; }
    return code;
  }

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
}