import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../core/services/firestore_service.dart';

class TripProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<List<TripModel>>? _tripsSub;
  StreamSubscription<int>? _sosCountSub;

  List<TripModel> _myTrips = [];
  TripModel? _activeTrip;
  bool _isLoading = false;
  int _sosCount = 0;

  List<TripModel> get myTrips => _myTrips;
  TripModel? get activeTrip => _activeTrip;
  bool get isLoading => _isLoading;
  // Real count of SOS alerts this user has triggered — feeds the
  // Safety Score's SOS Discipline factor.
  int get sosCount => _sosCount;

  List<TripModel> get activeTrips => _myTrips.where((t) => t.status == TripStatus.active).toList();
  List<TripModel> get completedTrips => _myTrips.where((t) => t.status == TripStatus.completed).toList();
  List<TripModel> get cancelledTrips => _myTrips.where((t) => t.status == TripStatus.cancelled).toList();

  // Kept the old name so existing call sites (home_screen.dart etc.) don't
  // need to change — internally this now pulls real trips from Firestore
  // instead of loading dummy data. It's a live stream: any change (new
  // trip, join, status update) reflects automatically without a manual
  // refresh call.
  void loadDummyTrips(String uid) {
    _setLoading(true);
    _tripsSub?.cancel();
    _tripsSub = _firestoreService.myTripsStream(uid).listen((trips) {
      _myTrips = trips;
      final activeOnes = trips.where((t) => t.status == TripStatus.active);
      _activeTrip = activeOnes.isNotEmpty ? activeOnes.first : null;
      _setLoading(false);
    }, onError: (_) {
      _setLoading(false);
    });

    _sosCountSub?.cancel();
    _sosCountSub = _firestoreService.sosAlertCountStream(uid).listen((count) {
      _sosCount = count;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _tripsSub?.cancel();
    _sosCountSub?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> createTrip({
    required String creatorUid, required String creatorName, required String creatorEmail,
    required String startLocationName, required double startLat, required double startLng,
    required String destinationName, required double destinationLat, required double destinationLng,
    required DateTime travelDate, required String passengerType, required String vehicleType, required int availableSeats,
  }) async {
    _setLoading(true);
    final code = _generateCode();
    final now = DateTime.now();
    final trip = TripModel(
        tripId: '', tripCode: code,
        creatorUid: creatorUid, creatorName: creatorName, creatorEmail: creatorEmail,
        startLocationName: startLocationName, startLat: startLat, startLng: startLng,
        destinationName: destinationName, destinationLat: destinationLat, destinationLng: destinationLng,
        travelDate: travelDate, passengerType: passengerType, vehicleType: vehicleType,
        availableSeats: availableSeats, bookedSeats: 1,
        memberUids: [creatorUid], memberEmails: [creatorEmail],
        status: TripStatus.active, createdAt: now, updatedAt: now);

    final tripId = await _firestoreService.createTrip(trip);
    _setLoading(false);

    if (tripId == null) {
      return {'success': false, 'error': 'Could not create trip. Check your connection.'};
    }
    final savedTrip = trip.copyWith(tripId: tripId);
    _activeTrip = savedTrip;
    return {'success': true, 'trip': savedTrip, 'tripCode': code};
  }

  Future<Map<String, dynamic>> joinTrip({
    required String tripCode, required String uid, required String email, required String name,
  }) async {
    _setLoading(true);
    final trip = await _firestoreService.getTripByCode(tripCode.toUpperCase());

    if (trip == null) {
      _setLoading(false);
      return {'success': false, 'error': 'No active trip found with that code.'};
    }
    if (trip.status != TripStatus.active) {
      _setLoading(false);
      final statusText = trip.status.name[0].toUpperCase() + trip.status.name.substring(1);
      return {'success': false, 'error': 'This trip is already $statusText and can no longer be joined.'};
    }
    if (trip.isFull) {
      _setLoading(false);
      return {'success': false, 'error': 'This trip is already full.'};
    }
    if (trip.memberUids.contains(uid)) {
      _setLoading(false);
      return {'success': false, 'error': 'You already joined this trip.'};
    }

    final result = await _firestoreService.joinTrip(trip.tripId, uid, email);
    _setLoading(false);

    if (result['success'] != true) {
      // The transaction is the final authority — e.g. someone else could
      // have taken the last seat between our pre-check above and now.
      return {'success': false, 'error': result['error']?.toString() ?? 'Could not join trip. Try again.'};
    }
    final updatedTrip = trip.copyWith(
      bookedSeats: trip.bookedSeats + 1,
      memberUids: [...trip.memberUids, uid],
      memberEmails: [...trip.memberEmails, email],
    );
    return {'success': true, 'trip': updatedTrip};
  }

  Future<void> completeTrip(String tripId) async {
    final ok = await _firestoreService.updateTripStatus(tripId, TripStatus.completed);
    if (ok) {
      final i = _myTrips.indexWhere((t) => t.tripId == tripId);
      if (i != -1) {
        _myTrips[i] = _myTrips[i].copyWith(status: TripStatus.completed);
      }
      if (_activeTrip?.tripId == tripId) _activeTrip = null;
      notifyListeners();
    }
  }

  Future<void> cancelTrip(String tripId) async {
    final ok = await _firestoreService.updateTripStatus(tripId, TripStatus.cancelled);
    if (ok) {
      final i = _myTrips.indexWhere((t) => t.tripId == tripId);
      if (i != -1) {
        _myTrips[i] = _myTrips[i].copyWith(status: TripStatus.cancelled);
      }
      if (_activeTrip?.tripId == tripId) _activeTrip = null;
      notifyListeners();
    }
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