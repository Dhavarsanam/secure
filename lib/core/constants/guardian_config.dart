/// Centralized configuration for Guardian AI Mode.
///
/// Phase 1 — rule-based thresholds only. Keeping every tunable number here
/// (instead of scattered through the service) means Phase 2 (ML upgrade,
/// auto-SOS escalation, etc.) can swap logic without hunting for magic
/// numbers across the codebase.
class GuardianConfig {
  GuardianConfig._();

  // ─── Route Deviation ───────────────────────────────────────
  /// Distance (meters) from the planned route that counts as "Caution".
  static const double routeDeviationCautionMeters = 500;

  /// Distance (meters) from the planned route that counts as "High Risk".
  static const double routeDeviationHighMeters = 1000;

  // ─── Unexpected Stop ───────────────────────────────────────
  static const Duration unexpectedStopCautionDuration = Duration(minutes: 5);
  static const Duration unexpectedStopHighDuration = Duration(minutes: 10);

  /// Minimum movement (meters) between fixes to be considered "still moving".
  static const double movementThresholdMeters = 15;

  /// Speed (m/s) above which the user is considered actively moving.
  /// ~0.5 m/s ≈ 1.8 km/h, filters out GPS jitter while stationary.
  static const double movingSpeedThreshold = 0.5;

  /// Radius (meters) around the destination where stops are expected
  /// and should never be flagged as "unexpected".
  static const double destinationRadiusMeters = 150;

  // ─── ETA Overdue ───────────────────────────────────────────
  static const Duration etaOverdueCautionDuration = Duration(minutes: 10);
  static const Duration etaOverdueHighDuration = Duration(minutes: 20);

  // ─── Location Signal ─────────────────────────────────────────
  /// If no successful location fix arrives within this window, raise a
  /// "Location Signal Lost" event.
  static const Duration locationSignalTimeout = Duration(minutes: 3);

  // ─── Engine cadence ──────────────────────────────────────────
  /// How often time-based conditions (stop duration, ETA, signal loss)
  /// are re-evaluated, independent of whether a new GPS fix arrived.
  static const Duration evaluationInterval = Duration(seconds: 30);

  // ─── Risk score contribution per event severity ─────────────
  static const int scoreCautionRouteDeviation = 25;
  static const int scoreHighRouteDeviation = 45;
  static const int scoreCautionUnexpectedStop = 20;
  static const int scoreHighUnexpectedStop = 40;
  static const int scoreCautionEtaOverdue = 15;
  static const int scoreHighEtaOverdue = 30;
  static const int scoreLocationSignalLost = 20;

  // ─── Risk level bands (0–100) ────────────────────────────────
  static const int safeMax = 29;
  static const int cautionMax = 59;
  static const int highRiskMax = 79;
  // 80–100 => Critical

  // ─── Firestore paths ──────────────────────────────────────────
  static const String tripsCollection = 'trips';
  static const String guardianStatusSubcollection = 'guardian';
  static const String guardianStatusDoc = 'status';
  static const String guardianEventsSubcollection = 'guardian_events';

  /// Timeline is trimmed to this many most-recent entries in memory,
  /// to avoid unbounded growth on very long journeys.
  static const int maxTimelineEntries = 50;
}