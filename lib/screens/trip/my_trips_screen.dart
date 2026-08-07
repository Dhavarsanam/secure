import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/trip_model.dart';
import 'create_trip_screen.dart';
import 'join_trip_screen.dart';
import 'trip_detail_screen.dart';
import 'trip_history_screen.dart';
import '../../utils/app_icon_colors.dart';

const _kPrimary = Color(0xFF1A73E8);
const _kPrimaryDark = Color(0xFF0D47A1);
const _kSuccess = Color(0xFF22C55E);
const _kDanger = Color(0xFFEF4444);
const _kAmber = Color(0xFFF59E0B);
const _kPurple = Color(0xFF7C3AED);

class MyTripsScreen extends StatelessWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trips = context.watch<TripProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    // Card surface follows the app's light/dark theme, same as every
    // other screen (SOS, trip detail, etc.) — dark navy in dark mode,
    // white in light mode.
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final uid = auth.currentUser?.uid ?? '';

    final active = trips.activeTrips;
    final completed = trips.completedTrips;
    final cancelled = trips.myTrips.where((t) => t.status == TripStatus.cancelled).toList();

    Future<void> onRefresh() async {
      // The list is backed by a live Firestore stream, so a pull just
      // resubscribes + gives a short delay for a satisfying refresh cue —
      // any backend change already reflects automatically otherwise.
      trips.loadDummyTrips(uid);
      await Future.delayed(const Duration(milliseconds: 650));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(128),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kPrimary, _kPrimaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 12, 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('My Trips',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.history_rounded, color: Colors.white),
                          tooltip: 'Trip History',
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripHistoryScreen())),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          color: _kPrimaryDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                        tabs: [
                          Tab(text: 'Active (${active.length})'),
                          Tab(text: 'Completed (${completed.length})'),
                          Tab(text: 'Cancelled (${cancelled.length})'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _kPrimary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: FloatingActionButton.extended(
            backgroundColor: _kPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('New Trip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTripScreen())),
          ),
        ),
        body: TabBarView(
          children: [
            _ActiveTripsView(trips: active, card: card, tp: tp, ts: ts, isDark: isDark, uid: uid, onRefresh: onRefresh),
            _TripList(
              trips: completed,
              card: card, tp: tp, ts: ts, isDark: isDark, uid: uid, onRefresh: onRefresh,
              emptyTitle: 'No Completed Trips',
              emptyMsg: 'Trips you finish will show up\nhere once they wrap up.',
              emptyIcon: Icons.check_circle_outline_rounded,
            ),
            _TripList(
              trips: cancelled,
              card: card, tp: tp, ts: ts, isDark: isDark, uid: uid, onRefresh: onRefresh,
              emptyTitle: 'No Cancelled Trips',
              emptyMsg: 'Trips you or the creator cancel\nwill be listed here for reference.',
              emptyIcon: Icons.event_busy_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// Active tab: shows two sections — Upcoming Trips and Past Trips.
// All active-status trips go under "Upcoming" (an active trip is, by definition, not yet completed).
// "Past Trips" here means an active trip whose scheduled date has already gone by (overdue/missed),
// not completed trips — those live in the separate "Completed" tab.
class _ActiveTripsView extends StatelessWidget {
  final List<TripModel> trips;
  final Color card, tp, ts;
  final bool isDark;
  final String uid;
  final Future<void> Function() onRefresh;
  const _ActiveTripsView({required this.trips, required this.card, required this.tp, required this.ts,
    required this.isDark, required this.uid, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return _EmptyState(
        icon: Icons.directions_car_outlined,
        title: 'No Active Trips',
        message: 'You don\'t have any ongoing or\nupcoming trips right now.',
        tp: tp, ts: ts, isDark: isDark,
        onRefresh: onRefresh,
        action: ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinTripScreen())),
          icon: const Icon(Icons.group_add_rounded, color: Colors.white),
          label: const Text('Join a Trip'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    final now = DateTime.now();
    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    final ongoing = trips.where((t) => sameDay(t.travelDate, now)).toList();
    final upcoming = trips.where((t) => t.travelDate.isAfter(now) && !sameDay(t.travelDate, now)).toList();
    final overdue = trips.where((t) => t.travelDate.isBefore(now) && !sameDay(t.travelDate, now)).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _kPrimary,
      backgroundColor: card,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          if (ongoing.isNotEmpty) ...[
            _SectionHeader(title: 'Ongoing Today', tp: tp),
            const SizedBox(height: 10),
            ...ongoing.map((t) => _TripCard(trip: t, card: card, tp: tp, ts: ts, isDark: isDark, uid: uid, badgeOverride: _CardBadge.ongoing)),
            const SizedBox(height: 18),
          ],
          _SectionHeader(title: 'Upcoming Trips', tp: tp),
          const SizedBox(height: 10),
          if (upcoming.isEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 18),
                child: Text('No upcoming trips.', style: TextStyle(color: ts, fontSize: 13)))
          else ...[
            ...upcoming.map((t) => _TripCard(trip: t, card: card, tp: tp, ts: ts, isDark: isDark, uid: uid, badgeOverride: _CardBadge.upcoming)),
            const SizedBox(height: 18),
          ],
          if (overdue.isNotEmpty) ...[
            _SectionHeader(title: 'Past Trips', tp: tp),
            const SizedBox(height: 10),
            ...overdue.map((t) => _TripCard(trip: t, card: card, tp: tp, ts: ts, isDark: isDark, uid: uid, badgeOverride: _CardBadge.overdue)),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color tp;
  const _SectionHeader({required this.title, required this.tp});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 4, height: 15, decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: tp)),
    ]);
  }
}

class _TripList extends StatelessWidget {
  final List<TripModel> trips;
  final String emptyTitle, emptyMsg, uid;
  final IconData emptyIcon;
  final Color card, tp, ts;
  final bool isDark;
  final Future<void> Function() onRefresh;

  const _TripList({required this.trips, required this.emptyTitle, required this.emptyMsg, required this.emptyIcon,
    required this.card, required this.tp, required this.ts, required this.isDark, required this.uid, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return _EmptyState(icon: emptyIcon, title: emptyTitle, message: emptyMsg, tp: tp, ts: ts, isDark: isDark, onRefresh: onRefresh);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _kPrimary,
      backgroundColor: card,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: trips.length,
        itemBuilder: (context, index) => _TripCard(trip: trips[index], card: card, tp: tp, ts: ts, isDark: isDark, uid: uid),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, message;
  final Color tp, ts;
  final bool isDark;
  final Widget? action;
  final Future<void> Function() onRefresh;
  const _EmptyState({required this.icon, required this.title, required this.message,
    required this.tp, required this.ts, required this.isDark, required this.onRefresh, this.action});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _kPrimary,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.08),
          SizedBox(
            height: 190,
            child: Lottie.asset('assets/animations/empty_state.json', repeat: true,
                errorBuilder: (context, error, stack) => Icon(icon, size: 80, color: appIconColor(icon))),
          ),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center,
              style: TextStyle(color: tp, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center,
              style: TextStyle(color: ts, fontSize: 13.5, height: 1.4)),
          if (action != null) ...[
            const SizedBox(height: 22),
            Center(child: action!),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

enum _CardBadge { ongoing, upcoming, overdue, none }

// Single trip card — used by both the plain tab lists and the Upcoming/Past split view
class _TripCard extends StatelessWidget {
  final TripModel trip;
  final Color card, tp, ts;
  final bool isDark;
  final String uid;
  final _CardBadge badgeOverride;
  const _TripCard({required this.trip, required this.card, required this.tp, required this.ts,
    required this.isDark, required this.uid, this.badgeOverride = _CardBadge.none});

  Color _statusColor(TripStatus s) {
    switch (s) {
      case TripStatus.active: return _kSuccess;
      case TripStatus.completed: return _kPrimary;
      case TripStatus.cancelled: return _kDanger;
    }
  }

  IconData _vehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bike': return Icons.two_wheeler_rounded;
      case 'auto': return Icons.electric_rickshaw_rounded;
      case 'van': return Icons.airport_shuttle_rounded;
      case 'bus': return Icons.directions_bus_rounded;
      default: return Icons.directions_car_rounded;
    }
  }

  ({String label, Color color, IconData icon, bool pulse}) _badgeFor(TripStatus s) {
    if (s == TripStatus.completed) return (label: 'COMPLETED', color: _kPrimary, icon: Icons.check_circle_rounded, pulse: false);
    if (s == TripStatus.cancelled) return (label: 'CANCELLED', color: _kDanger, icon: Icons.cancel_rounded, pulse: false);
    switch (badgeOverride) {
      case _CardBadge.ongoing: return (label: 'ONGOING', color: _kSuccess, icon: Icons.podcasts_rounded, pulse: true);
      case _CardBadge.overdue: return (label: 'OVERDUE', color: _kAmber, icon: Icons.warning_amber_rounded, pulse: false);
      case _CardBadge.upcoming:
      case _CardBadge.none:
        return (label: 'UPCOMING', color: _kPurple, icon: Icons.schedule_rounded, pulse: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(trip.status);
    final isCreator = trip.creatorUid == uid;
    final badge = _badgeFor(trip.status);
    final dateStr = DateFormat('d MMM yyyy').format(trip.travelDate);
    final timeStr = DateFormat('hh:mm a').format(trip.travelDate);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored top accent strip
            Container(height: 4, color: statusColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Status + creator/passenger badges
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: badge.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (badge.pulse) ...[
                        const _LiveDot(color: _kSuccess),
                        const SizedBox(width: 5),
                      ] else ...[
                        Icon(badge.icon, size: 12, color: badge.color),
                        const SizedBox(width: 4),
                      ],
                      Text(badge.label, style: TextStyle(color: badge.color, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                    ]),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                        color: (isCreator ? _kPurple : _kSuccess).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(isCreator ? Icons.workspace_premium_rounded : Icons.person_rounded,
                          size: 12, color: isCreator ? _kPurple : _kSuccess),
                      const SizedBox(width: 4),
                      Text(isCreator ? 'Creator' : 'Passenger',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold,
                              color: isCreator ? _kPurple : _kSuccess)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),

                // Route: source -> destination with connector
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 16,
                    child: Column(children: [
                      Container(width: 10, height: 10,
                          decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle)),
                      SizedBox(
                        height: 26,
                        child: Center(
                          child: Container(width: 2, height: 22,
                              decoration: BoxDecoration(color: ts.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(1))),
                        ),
                      ),
                      const Icon(Icons.location_on_rounded, size: 15, color: _kDanger),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(trip.startLocationName, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: tp, fontWeight: FontWeight.w600, fontSize: 14.5)),
                      const SizedBox(height: 22),
                      Text(trip.destinationName, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: tp, fontWeight: FontWeight.w600, fontSize: 14.5)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: ts, size: 20),
                ]),
                const SizedBox(height: 14),
                Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                const SizedBox(height: 12),

                // Date & time
                Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 13, color: appIconColor(Icons.calendar_today_rounded)),
                  const SizedBox(width: 6),
                  Text(dateStr, style: TextStyle(fontSize: 12.5, color: ts, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time_rounded, size: 13, color: appIconColor(Icons.access_time_rounded)),
                  const SizedBox(width: 6),
                  Text(timeStr, style: TextStyle(fontSize: 12.5, color: ts, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 8),

                // Vehicle & seats
                Row(children: [
                  Icon(_vehicleIcon(trip.vehicleType), size: 14, color: appIconColor(_vehicleIcon(trip.vehicleType))),
                  const SizedBox(width: 6),
                  Text(trip.vehicleType, style: TextStyle(fontSize: 12.5, color: ts, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 16),
                  Icon(Icons.people_alt_rounded, size: 14, color: appIconColor(Icons.people_alt_rounded)),
                  const SizedBox(width: 6),
                  Text('${trip.bookedSeats}/${trip.availableSeats} Seats',
                      style: TextStyle(fontSize: 12.5, color: ts, fontWeight: FontWeight.w500)),
                ]),
              ]),
            ),
            if (trip.status == TripStatus.cancelled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: _kDanger.withValues(alpha: 0.08),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: _kDanger),
                  SizedBox(width: 6),
                  Text('This trip was cancelled', style: TextStyle(color: _kDanger, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

// Small pulsing "live" indicator dot used on ongoing-today trip badges.
class _LiveDot extends StatefulWidget {
  final Color color;
  const _LiveDot({required this.color});
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(width: 7, height: 7, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}