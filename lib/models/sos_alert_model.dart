import 'package:cloud_firestore/cloud_firestore.dart';

enum SosStatus { active, resolved, cancelled }

class SosAlertModel {
  final String alertId;
  final String senderUid;
  final String senderName;
  final String senderEmail;
  final String senderPhone;

  // Location at time of SOS
  final double latitude;
  final double longitude;
  final String? locationAddress;

  // Trip info (if in active trip)
  final String? tripId;
  final String? tripCode;
  final String? startLocationName;
  final String? destinationName;

  // Alert details
  final String message;
  final List<String> notifiedContacts;
  final SosStatus status;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;

  // Periodic update locations
  final List<Map<String, dynamic>> locationUpdates;

  SosAlertModel({
    required this.alertId,
    required this.senderUid,
    required this.senderName,
    required this.senderEmail,
    required this.senderPhone,
    required this.latitude,
    required this.longitude,
    this.locationAddress,
    this.tripId,
    this.tripCode,
    this.startLocationName,
    this.destinationName,
    this.message = 'Emergency! I need help.',
    this.notifiedContacts = const [],
    this.status = SosStatus.active,
    required this.triggeredAt,
    this.resolvedAt,
    this.locationUpdates = const [],
  });

  factory SosAlertModel.fromMap(Map<String, dynamic> map, String alertId) {
    return SosAlertModel(
      alertId: alertId,
      senderUid: map['senderUid'] ?? '',
      senderName: map['senderName'] ?? '',
      senderEmail: map['senderEmail'] ?? '',
      senderPhone: map['senderPhone'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      locationAddress: map['locationAddress'],
      tripId: map['tripId'],
      tripCode: map['tripCode'],
      startLocationName: map['startLocationName'],
      destinationName: map['destinationName'],
      message: map['message'] ?? 'Emergency! I need help.',
      notifiedContacts: List<String>.from(map['notifiedContacts'] ?? []),
      status: SosStatus.values.firstWhere(
            (e) => e.name == (map['status'] ?? 'active'),
        orElse: () => SosStatus.active,
      ),
      triggeredAt:
      (map['triggeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      locationUpdates:
      List<Map<String, dynamic>>.from(map['locationUpdates'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderUid': senderUid,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'senderPhone': senderPhone,
      'latitude': latitude,
      'longitude': longitude,
      'locationAddress': locationAddress,
      'tripId': tripId,
      'tripCode': tripCode,
      'startLocationName': startLocationName,
      'destinationName': destinationName,
      'message': message,
      'notifiedContacts': notifiedContacts,
      'status': status.name,
      'triggeredAt': Timestamp.fromDate(triggeredAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'locationUpdates': locationUpdates,
    };
  }

  SosAlertModel copyWith({
    String? alertId,
    String? senderUid,
    String? senderName,
    String? senderEmail,
    String? senderPhone,
    double? latitude,
    double? longitude,
    String? locationAddress,
    String? tripId,
    String? tripCode,
    String? startLocationName,
    String? destinationName,
    String? message,
    List<String>? notifiedContacts,
    SosStatus? status,
    DateTime? triggeredAt,
    DateTime? resolvedAt,
    List<Map<String, dynamic>>? locationUpdates,
  }) {
    return SosAlertModel(
      alertId: alertId ?? this.alertId,
      senderUid: senderUid ?? this.senderUid,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      senderPhone: senderPhone ?? this.senderPhone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAddress: locationAddress ?? this.locationAddress,
      tripId: tripId ?? this.tripId,
      tripCode: tripCode ?? this.tripCode,
      startLocationName: startLocationName ?? this.startLocationName,
      destinationName: destinationName ?? this.destinationName,
      message: message ?? this.message,
      notifiedContacts: notifiedContacts ?? this.notifiedContacts,
      status: status ?? this.status,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      locationUpdates: locationUpdates ?? this.locationUpdates,
    );
  }
}
