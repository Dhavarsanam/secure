import 'package:cloud_firestore/cloud_firestore.dart';
import 'emergency_contact_model.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? profileImageUrl;
  final List<String> approvedContacts; // list of emails — used for location-sharing visibility & SOS alert emails
  final List<EmergencyContact> emergencyContacts; // named contacts with phone numbers — shown on the SOS screen
  final bool isLocationSharing;
  // Admin-managed moderation fields (set from the Admin Panel → User
  // Management screen). Real, persisted Firestore fields — not demo data.
  final bool isVerified;
  final bool isBlocked;
  // Grants access to the Admin Panel (see AdminLoginScreen). Only ever set
  // manually on a user's Firestore document — there is no in-app UI that
  // sets this, so it must be enabled by a developer/existing admin
  // directly in the Firebase console (or via a Cloud Function), not by
  // any client-side write path.
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.profileImageUrl,
    this.approvedContacts = const [],
    this.emergencyContacts = const [],
    this.isLocationSharing = false,
    this.isVerified = false,
    this.isBlocked = false,
    this.isAdmin = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      approvedContacts: List<String>.from(map['approvedContacts'] ?? []),
      emergencyContacts: (map['emergencyContacts'] as List<dynamic>? ?? [])
          .map((e) => EmergencyContact.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      isLocationSharing: map['isLocationSharing'] ?? false,
      isVerified: map['isVerified'] ?? false,
      isBlocked: map['isBlocked'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'approvedContacts': approvedContacts,
      'emergencyContacts': emergencyContacts.map((e) => e.toMap()).toList(),
      'isLocationSharing': isLocationSharing,
      'isVerified': isVerified,
      'isBlocked': isBlocked,
      'isAdmin': isAdmin,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    List<String>? approvedContacts,
    List<EmergencyContact>? emergencyContacts,
    bool? isLocationSharing,
    bool? isVerified,
    bool? isBlocked,
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      approvedContacts: approvedContacts ?? this.approvedContacts,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      isLocationSharing: isLocationSharing ?? this.isLocationSharing,
      isVerified: isVerified ?? this.isVerified,
      isBlocked: isBlocked ?? this.isBlocked,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, fullName: $fullName, email: $email)';
  }
}