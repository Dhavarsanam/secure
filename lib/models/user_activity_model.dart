import 'package:cloud_firestore/cloud_firestore.dart';

// Real account/session events (login, logout, live-location sharing
// turned on) written to Firestore the instant they happen, so the
// Notifications feed can show them exactly like trip/SOS/weather
// alerts — from real backend data, never a hardcoded demo entry.
enum UserActivityType { login, logout, locationShared }

class UserActivityModel {
  final String activityId;
  final String uid;
  final UserActivityType type;
  final DateTime timestamp;

  UserActivityModel({
    required this.activityId,
    required this.uid,
    required this.type,
    required this.timestamp,
  });

  factory UserActivityModel.fromMap(Map<String, dynamic> map, String activityId) {
    return UserActivityModel(
      activityId: activityId,
      uid: map['uid'] ?? '',
      type: UserActivityType.values.firstWhere(
            (e) => e.name == (map['type'] ?? 'login'),
        orElse: () => UserActivityType.login,
      ),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'type': type.name,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}