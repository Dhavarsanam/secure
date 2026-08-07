// A named emergency contact with a real phone number and a relation tag
// (Family / Friend / Other) — shown on the SOS screen for one-tap calling.
//
// This is distinct from UserModel.approvedContacts (a plain list of emails
// used for location-sharing visibility and SOS alert emails). Adding or
// removing an EmergencyContact keeps that email list in sync automatically
// (see AuthProvider), so location sharing and SOS emails keep working too.
class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String relation; // 'Family' | 'Friend' | 'Other'

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.relation,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      relation: map['relation']?.toString() ?? 'Other',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'relation': relation,
  };

  EmergencyContact copyWith({String? name, String? phone, String? email, String? relation}) {
    return EmergencyContact(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      relation: relation ?? this.relation,
    );
  }
}