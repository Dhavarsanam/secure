import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:telephony/telephony.dart';

import 'location_service.dart';

class SosService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();

  // Gmail credentials — set in .env
  static const String _gmailUser =
  String.fromEnvironment('GMAIL_USERNAME', defaultValue: '');
  static const String _gmailPassword =
  String.fromEnvironment('GMAIL_APP_PASSWORD', defaultValue: '');

  // Public page (see web/track.html, deployed via Firebase Hosting) that
  // reads the sos_alerts/{id} document LIVE from Firestore and shows a
  // marker that moves on its own as the sender's location updates — this
  // is the "live location" link texted/emailed to emergency contacts.
  // If you host the tracker page somewhere else, update this base URL.
  static const String _trackingBaseUrl =
      'https://ride-4f466.web.app/track.html';

  Timer? _periodicTimer;
  StreamSubscription<Position>? _liveTrackingSub;
  String? _activeSosId;

  // Remembered from the moment SOS goes live so cancelSos() can text the
  // exact same contacts the "I'm safe now" message without the caller
  // having to pass everything a second time.
  List<String> _activeContactPhones = [];
  Position? _lastKnownPosition;

  bool get isSosActive => _activeSosId != null;

  String trackingUrlFor(String alertId) => '$_trackingBaseUrl?id=$alertId';

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
        // Pass along *why* (GPS off, permission denied, etc.) so the SOS
        // screen can show a friendly, specific message instead of a
        // generic failure — e.g. a "turn on your location" prompt with a
        // one-tap settings shortcut when the device's location is off.
        return {
          'success': false,
          'error': _locationService.lastErrorMessage ?? 'Could not get location.',
          'errorReason': _locationService.lastErrorReason.name,
        };
      }
      _lastKnownPosition = position;

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
        'lastUpdated': FieldValue.serverTimestamp(),
        'resolvedAt': null,
        'locationUpdates': [],
      };

      // Save to Firestore
      final doc = await _db.collection('sos_alerts').add(alertData);
      _activeSosId = doc.id;
      final trackingUrl = trackingUrlFor(doc.id);

      // Send emails (now includes the live-tracking link too)
      await _sendSosEmails(
        contacts: approvedContacts,
        senderName: senderName,
        senderPhone: senderPhone,
        lat: position.latitude,
        lng: position.longitude,
        address: address ?? 'Unknown location',
        trackingUrl: trackingUrl,
        tripCode: tripCode,
        startLocation: startLocationName,
        destination: destinationName,
      );

      // Start CONTINUOUS live location tracking: every real GPS movement
      // (not just a once-every-2-minutes poll) is pushed straight to
      // Firestore, so the tracking page always shows where the user
      // actually is right now, updating on its own as they move.
      _startLiveTracking(doc.id);

      // Keep the existing periodic email nudge every 2 minutes (unchanged
      // cadence/feature) — it now just reuses whatever the live-tracking
      // stream has most recently seen instead of doing a second GPS fetch.
      _startPeriodicEmailUpdates(
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
        'trackingUrl': trackingUrl,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Sends the SOS SMS (with the live-tracking link) to every given phone
  // number.
  //
  // Android: sent silently in the background via the device's own SIM
  // (SmsManager, through the `telephony` plugin) as long as the user has
  // granted SEND_SMS — no SMS app opens, no tap needed.
  // iOS: Apple gives no API for a third-party app to send SMS without the
  // user tapping Send in Messages — there is no way around this on iOS, so
  // it falls back to opening the pre-filled Messages sheet there (and on
  // Android too if SEND_SMS wasn't granted).
  Future<bool> shareSosViaSms({
    required List<String> phoneNumbers,
    required String senderName,
    required String senderPhone,
    required String trackingUrl,
    double? lat,
    double? lng,
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

    // Remembered so cancelSos() can send the "I'm safe now" text to the
    // same people, without the SOS screen having to pass it in again.
    _activeContactPhones = cleaned.toList();

    final tripLine = tripCode != null
        ? ' Trip: $tripCode (${startLocation ?? '?'} -> ${destination ?? '?'}).'
        : '';
    final body = '🚨 EMERGENCY! $senderName needs help.'
        '${address != null ? ' Near: $address.' : ''}'
        ' Live location (updates automatically as I move): $trackingUrl'
        ' Contact: $senderPhone.$tripLine';

    return _sendSms(cleaned, body);
  }

  // Shared send path: try silent Android SmsManager send first, then fall
  // back to opening the device's Messages app pre-filled (needed on iOS
  // always, and on Android if SEND_SMS wasn't granted).
  Future<bool> _sendSms(Set<String> numbers, String body) async {
    if (numbers.isEmpty) return false;

    if (Platform.isAndroid) {
      final sentSilently = await _sendSmsSilentlyAndroid(numbers, body);
      if (sentSilently) return true;
      // Permission not granted / send failed -> fall through to the
      // pre-filled Messages sheet below.
    }

    final uri = Uri(scheme: 'sms', path: numbers.join(','), queryParameters: {'body': body});
    try {
      return await launchUrl(uri);
    } catch (e) {
      return false;
    }
  }

  // Tries to send directly via SmsManager with no UI. Returns false if the
  // SEND_SMS permission isn't granted or a send call throws, so the caller
  // can fall back to the Messages-sheet approach.
  Future<bool> _sendSmsSilentlyAndroid(Set<String> numbers, String body) async {
    try {
      final telephony = Telephony.instance;
      final granted = await telephony.requestSmsPermissions;
      if (granted != true) return false;

      var anySent = false;
      for (final number in numbers) {
        try {
          await telephony.sendSms(to: number, message: body);
          anySent = true;
        } catch (_) {
          // Skip this number, try the rest.
        }
      }
      return anySent;
    } catch (_) {
      return false;
    }
  }

  // Cancel SOS: stops live tracking + the periodic email timer, marks the
  // alert resolved in Firestore, and automatically sends ONE follow-up SMS
  // to the same contacts letting them know it's over.
  Future<bool> cancelSos() async {
    try {
      _periodicTimer?.cancel();
      _periodicTimer = null;
      await _liveTrackingSub?.cancel();
      _liveTrackingSub = null;

      final wasActive = _activeSosId != null;

      if (_activeSosId != null) {
        await _db.collection('sos_alerts').doc(_activeSosId).update({
          'status': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
        });
      }

      // Let the contacts who got the emergency text know it's over, so
      // they stop worrying and know the (now-frozen) tracking link is done.
      if (wasActive && _activeContactPhones.isNotEmpty) {
        const safeBody = 'Trip Safe: The SOS alert has been cancelled. '
            "I'm safe now. No further assistance is needed.";
        await _sendSms(_activeContactPhones.toSet(), safeBody);
      }

      _activeSosId = null;
      _activeContactPhones = [];
      _lastKnownPosition = null;
      return true;
    } catch (e) {
      return false;
    }
  }

  // Continuous live location tracking: listens to the device's GPS stream
  // (see LocationService.positionStream — fires on real movement, ~10m
  // filter) and pushes every fix straight to Firestore. This is what makes
  // the tracking link show the CURRENT position updating in real time,
  // instead of a single one-time snapshot.
  void _startLiveTracking(String alertId) {
    _liveTrackingSub?.cancel();
    _liveTrackingSub = _locationService.positionStream().listen(
          (position) async {
        _lastKnownPosition = position;
        try {
          await _db.collection('sos_alerts').doc(alertId).update({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'lastUpdated': FieldValue.serverTimestamp(),
            'locationUpdates': FieldValue.arrayUnion([
              {
                'lat': position.latitude,
                'lng': position.longitude,
                'timestamp': DateTime.now().toIso8601String(),
              }
            ]),
          });
        } catch (_) {
          // A single failed write (brief network drop) shouldn't kill the
          // stream — it just keeps listening for the next fix.
        }
      },
      onError: (_) {
        // GPS turned off / permission revoked mid-SOS: don't crash, the
        // periodic email updates below still use the last known fix.
      },
    );
  }

  // Existing periodic email nudge every 2 minutes — unchanged cadence,
  // now just reads the last position seen by the live-tracking stream
  // (falling back to a fresh fetch only if that stream hasn't fired yet).
  void _startPeriodicEmailUpdates({
    required List<String> contacts,
    required String senderName,
    required String senderPhone,
  }) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      final position = _lastKnownPosition ?? await _locationService.getCurrentPosition();
      if (position == null) return;
      _lastKnownPosition = position;

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
    required String trackingUrl,
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
    <h3>📍 Live Location</h3>
    <p>$address</p>
    <p><a href="$trackingUrl" style="background: #DC2626; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none;">🔴 Track Live Location</a></p>
    <p style="font-size: 12px; color: #6B7280;">This link updates automatically as $senderName moves — no need to refresh.</p>
    <p><a href="$mapsUrl" style="color: #1A73E8; font-size: 13px;">View starting point on Google Maps</a></p>
    <hr>
    <h3>📞 Contact</h3>
    <p>Phone: <strong>$senderPhone</strong></p>
    <p>Email: <strong>$_gmailUser</strong></p>
    $tripInfo
    <hr>
    <p style="color: #6B7280; font-size: 13px;">
      This is an automated emergency alert from SecureRide.<br>
      Location updates live until the alert is cancelled.
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