import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:url_launcher/url_launcher.dart';

import 'location_service.dart';

class SosService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();

  // Gmail credentials — set in .env
  static const String _gmailUser =
  String.fromEnvironment('GMAIL_USERNAME', defaultValue: '');
  static const String _gmailPassword =
  String.fromEnvironment('GMAIL_APP_PASSWORD', defaultValue: '');

  Timer? _periodicTimer;
  String? _activeSosId;

  bool get isSosActive => _activeSosId != null;

  // Trigger SOS alert
  Future<Map<String, dynamic>> triggerSos({
    required String senderUid,
    required String senderName,
    required String senderEmail,
    required String senderPhone,
    required List<String> approvedContacts,
    String? tripId,
    String? tripCode,
    String? startLocationName,
    String? destinationName,
  }) async {
    try {
      // Get current location
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        return {'success': false, 'error': 'Could not get location.'};
      }

      // Get address
      final address = await _locationService
          ._dummyAddress(position.latitude, position.longitude);

      final alertData = {
        'senderUid': senderUid,
        'senderName': senderName,
        'senderEmail': senderEmail,
        'senderPhone': senderPhone,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'locationAddress': address,
        'tripId': tripId,
        'tripCode': tripCode,
        'startLocationName': startLocationName,
        'destinationName': destinationName,
        'message': 'EMERGENCY! I need immediate help!',
        'notifiedContacts': approvedContacts,
        'status': 'active',
        'triggeredAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
        'locationUpdates': [],
      };

      // Save to Firestore
      final doc = await _db.collection('sos_alerts').add(alertData);
      _activeSosId = doc.id;

      // Send emails
      await _sendSosEmails(
        contacts: approvedContacts,
        senderName: senderName,
        senderPhone: senderPhone,
        lat: position.latitude,
        lng: position.longitude,
        address: address ?? 'Unknown location',
        tripCode: tripCode,
        startLocation: startLocationName,
        destination: destinationName,
      );

      // Start periodic updates every 2 minutes
      _startPeriodicUpdates(
        alertId: doc.id,
        senderUid: senderUid,
        contacts: approvedContacts,
        senderName: senderName,
        senderPhone: senderPhone,
      );

      return {
        'success': true,
        'alertId': doc.id,
        'lat': position.latitude,
        'lng': position.longitude,
        'address': address,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Opens the device's SMS app with a pre-filled emergency message
  // addressed to every given phone number. This needs no Gmail/SMTP setup
  // and works the same on Android and iOS — the user just has to tap Send
  // once the app opens (neither platform allows a normal app to send SMS
  // silently without the message app in between).
  Future<bool> shareSosViaSms({
    required List<String> phoneNumbers,
    required String senderName,
    required String senderPhone,
    required double lat,
    required double lng,
    String? address,
    String? tripCode,
    String? startLocation,
    String? destination,
  }) async {
    // Clean + dedupe: keep only digits and a leading +, drop empties/dupes.
    final cleaned = <String>{};
    for (final raw in phoneNumbers) {
      final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
      if (digits.length >= 6) cleaned.add(digits);
    }
    if (cleaned.isEmpty) return false;

    final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final tripLine = tripCode != null ? ' Trip: $tripCode (${startLocation ?? '?'} -> ${destination ?? '?'}).' : '';
    final body = '🚨 EMERGENCY! $senderName needs help.'
        ' Location: ${address ?? '$lat,$lng'}.'
        ' Map: $mapsUrl'
        ' Contact: $senderPhone.$tripLine';

    final uri = Uri(scheme: 'sms', path: cleaned.join(','), queryParameters: {'body': body});
    try {
      return await launchUrl(uri);
    } catch (e) {
      return false;
    }
  }

  // Cancel SOS
  Future<bool> cancelSos() async {
    try {
      _periodicTimer?.cancel();
      _periodicTimer = null;

      if (_activeSosId != null) {
        await _db.collection('sos_alerts').doc(_activeSosId).update({
          'status': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
        });
        _activeSosId = null;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Start periodic location updates
  void _startPeriodicUpdates({
    required String alertId,
    required String senderUid,
    required List<String> contacts,
    required String senderName,
    required String senderPhone,
  }) {
    _periodicTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      final position = await _locationService.getCurrentPosition();
      if (position == null) return;

      // Update Firestore
      await _db.collection('sos_alerts').doc(alertId).update({
        'locationUpdates': FieldValue.arrayUnion([
          {
            'lat': position.latitude,
            'lng': position.longitude,
            'timestamp': DateTime.now().toIso8601String(),
          }
        ]),
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      // Send update email
      await _sendUpdateEmails(
        contacts: contacts,
        senderName: senderName,
        senderPhone: senderPhone,
        lat: position.latitude,
        lng: position.longitude,
      );
    });
  }

  // Send SOS emails via Gmail SMTP
  Future<void> _sendSosEmails({
    required List<String> contacts,
    required String senderName,
    required String senderPhone,
    required double lat,
    required double lng,
    required String address,
    String? tripCode,
    String? startLocation,
    String? destination,
  }) async {
    if (_gmailUser.isEmpty || _gmailPassword.isEmpty) return;
    if (contacts.isEmpty) return;

    try {
      final smtpServer = gmail(_gmailUser, _gmailPassword);
      final mapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

      final tripInfo = tripCode != null
          ? '''
Trip Details:
• Trip Code: $tripCode
• From: ${startLocation ?? 'N/A'}
• To: ${destination ?? 'N/A'}
'''
          : '';

      final message = Message()
        ..from = Address(_gmailUser, 'SecureRide SOS Alert')
        ..recipients.addAll(contacts)
        ..subject = '🚨 EMERGENCY SOS - $senderName needs help!'
        ..html = '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <div style="background: #DC2626; padding: 20px; border-radius: 8px 8px 0 0;">
    <h1 style="color: white; margin: 0;">🚨 EMERGENCY SOS ALERT</h1>
  </div>
  <div style="background: #FFF; padding: 20px; border: 1px solid #E5E7EB;">
    <p style="font-size: 16px;"><strong>$senderName</strong> has triggered an emergency SOS alert!</p>
    <hr>
    <h3>📍 Current Location</h3>
    <p>$address</p>
    <p><a href="$mapsUrl" style="background: #1A73E8; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none;">View on Google Maps</a></p>
    <hr>
    <h3>📞 Contact</h3>
    <p>Phone: <strong>$senderPhone</strong></p>
    <p>Email: <strong>$_gmailUser</strong></p>
    $tripInfo
    <hr>
    <p style="color: #6B7280; font-size: 13px;">
      This is an automated emergency alert from SecureRide.<br>
      Location updates will be sent every 2 minutes until the alert is cancelled.
    </p>
  </div>
</div>
''';

      await send(message, smtpServer);
    } catch (e) {
      // Email failed — silent fail, Firestore already saved
    }
  }

  // Send periodic update emails
  Future<void> _sendUpdateEmails({
    required List<String> contacts,
    required String senderName,
    required String senderPhone,
    required double lat,
    required double lng,
  }) async {
    if (_gmailUser.isEmpty || _gmailPassword.isEmpty) return;
    if (contacts.isEmpty) return;

    try {
      final smtpServer = gmail(_gmailUser, _gmailPassword);
      final mapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      final time = DateTime.now().toString().substring(0, 16);

      final message = Message()
        ..from = Address(_gmailUser, 'SecureRide SOS Alert')
        ..recipients.addAll(contacts)
        ..subject = '📍 SOS Update - $senderName location at $time'
        ..html = '''
<div style="font-family: Arial, sans-serif; max-width: 600px;">
  <div style="background: #F59E0B; padding: 16px; border-radius: 8px 8px 0 0;">
    <h2 style="color: white; margin: 0;">📍 Location Update</h2>
  </div>
  <div style="background: #FFF; padding: 20px; border: 1px solid #E5E7EB;">
    <p><strong>$senderName</strong> SOS is still active.</p>
    <p>Updated location at $time:</p>
    <p><a href="$mapsUrl" style="background: #1A73E8; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none;">View Current Location</a></p>
    <p style="color: #6B7280; font-size: 13px;">Phone: $senderPhone</p>
  </div>
</div>
''';

      await send(message, smtpServer);
    } catch (e) {
      // Silent fail
    }
  }
}

// Extension for dummy address when reverse geocoding not available
extension on LocationService {
  Future<String?> _dummyAddress(double lat, double lng) async {
    return await reverseGeocode(lat, lng) ??
        'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
  }

  Future<String?> reverseGeocode(double lat, double lng) async {
    return null; // Will be implemented via GeocodingService
  }
}