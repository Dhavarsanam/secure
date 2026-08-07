import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_model.dart';
import '../models/sos_alert_model.dart';
import '../models/user_activity_model.dart';
import '../core/services/firestore_service.dart';
import '../core/services/weather_service.dart';
import '../core/services/traffic_service.dart';

enum NotifType {
  tripCreated,
  tripJoined,       // someone joined a trip I created
  tripJoinedByMe,   // I joined someone else's trip
  tripActive,       // trip's scheduled time has arrived — ride is underway
  tripCompleted,
  tripCancelled,
  sos,
  weatherAlert,
  trafficAlert,
  loginSuccess,
  logout,
  locationShared,
}

class AppNotif {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final NotifType type;
  final String? tripId; // lets the UI open the related trip/SOS/weather screen
  bool isRead;

  AppNotif({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    this.tripId,
    this.isRead = false,
  });
}

/// Builds the Notifications list entirely from REAL app data — a user's
/// trips + SOS alerts (live Firestore streams), plus live weather/traffic
/// conditions for their active trip — instead of a static hardcoded demo
/// list. Every entry has a stable id, so the feed never shows duplicates
/// and updates automatically as the underlying data changes.
class NotificationsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final WeatherService _weatherService = WeatherService();
  final TrafficService _trafficService = TrafficService();

  StreamSubscription<List<TripModel>>? _tripsSub;
  StreamSubscription<List<SosAlertModel>>? _sosSub;
  StreamSubscription<List<UserActivityModel>>? _activitySub;
  Timer? _conditionsTimer;

  List<TripModel> _trips = [];
  List<SosAlertModel> _sosAlerts = [];
  List<UserActivityModel> _activities = [];
  final List<AppNotif> _liveAlerts = []; // weather/traffic — point-in-time checks, not re-derived each build
  Set<String> _readIds = {};
  Set<String> _dismissedIds = {};
  // Hard cutoff set by "Clear All" — once set, every notification with a
  // timestamp at or before this moment is hidden for good, even if the
  // underlying trip/SOS/activity record is later re-read or re-ordered.
  // This is what makes "Clear All" actually behave like clearing old data
  // instead of relying on per-id dismissal (which could miss entries or
  // let old ones resurface). Anything AFTER this moment is fresh/new and
  // always shows.
  int? _clearedBeforeMillis;
  String? _uid;

  String? _lastWeatherKey;
  String? _lastTrafficKey;

  List<AppNotif> get notifications {
    final cutoff = _clearedBeforeMillis;
    final list = _build().where((n) => !_dismissedIds.contains(n.id)).toList();
    final filtered = cutoff == null
        ? list
        : list.where((n) => n.time.millisecondsSinceEpoch > cutoff).toList();
    // Always latest-first, defensively re-sorted here too so the on-screen
    // sequence is guaranteed correct regardless of the order data streams
    // arrived in.
    filtered.sort((a, b) => b.time.compareTo(a.time));
    return filtered;
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  TripModel? tripById(String tripId) {
    for (final t in _trips) {
      if (t.tripId == tripId) return t;
    }
    return null;
  }

  // Call once the signed-in user's uid is known (e.g. from the Home
  // screen's initState, right where trips are already loaded).
  void listenFor(String uid) {
    if (_uid == uid) return; // already listening for this user
    _uid = uid;
    _loadReadState();

    _tripsSub?.cancel();
    _tripsSub = _firestoreService.myTripsStream(uid).listen((trips) {
      _trips = trips;
      notifyListeners();
      _refreshConditionsTimer();
    });

    _sosSub?.cancel();
    _sosSub = _firestoreService.sosAlertsStream(uid).listen((alerts) {
      _sosAlerts = alerts;
      notifyListeners();
    });

    _activitySub?.cancel();
    _activitySub = _firestoreService.userActivityStream(uid).listen((activities) {
      _activities = activities;
      notifyListeners();
    });
  }

  Future<void> _loadReadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _readIds = (prefs.getStringList('notif_read_$_uid') ?? []).toSet();
      _dismissedIds = (prefs.getStringList('notif_dismissed_$_uid') ?? []).toSet();
      _clearedBeforeMillis = prefs.getInt('notif_cleared_before_$_uid');

      // One-time automatic migration: the very first time this device
      // opens the feed after this feature shipped, any old/stale data
      // already sitting in Firestore (old trips, old activity, etc. —
      // e.g. everything from before this update) is auto-cleared exactly
      // like a manual "Clear All", so it never shows up as if it just
      // happened. From this moment on, only genuinely new events (real
      // backend writes that occur AFTER this cutoff) are shown, refreshed
      // live from the streams and always in correct latest-first order.
      const migrationKey = 'notif_v2_migrated';
      final migrated = prefs.getBool('${migrationKey}_$_uid') ?? false;
      if (!migrated) {
        _clearedBeforeMillis = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt('notif_cleared_before_$_uid', _clearedBeforeMillis!);
        await prefs.setBool('${migrationKey}_$_uid', true);
      }

      notifyListeners();
    } catch (_) {
      // Silent fail — read/dismissed state just won't persist this session.
    }
  }

  Future<void> _saveReadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('notif_read_$_uid', _readIds.toList());
      await prefs.setStringList('notif_dismissed_$_uid', _dismissedIds.toList());
      if (_clearedBeforeMillis != null) {
        await prefs.setInt('notif_cleared_before_$_uid', _clearedBeforeMillis!);
      }
    } catch (_) {
      // Silent fail
    }
  }

  // ─── Weather & traffic alerts ────────────────────────
  // Checked for the user's current active trip's destination/route, on a
  // timer, so alerts stay live without spamming duplicate entries — a new
  // notification only fires when the condition actually changes.

  void _refreshConditionsTimer() {
    _conditionsTimer?.cancel();
    final active = _activeTrip;
    if (active == null) return;
    _checkConditions(active); // run once immediately
    _conditionsTimer = Timer.periodic(const Duration(minutes: 15), (_) => _checkConditions(active));
  }

  TripModel? get _activeTrip {
    for (final t in _trips) {
      if (t.status == TripStatus.active) return t;
    }
    return null;
  }

  Future<void> _checkConditions(TripModel trip) async {
    try {
      final weather = await _weatherService.getWeather(
        lat: trip.destinationLat,
        lng: trip.destinationLng,
        cityName: trip.destinationName,
      );
      if (weather != null && weather.alertLevel != 'safe') {
        final dayKey = DateTime.now().toIso8601String().substring(0, 10);
        final key = '${trip.tripId}_${weather.alertLevel}_$dayKey';
        if (key != _lastWeatherKey) {
          _lastWeatherKey = key;
          _addLiveAlert(AppNotif(
            id: 'weather_$key',
            title: 'Weather Alert',
            message: '${weather.alertMessage} Destination: ${trip.destinationName}.',
            time: DateTime.now(),
            type: NotifType.weatherAlert,
            tripId: trip.tripId,
          ));
        }
      }
    } catch (_) {
      // Silent fail — weather is best-effort, never blocks the feed.
    }

    try {
      final traffic = await _trafficService.getRouteTraffic(
        originLat: trip.startLat,
        originLng: trip.startLng,
        destLat: trip.destinationLat,
        destLng: trip.destinationLng,
      );
      if (traffic != null && !traffic.isClear) {
        // Bucketed by hour so a persistently bad traffic condition can
        // re-surface as it evolves, without re-firing every minute.
        final hourKey = DateTime.now().toIso8601String().substring(0, 13);
        final key = '${trip.tripId}_${traffic.level}_$hourKey';
        if (key != _lastTrafficKey) {
          _lastTrafficKey = key;
          _addLiveAlert(AppNotif(
            id: 'traffic_$key',
            title: 'Traffic Alert',
            message: '${traffic.level} on your route to ${trip.destinationName} — about ${traffic.delayMinutes} min delay.',
            time: DateTime.now(),
            type: NotifType.trafficAlert,
            tripId: trip.tripId,
          ));
        }
      }
    } catch (_) {
      // Silent fail — traffic is best-effort, never blocks the feed.
    }
  }

  void _addLiveAlert(AppNotif n) {
    n.isRead = _readIds.contains(n.id);
    _liveAlerts.insert(0, n);
    if (_liveAlerts.length > 30) _liveAlerts.removeRange(30, _liveAlerts.length);
    notifyListeners();
  }

  // ─── Build the combined, deduplicated, newest-first feed ─────

  List<AppNotif> _build() {
    final list = <AppNotif>[];

    for (final t in _trips) {
      if (t.creatorUid == _uid) {
        list.add(AppNotif(
          id: 'trip_created_${t.tripId}',
          title: 'Trip Created Successfully',
          message: 'Your trip ${t.tripCode} ${t.startLocationName} → ${t.destinationName} is created!',
          time: t.createdAt,
          type: NotifType.tripCreated,
          tripId: t.tripId,
        ));

        if (t.bookedSeats > 1) {
          list.add(AppNotif(
            id: 'trip_joined_${t.tripId}_${t.bookedSeats}',
            title: 'Passenger Joined Your Ride',
            message: '${t.bookedSeats}/${t.availableSeats} seats filled on trip ${t.tripCode}.',
            time: t.updatedAt,
            type: NotifType.tripJoined,
            tripId: t.tripId,
          ));
        }
      } else {
        list.add(AppNotif(
          id: 'trip_joined_by_me_${t.tripId}',
          title: 'Joined Trip Successfully',
          message: 'You joined trip ${t.tripCode}: ${t.startLocationName} → ${t.destinationName}.',
          time: t.updatedAt,
          type: NotifType.tripJoinedByMe,
          tripId: t.tripId,
        ));
      }

      // Real "Trip Active" alert — fires once the trip's scheduled time has
      // actually arrived (derived from the trip's own travelDate, never a
      // dummy timer), so it's distinct from "Trip Created" and only shows
      // once the ride is genuinely underway.
      if (t.status == TripStatus.active && !DateTime.now().isBefore(t.travelDate)) {
        list.add(AppNotif(
          id: 'trip_active_${t.tripId}',
          title: 'Trip is Active',
          message: '${t.tripCode} ${t.startLocationName} → ${t.destinationName} is now active.',
          time: t.travelDate,
          type: NotifType.tripActive,
          tripId: t.tripId,
        ));
      }

      if (t.status == TripStatus.completed) {
        list.add(AppNotif(
          id: 'trip_completed_${t.tripId}',
          title: 'Trip Completed Successfully',
          message: '${t.tripCode} ${t.startLocationName} → ${t.destinationName} completed. Rate your ride!',
          time: t.updatedAt,
          type: NotifType.tripCompleted,
          tripId: t.tripId,
        ));
      } else if (t.status == TripStatus.cancelled) {
        list.add(AppNotif(
          id: 'trip_cancelled_${t.tripId}',
          title: 'Trip Cancelled',
          message: '${t.tripCode} ${t.startLocationName} → ${t.destinationName} was cancelled.',
          time: t.updatedAt,
          type: NotifType.tripCancelled,
          tripId: t.tripId,
        ));
      }
    }

    for (final s in _sosAlerts) {
      final resolved = s.status == SosStatus.resolved;
      list.add(AppNotif(
        id: 'sos_${s.alertId}',
        title: resolved ? 'SOS Alert Resolved' : 'SOS Alert Sent',
        message: resolved
            ? 'Your SOS alert has been marked resolved. Stay safe!'
            : 'Your SOS alert was sent to ${s.notifiedContacts.length} contact(s).',
        time: (resolved && s.resolvedAt != null) ? s.resolvedAt! : s.triggeredAt,
        type: NotifType.sos,
        tripId: s.tripId,
      ));
    }

    list.addAll(_liveAlerts);

    // Real account/session events — login, logout, live-location shared —
    // from the user_activity Firestore stream.
    for (final a in _activities) {
      switch (a.type) {
        case UserActivityType.login:
          list.add(AppNotif(
            id: 'activity_${a.activityId}',
            title: 'Login Successfully',
            message: 'You logged in to your account.',
            time: a.timestamp,
            type: NotifType.loginSuccess,
          ));
          break;
        case UserActivityType.logout:
          list.add(AppNotif(
            id: 'activity_${a.activityId}',
            title: 'Logout',
            message: 'You logged out of your account.',
            time: a.timestamp,
            type: NotifType.logout,
          ));
          break;
        case UserActivityType.locationShared:
          list.add(AppNotif(
            id: 'activity_${a.activityId}',
            title: 'Live Location Shared',
            message: 'Your live location is now being shared.',
            time: a.timestamp,
            type: NotifType.locationShared,
          ));
          break;
      }
    }

    for (final n in list) {
      n.isRead = _readIds.contains(n.id);
    }

    list.sort((a, b) => b.time.compareTo(a.time)); // latest first
    return list;
  }

  void markRead(String id) {
    _readIds.add(id);
    _saveReadState();
    notifyListeners();
  }

  void markAllRead() {
    for (final n in _build()) {
      _readIds.add(n.id);
    }
    _saveReadState();
    notifyListeners();
  }

  void dismiss(String id) {
    _dismissedIds.add(id);
    _saveReadState();
    notifyListeners();
  }

  // Clears every notification currently visible. Uses a hard timestamp
  // cutoff (not per-id dismissal) so old data can never resurface — only
  // notifications that arrive fresh AFTER this moment will show up.
  void clearAll() {
    _clearedBeforeMillis = DateTime.now().millisecondsSinceEpoch;
    _saveReadState();
    notifyListeners();
  }

  @override
  void dispose() {
    _tripsSub?.cancel();
    _sosSub?.cancel();
    _activitySub?.cancel();
    _conditionsTimer?.cancel();
    super.dispose();
  }
}