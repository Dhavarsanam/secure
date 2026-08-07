import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../models/guardian_risk_event.dart';
import '../../models/trip_model.dart';
import '../constants/guardian_config.dart';
import 'location_service.dart';

/// Guardian AI Mode — Phase 1: rule-based journey monitoring engine.
///
/// Watches an active trip's live location and raises risk events for:
///   • Route deviation (distance from planned route)
///   • Unexpected stop (no meaningful movement)
///   • ETA overdue (past expected arrival)
///   • Location signal lost (no fresh GPS fix)
///
/// This is intentionally NOT machine learning — it's a transparent,
/// explainable rule engine so behavior is predictable and debuggable.
/// The architecture (risk score, event stream, config thresholds) is
/// built so a future ML-based scorer could be swapped in without
/// changing how the UI consumes it.
///
/// Phase 1 never auto-triggers SOS — it only observes and reports.
class GuardianAiService extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final Uuid _uuid = const Uuid();

  // Lazily resolved — never touched until the first Firestore write is
  // actually attempted, and guarded so a missing/broken Firebase.initializeApp()
  // elsewhere in the app can never crash Guardian AI's local monitoring.
  FirebaseFirestore? _dbInstance;
  bool _firestoreUnavailable = false;

  FirebaseFirestore? get _db {
    if (_firestoreUnavailable) return null;
    try {
      return _dbInstance ??= FirebaseFirestore.instance;
    } catch (_) {
      _firestoreUnavailable = true;
      return null;
    }
  }

  TripModel? _trip;
  String? _userId;

  StreamSubscription<Position>? _positionSub;
  Timer? _evaluationTimer;

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  bool _locationError = false;
  bool get hasLocationError => _locationError;

  bool _routeMonitoringAvailable = false;
  bool get routeMonitoringAvailable => _routeMonitoringAvailable;

  bool _etaMonitoringAvailable = false;
  bool get etaMonitoringAvailable => _etaMonitoringAvailable;

  Position? _lastPosition;
  DateTime? _lastLocationUpdate;
  DateTime? _lastMovementTime;
  DateTime? _lastCheckedAt;
  DateTime? get lastCheckedAt => _lastCheckedAt;

  int _riskScore = 0;
  int get riskScore => _riskScore;

  GuardianRiskLevel _riskLevel = GuardianRiskLevel.safe;
  GuardianRiskLevel get riskLevel => _riskLevel;

  final List<GuardianRiskEvent> _events = [];
  List<GuardianRiskEvent> get events => List.unmodifiable(_events);

  final Map<GuardianEventType, GuardianRiskEvent> _activeEvents = {};

  final List<GuardianTimelineEntry> _timeline = [];
  List<GuardianTimelineEntry> get timeline => List.unmodifiable(_timeline);

  /// Start monitoring an active trip. Safe to call again for the same
  /// trip (no-op) — guards against duplicate subscriptions.
  Future<void> start({required TripModel trip, required String userId}) async {
    if (_isMonitoring && _trip?.tripId == trip.tripId) return;
    if (_isMonitoring) await stop();

    _trip = trip;
    _userId = userId;
    _isMonitoring = true;
    _locationError = false;
    _riskScore = 0;
    _riskLevel = GuardianRiskLevel.safe;
    _events.clear();
    _activeEvents.clear();
    _timeline.clear();
    _lastPosition = null;
    _lastLocationUpdate = null;
    _lastMovementTime = DateTime.now();

    _routeMonitoringAvailable = trip.routePoints != null && trip.routePoints!.isNotEmpty;
    _etaMonitoringAvailable = trip.durationMinutes != null;

    _timeline.add(GuardianTimelineEntry(
      time: DateTime.now(),
      title: 'Guardian AI activated',
      description: 'Smart journey monitoring has started for this trip.',
      level: GuardianRiskLevel.safe,
    ));

    notifyListeners();

    try {
      final hasPermission = await _locationService.checkPermission();
      if (!hasPermission) {
        _locationError = true;
      } else {
        _positionSub = _locationService.positionStream().listen(
          _onPosition,
          onError: (_) {
            _locationError = true;
            notifyListeners();
          },
        );
      }
    } catch (_) {
      _locationError = true;
    }

    _evaluationTimer = Timer.periodic(
      GuardianConfig.evaluationInterval,
          (_) => _runPeriodicChecks(),
    );

    await _writeStatusToFirestore();
    notifyListeners();
  }

  /// Stop monitoring, cancel all timers/streams, and persist final status.
  /// Safe to call even if not currently monitoring.
  Future<void> stop({String? reason}) async {
    final wasMonitoring = _isMonitoring;
    await _positionSub?.cancel();
    _positionSub = null;
    _evaluationTimer?.cancel();
    _evaluationTimer = null;
    _isMonitoring = false;

    if (wasMonitoring) {
      _timeline.add(GuardianTimelineEntry(
        time: DateTime.now(),
        title: reason ?? 'Guardian AI deactivated',
        description: reason == null
            ? 'Journey monitoring has been turned off.'
            : reason,
        level: GuardianRiskLevel.safe,
      ));
      await _writeStatusToFirestore(stopped: true);
    }
    notifyListeners();
  }

  void _onPosition(Position position) {
    _lastLocationUpdate = DateTime.now();
    _locationError = false;

    final prev = _lastPosition;
    _lastPosition = position;

    if (prev == null) {
      _lastMovementTime = DateTime.now();
    } else {
      final movedMeters = Geolocator.distanceBetween(
        prev.latitude, prev.longitude, position.latitude, position.longitude,
      );
      if (movedMeters > GuardianConfig.movementThresholdMeters ||
          position.speed > GuardianConfig.movingSpeedThreshold) {
        _lastMovementTime = DateTime.now();
      }
    }

    _checkRouteDeviation(position);
    _runPeriodicChecks();
  }

  void _runPeriodicChecks() {
    if (!_isMonitoring || _trip == null) return;
    _lastCheckedAt = DateTime.now();
    _checkUnexpectedStop();
    _checkEtaOverdue();
    _checkLocationSignal();
    _recomputeRiskScore();
    notifyListeners();
    _writeStatusToFirestore();
  }

  // ─── Detection rules ─────────────────────────────────────────

  void _checkRouteDeviation(Position position) {
    if (!_routeMonitoringAvailable) return;
    final points = _trip!.routePoints!;
    double minDist = double.infinity;
    for (final p in points) {
      final d = Geolocator.distanceBetween(
        position.latitude, position.longitude, p[0], p[1],
      );
      if (d < minDist) minDist = d;
    }

    if (minDist >= GuardianConfig.routeDeviationHighMeters) {
      _raiseEvent(
        type: GuardianEventType.routeDeviation,
        level: GuardianRiskLevel.highRisk,
        score: GuardianConfig.scoreHighRouteDeviation,
        title: 'Route deviation detected',
        description: 'You are ${minDist.round()}m away from the planned route.',
        lat: position.latitude,
        lng: position.longitude,
      );
    } else if (minDist >= GuardianConfig.routeDeviationCautionMeters) {
      _raiseEvent(
        type: GuardianEventType.routeDeviation,
        level: GuardianRiskLevel.caution,
        score: GuardianConfig.scoreCautionRouteDeviation,
        title: 'Minor route deviation',
        description: 'You are ${minDist.round()}m away from the planned route.',
        lat: position.latitude,
        lng: position.longitude,
      );
    } else {
      _resolveEvent(GuardianEventType.routeDeviation, 'Back on the expected route');
    }
  }

  void _checkUnexpectedStop() {
    if (_lastMovementTime == null || _lastPosition == null) return;

    final distToDest = Geolocator.distanceBetween(
      _lastPosition!.latitude, _lastPosition!.longitude,
      _trip!.destinationLat, _trip!.destinationLng,
    );
    if (distToDest <= GuardianConfig.destinationRadiusMeters) {
      _resolveEvent(GuardianEventType.unexpectedStop, 'Reached destination area');
      return;
    }

    final stoppedFor = DateTime.now().difference(_lastMovementTime!);
    if (stoppedFor >= GuardianConfig.unexpectedStopHighDuration) {
      _raiseEvent(
        type: GuardianEventType.unexpectedStop,
        level: GuardianRiskLevel.highRisk,
        score: GuardianConfig.scoreHighUnexpectedStop,
        title: 'Prolonged unexpected stop',
        description: 'No movement for ${stoppedFor.inMinutes} minutes.',
      );
    } else if (stoppedFor >= GuardianConfig.unexpectedStopCautionDuration) {
      _raiseEvent(
        type: GuardianEventType.unexpectedStop,
        level: GuardianRiskLevel.caution,
        score: GuardianConfig.scoreCautionUnexpectedStop,
        title: 'Unexpected stop',
        description: 'No movement for ${stoppedFor.inMinutes} minutes.',
      );
    } else {
      _resolveEvent(GuardianEventType.unexpectedStop, 'Movement resumed');
    }
  }

  void _checkEtaOverdue() {
    if (!_etaMonitoringAvailable) return;
    final expectedArrival = _trip!.travelDate.add(Duration(minutes: _trip!.durationMinutes!));
    final overdueBy = DateTime.now().difference(expectedArrival);

    if (overdueBy >= GuardianConfig.etaOverdueHighDuration) {
      _raiseEvent(
        type: GuardianEventType.etaOverdue,
        level: GuardianRiskLevel.highRisk,
        score: GuardianConfig.scoreHighEtaOverdue,
        title: 'Significantly overdue',
        description: '${overdueBy.inMinutes} minutes past expected arrival.',
      );
    } else if (overdueBy >= GuardianConfig.etaOverdueCautionDuration) {
      _raiseEvent(
        type: GuardianEventType.etaOverdue,
        level: GuardianRiskLevel.caution,
        score: GuardianConfig.scoreCautionEtaOverdue,
        title: 'ETA overdue',
        description: '${overdueBy.inMinutes} minutes past expected arrival.',
      );
    } else {
      _resolveEvent(GuardianEventType.etaOverdue, 'Within expected arrival window');
    }
  }

  void _checkLocationSignal() {
    if (_lastLocationUpdate == null) return; // no fix received yet — don't flag prematurely
    final since = DateTime.now().difference(_lastLocationUpdate!);
    if (since >= GuardianConfig.locationSignalTimeout) {
      _locationError = true;
      _raiseEvent(
        type: GuardianEventType.locationSignalLost,
        level: GuardianRiskLevel.caution,
        score: GuardianConfig.scoreLocationSignalLost,
        title: 'Location signal lost',
        description: 'No location update for ${since.inMinutes} minutes.',
      );
    } else {
      _locationError = false;
      _resolveEvent(GuardianEventType.locationSignalLost, 'Location signal restored');
    }
  }

  // ─── Event bookkeeping ───────────────────────────────────────

  void _raiseEvent({
    required GuardianEventType type,
    required GuardianRiskLevel level,
    required int score,
    required String title,
    required String description,
    double? lat,
    double? lng,
  }) {
    final existing = _activeEvents[type];
    // Same severity already active for this condition — avoid duplicate writes.
    if (existing != null && existing.riskLevel == level) return;

    if (existing != null) {
      _resolveEventLocal(existing, 'Escalated');
    }

    final event = GuardianRiskEvent(
      id: _uuid.v4(),
      tripId: _trip!.tripId,
      userId: _userId ?? '',
      eventType: type,
      riskLevel: level,
      riskScore: score,
      title: title,
      description: description,
      latitude: lat,
      longitude: lng,
      detectedAt: DateTime.now(),
      isResolved: false,
    );

    _activeEvents[type] = event;
    _events.insert(0, event);
    _addTimelineEntry(GuardianTimelineEntry(
      time: event.detectedAt,
      title: title,
      description: description,
      level: level,
      eventType: type,
    ));
    _writeEventToFirestore(event);
  }

  void _resolveEvent(GuardianEventType type, String resolutionNote) {
    final existing = _activeEvents[type];
    if (existing == null) return;
    _resolveEventLocal(existing, resolutionNote);
  }

  void _resolveEventLocal(GuardianRiskEvent event, String resolutionNote) {
    final resolved = event.copyWith(isResolved: true, resolvedAt: DateTime.now());
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx != -1) _events[idx] = resolved;
    _activeEvents.remove(event.eventType);
    _addTimelineEntry(GuardianTimelineEntry(
      time: resolved.resolvedAt!,
      title: resolutionNote,
      description: resolved.title,
      level: GuardianRiskLevel.safe,
      eventType: event.eventType,
    ));
    _resolveEventInFirestore(resolved);
  }

  void _addTimelineEntry(GuardianTimelineEntry entry) {
    _timeline.add(entry);
    if (_timeline.length > GuardianConfig.maxTimelineEntries) {
      _timeline.removeAt(0);
    }
  }

  void _recomputeRiskScore() {
    int score = 0;
    for (final e in _activeEvents.values) {
      score += e.riskScore;
    }
    _riskScore = score.clamp(0, 100).toInt();
    _riskLevel = _levelForScore(_riskScore);
  }

  static GuardianRiskLevel _levelForScore(int score) {
    if (score > GuardianConfig.highRiskMax) return GuardianRiskLevel.critical;
    if (score > GuardianConfig.cautionMax) return GuardianRiskLevel.highRisk;
    if (score > GuardianConfig.safeMax) return GuardianRiskLevel.caution;
    return GuardianRiskLevel.safe;
  }

  // ─── Firestore (best-effort, never blocks or crashes monitoring) ──

  Future<void> _writeStatusToFirestore({bool stopped = false}) async {
    final trip = _trip;
    final db = _db;
    if (trip == null || trip.tripId.isEmpty || db == null) return;
    try {
      await db
          .collection(GuardianConfig.tripsCollection)
          .doc(trip.tripId)
          .collection(GuardianConfig.guardianStatusSubcollection)
          .doc(GuardianConfig.guardianStatusDoc)
          .set({
        'enabled': !stopped,
        'riskScore': _riskScore,
        'riskLevel': _riskLevel.name,
        'lastMonitoredAt': FieldValue.serverTimestamp(),
        if (stopped) 'stoppedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Offline or rules-restricted — local monitoring continues regardless.
    }
  }

  Future<void> _writeEventToFirestore(GuardianRiskEvent event) async {
    final db = _db;
    if (event.tripId.isEmpty || db == null) return;
    try {
      await db
          .collection(GuardianConfig.tripsCollection)
          .doc(event.tripId)
          .collection(GuardianConfig.guardianEventsSubcollection)
          .doc(event.id)
          .set(event.toMap());
    } catch (_) {
      // Best-effort persistence — event already reflected in local UI state.
    }
  }

  Future<void> _resolveEventInFirestore(GuardianRiskEvent event) async {
    final db = _db;
    if (event.tripId.isEmpty || db == null) return;
    try {
      await db
          .collection(GuardianConfig.tripsCollection)
          .doc(event.tripId)
          .collection(GuardianConfig.guardianEventsSubcollection)
          .doc(event.id)
          .update({
        'isResolved': true,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-fatal — local state already marks it resolved.
    }
  }

  // ─── Demo / Viva simulation (testing only) ────────────────────
  //
  // Lets a demo/viva presentation show the risk engine reacting without
  // waiting for real GPS conditions (walking 500m off-route, waiting
  // 10 minutes stopped, etc). Never called from real detection logic —
  // only from a UI button the developer/presenter taps manually.

  /// Manually raises a fake risk event of [type] at [level], exactly as
  /// if the real rule engine had detected it. Updates the risk score,
  /// timeline and Firestore status the same way a real detection would.
  void simulateEvent(GuardianEventType type, GuardianRiskLevel level) {
    if (!_isMonitoring || _trip == null) return;
    _raiseEvent(
      type: type,
      level: level,
      score: _demoScoreFor(type, level),
      title: '${_demoTitleFor(type)} (Simulated)',
      description: _demoDescriptionFor(type, level),
      lat: _lastPosition?.latitude,
      lng: _lastPosition?.longitude,
    );
    _recomputeRiskScore();
    notifyListeners();
    _writeStatusToFirestore();
  }

  /// Clears every currently-active (real or simulated) event and drops
  /// the risk score back to 0 / Safe, without turning monitoring off.
  void resetToSafe() {
    if (!_isMonitoring) return;
    for (final event in List<GuardianRiskEvent>.from(_activeEvents.values)) {
      _resolveEventLocal(event, 'Manually reset to Safe (demo)');
    }
    _recomputeRiskScore();
    notifyListeners();
    _writeStatusToFirestore();
  }

  int _demoScoreFor(GuardianEventType type, GuardianRiskLevel level) {
    final high = level == GuardianRiskLevel.highRisk || level == GuardianRiskLevel.critical;
    switch (type) {
      case GuardianEventType.routeDeviation:
        return high ? GuardianConfig.scoreHighRouteDeviation : GuardianConfig.scoreCautionRouteDeviation;
      case GuardianEventType.unexpectedStop:
        return high ? GuardianConfig.scoreHighUnexpectedStop : GuardianConfig.scoreCautionUnexpectedStop;
      case GuardianEventType.etaOverdue:
        return high ? GuardianConfig.scoreHighEtaOverdue : GuardianConfig.scoreCautionEtaOverdue;
      case GuardianEventType.locationSignalLost:
        return GuardianConfig.scoreLocationSignalLost;
      case GuardianEventType.noUserResponse:
      case GuardianEventType.manualSOS:
        return high ? 45 : 25;
    }
  }

  String _demoTitleFor(GuardianEventType type) {
    switch (type) {
      case GuardianEventType.routeDeviation:
        return 'Route deviation detected';
      case GuardianEventType.unexpectedStop:
        return 'Unexpected stop';
      case GuardianEventType.etaOverdue:
        return 'ETA overdue';
      case GuardianEventType.locationSignalLost:
        return 'Location signal lost';
      case GuardianEventType.noUserResponse:
        return 'No response to safety check';
      case GuardianEventType.manualSOS:
        return 'Manual SOS';
    }
  }

  String _demoDescriptionFor(GuardianEventType type, GuardianRiskLevel level) {
    final tag = level == GuardianRiskLevel.highRisk || level == GuardianRiskLevel.critical ? 'High risk' : 'Caution';
    switch (type) {
      case GuardianEventType.routeDeviation:
        return '$tag demo — simulated distance from planned route.';
      case GuardianEventType.unexpectedStop:
        return '$tag demo — simulated no-movement period.';
      case GuardianEventType.etaOverdue:
        return '$tag demo — simulated overdue arrival.';
      case GuardianEventType.locationSignalLost:
        return '$tag demo — simulated GPS signal loss.';
      case GuardianEventType.noUserResponse:
      case GuardianEventType.manualSOS:
        return '$tag demo event.';
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _evaluationTimer?.cancel();
    super.dispose();
  }
}