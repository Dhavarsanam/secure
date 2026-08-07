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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, fullName: $fullName, email: $email)';
  }
}