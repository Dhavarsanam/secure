import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/trip_model.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import 'otp_verification_screen.dart';
import 'rating_review_screen.dart';
import 'user_profile_screen.dart';
import '../../utils/app_icon_colors.dart';

class TripDetailScreen extends StatelessWidget {
  final TripModel trip;
  const TripDetailScreen({super.key, required this.trip});

  String _formatDate(DateTime date) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60; final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final isCreator = trip.creatorUid == auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        title: Text('Trip #${trip.tripCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.copy, color: appIconColor(Icons.copy)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: trip.tripCode));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Trip code copied!'),
                backgroundColor: const Color(0xFF1A73E8),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              ));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: trip.status == TripStatus.active
                  ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                  : const Color(0xFF6B7280).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: trip.status == TripStatus.active
                  ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                  : const Color(0xFF6B7280).withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(trip.status == TripStatus.active ? Icons.directions_car : Icons.check_circle, color: appIconColor(trip.status == TripStatus.active ? Icons.directions_car : Icons.check_circle), size: 28),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trip.status.name.toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                        color: trip.status == TripStatus.active ? const Color(0xFF22C55E) : const Color(0xFF6B7280))),
                Text(isCreator ? 'You created this trip' : 'You joined this trip',
                    style: TextStyle(fontSize: 12, color: ts)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(trip.tripCode, style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // Route Card
          _Card(card: card, child: Column(children: [
            _Row(icon: Icons.radio_button_checked, iconColor: const Color(0xFF1A73E8), label: 'From', value: trip.startLocationName, tp: tp, ts: ts),
            Padding(padding: const EdgeInsets.only(left: 10), child: Container(height: 20, width: 2, color: const Color(0xFFE5E7EB))),
            _Row(icon: Icons.location_on, iconColor: const Color(0xFFEF4444), label: 'To', value: trip.destinationName, tp: tp, ts: ts),
            if (trip.distanceKm != null) ...[
              const Divider(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _Stat(icon: Icons.straighten, label: 'Distance', value: '${trip.distanceKm!.toStringAsFixed(1)} km', color: const Color(0xFF1A73E8), tp: tp, ts: ts),
                _Stat(icon: Icons.access_time, label: 'Duration', value: trip.durationMinutes != null ? _formatDuration(trip.durationMinutes!) : 'N/A', color: const Color(0xFFF59E0B), tp: tp, ts: ts),
                _Stat(icon: Icons.people, label: 'Seats', value: '${trip.bookedSeats}/${trip.availableSeats}', color: const Color(0xFF22C55E), tp: tp, ts: ts),
              ]),
            ],
          ])),

          const SizedBox(height: 12),

          // Trip Info
          _Card(card: card, child: Column(children: [
            _Row(icon: Icons.calendar_today, iconColor: const Color(0xFF1A73E8), label: 'Travel Date', value: _formatDate(trip.travelDate), tp: tp, ts: ts),
            const Divider(height: 20),
            _Row(icon: Icons.person, iconColor: const Color(0xFF22C55E), label: 'Passenger Type', value: trip.passengerType, tp: tp, ts: ts),
            const Divider(height: 20),
            _Row(icon: Icons.directions_car, iconColor: const Color(0xFFF59E0B), label: 'Vehicle Type', value: trip.vehicleType, tp: tp, ts: ts),
            const Divider(height: 20),
            _Row(icon: Icons.person_outline, iconColor: const Color(0xFF6B7280), label: 'Created By', value: trip.creatorName, tp: tp, ts: ts),
          ])),

          const SizedBox(height: 12),

          // Members
          _Card(card: card, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Trip Members (${trip.memberEmails.length})', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 15)),
            const SizedBox(height: 12),
            ...trip.memberEmails.map((email) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                CircleAvatar(radius: 16,
                    backgroundColor: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                    child: Text(email[0].toUpperCase(), style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(width: 10),
                Expanded(child: Text(email, style: TextStyle(color: tp, fontSize: 13), overflow: TextOverflow.ellipsis)),
                if (email == trip.creatorEmail)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: const Text('Creator', style: TextStyle(color: Color(0xFF1A73E8), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ]),
            )),
          ])),

          // OTP Section
          if (trip.status == TripStatus.active) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.verified_user, color: Color(0xFF1A73E8), size: 20),
                  const SizedBox(width: 8),
                  Text('Ride OTP Verification', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 15)),
                ]),
                const SizedBox(height: 8),
                Text(isCreator ? 'Verify the passenger\'s OTP to start the ride.' : 'Use your OTP to verify with the driver.',
                    style: TextStyle(fontSize: 12, color: ts, height: 1.4)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => OtpVerificationScreen(tripCode: trip.tripCode, tripId: trip.tripId, isDriver: isCreator))),
                    icon: Icon(Icons.lock_open_outlined, color: appIconColor(Icons.lock_open_outlined)),
                    label: Text(isCreator ? 'Enter Passenger OTP' : 'Get My OTP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ]),
            ),
          ],

          // Complete/Cancel buttons
          if (trip.status == TripStatus.active && isCreator) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Complete Trip?'),
                          content: const Text('Mark this trip as completed?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white),
                                child: const Text('Complete')),
                          ],
                        ));
                    if (ok == true && context.mounted) {
                      await context.read<TripProvider>().completeTrip(trip.tripId);
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, color: Color(0xFF22C55E)),
                  label: const Text('Complete', style: TextStyle(color: Color(0xFF22C55E))),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF22C55E)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Cancel Trip?'),
                          content: const Text('Are you sure you want to cancel?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                                child: const Text('Cancel Trip')),
                          ],
                        ));
                    if (ok == true && context.mounted) {
                      await context.read<TripProvider>().cancelTrip(trip.tripId);
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444)),
                  label: const Text('Cancel', style: TextStyle(color: Color(0xFFEF4444))),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFEF4444)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ]),
          ],

          // Rate + View Profile for completed trips
          if (trip.status == TripStatus.completed) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => RatingReviewScreen(
                      trip: trip,
                      revieweeEmail: isCreator ? trip.creatorEmail : trip.creatorEmail,
                      revieweeName: trip.creatorName,
                    ))),
                icon: Icon(Icons.star_rounded, color: appIconColor(Icons.star_rounded)),
                label: const Text('Rate This Ride'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity, height: 48,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userName: trip.creatorName, userEmail: trip.creatorEmail, isVerified: true))),
                icon: const Icon(Icons.person_outline, color: Color(0xFF1A73E8)),
                label: const Text('View Creator Profile', style: TextStyle(color: Color(0xFF1A73E8))),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1A73E8)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color card;
  const _Card({required this.child, required this.card});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
    child: child,
  );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  final Color tp, ts;
  const _Row({required this.icon, required this.iconColor, required this.label, required this.value, required this.tp, required this.ts});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: iconColor, size: 18)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: ts)),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tp)),
    ])),
  ]);
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color, tp, ts;
  const _Stat({required this.icon, required this.label, required this.value, required this.color, required this.tp, required this.ts});
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: color, size: 22),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 14)),
    Text(label, style: TextStyle(fontSize: 11, color: ts)),
  ]);
}