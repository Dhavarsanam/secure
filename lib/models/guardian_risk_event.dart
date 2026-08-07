import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of conditions Guardian AI can detect during a journey.
///
/// Phase 1 implements: routeDeviation, unexpectedStop, etaOverdue,
/// locationSignalLost.
/// `noUserResponse` and `manualSOS` are modeled now so Firestore
/// data + UI (icons, colors) already understand them, but nothing in
/// Phase 1 raises them yet — they belong to the safety-check /
/// auto-escalation phase.
enum GuardianEventType {
  routeDeviation,
  unexpectedStop,
  etaOverdue,
  locationSignalLost,
  noUserResponse,
  manualSOS,
}

/// Guardian AI risk severity band, derived from the 0–100 risk score.
enum GuardianRiskLevel { safe, caution, highRisk, critical }

extension GuardianRiskLevelX on GuardianRiskLevel {
  String get label {
    switch (this) {
      case GuardianRiskLevel.safe:
        return 'Safe';
      case GuardianRiskLevel.caution:
        return 'Caution';
      case GuardianRiskLevel.highRisk:
        return 'High Risk';
      case GuardianRiskLevel.critical:
        return 'Critical';
    }
  }
}

/// A single detected (or resolved) Guardian AI risk event for a trip.
///
/// Stored at: trips/{tripId}/guardian_events/{eventId}
class GuardianRiskEvent {
  final String id;
  final String tripId;
  final String userId;
  final GuardianEventType eventType;
  final GuardianRiskLevel riskLevel;
  final int riskScore;
  final String title;
  final String description;
  final double? latitude;
  final double? longitude;
  final DateTime detectedAt;
  final DateTime? resolvedAt;
  final bool isResolved;
  final Map<String, dynamic>? metadata;

  const GuardianRiskEvent({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.eventType,
    required this.riskLevel,
    required this.riskScore,
    required this.title,
    required this.description,
    this.latitude,
    this.longitude,
    required this.detectedAt,
    this.resolvedAt,
    this.isResolved = false,
    this.metadata,
  });

  GuardianRiskEvent copyWith({
    GuardianRiskLevel? riskLevel,
    int? riskScore,
    String? title,
    String? description,
    DateTime? resolvedAt,
    bool? isResolved,
  }) {
    return GuardianRiskEvent(
      id: id,
      tripId: tripId,
      userId: userId,
      eventType: eventType,
      riskLevel: riskLevel ?? this.riskLevel,
      riskScore: riskScore ?? this.riskScore,
      title: title ?? this.title,
      description: description ?? this.description,
      latitude: latitude,
      longitude: longitude,
      detectedAt: detectedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      isResolved: isResolved ?? this.isResolved,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'userId': userId,
      'eventType': eventType.name,
      'riskLevel': riskLevel.name,
      'riskScore': riskScore,
      'title': title,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'detectedAt': Timestamp.fromDate(detectedAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'isResolved': isResolved,
      'metadata': metadata,
    };
  }

  factory GuardianRiskEvent.fromMap(Map<String, dynamic> map, String id) {
    return GuardianRiskEvent(
      id: id,
      tripId: map['tripId'] ?? '',
      userId: map['userId'] ?? '',
      eventType: GuardianEventType.values.firstWhere(
            (e) => e.name == map['eventType'],
        orElse: () => GuardianEventType.unexpectedStop,
      ),
      riskLevel: GuardianRiskLevel.values.firstWhere(
            (e) => e.name == map['riskLevel'],
        orElse: () => GuardianRiskLevel.caution,
      ),
      riskScore: (map['riskScore'] ?? 0) as int,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      detectedAt: (map['detectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      isResolved: map['isResolved'] ?? false,
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
    );
  }
}

/// A lightweight, purely local timeline entry for the "Journey Safety
/// Timeline" UI. Not every timeline entry maps to a Firestore risk event
/// (e.g. "Guardian AI activated" or "Returned to expected route" are
/// narrative markers, not standalone risk records).
class GuardianTimelineEntry {
  final DateTime time;
  final String title;
  final String description;
  final GuardianRiskLevel level;
  final GuardianEventType? eventType;

  const GuardianTimelineEntry({
    required this.time,
    required this.title,
    required this.description,
    required this.level,
    this.eventType,
  });
}