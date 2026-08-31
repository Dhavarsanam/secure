import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/theme_provider.dart';

class SafetyScore {
  final double overall;
  final double tripCompletion;
  final double tripReliability;
  final double locationSharing;
  final double trustedContacts;
  final double emergencyReadiness; // was sosUsage — now based on real SOS setup, not usage
  final int totalTrips;
  final int completedTrips;
  final int cancelledTrips;

  SafetyScore({
    required this.overall,
    required this.tripCompletion,
    required this.tripReliability,
    required this.locationSharing,
    required this.trustedContacts,
    required this.emergencyReadiness,
    required this.totalTrips,
    required this.completedTrips,
    required this.cancelledTrips,
  });

  // True until the user creates/joins their first trip — used to show a
  // friendly "get started" message instead of a misleading score. Setting
  // up contacts or location sharing alone doesn't count as "activity" for
  // this screen: nothing here is presented as a real score until there's
  // at least one trip.
  bool get hasNoActivity => totalTrips == 0;

  String get grade {
    if (overall >= 90) return 'A+';
    if (overall >= 80) return 'A';
    if (overall >= 70) return 'B+';
    if (overall >= 60) return 'B';
    if (overall >= 50) return 'C';
    return 'D';
  }

  String get label {
    if (hasNoActivity) return 'Not Enough Data';
    if (overall >= 90) return 'Excellent';
    if (overall >= 80) return 'Very Good';
    if (overall >= 70) return 'Good';
    if (overall >= 60) return 'Fair';
    return 'Needs Improvement';
  }

  Color get color {
    if (hasNoActivity) return const Color(0xFF94A3B8);
    if (overall >= 90) return const Color(0xFF22C55E);
    if (overall >= 70) return const Color(0xFF1A73E8);
    if (overall >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  // Shared calculation — used by both the Home dashboard card AND this
  // detail screen, so the number shown in both places always matches.
  //
  // Every factor starts at 0 for a brand-new user. Nothing is pre-filled —
  // each factor only rises when the user performs the matching real action:
  //   Trip Completion   (25%) — completed / total trips
  //   Trip Reliability  (20%) — 100 - cancellation rate
  //   Location Sharing  (20%) — 100 only while live location sharing is on
  //   Trusted Contacts  (25%) — scales with approved contacts (5+ = 100)
  //   Emergency Readiness (10%) — 50 for having a trusted contact + 50 for
  //                               location sharing on (the two real
  //                               prerequisites for SOS to actually work)
  static SafetyScore calculate(TripProvider trips, AuthProvider auth) {
    final total = trips.myTrips.length;
    final completed = trips.completedTrips.length;
    final cancelled = trips.cancelledTrips.length;
    final contacts = auth.currentUser?.emergencyContacts.length ?? 0;
    final locationOn = auth.currentUser?.isLocationSharing ?? false;
    return calculateFromCounts(
      total: total,
      completed: completed,
      cancelled: cancelled,
      contactsCount: contacts,
      locationOn: locationOn,
    );
  }

  // Same weighted formula as [calculate], but driven by raw counts instead
  // of the providers — lets other real data sources (e.g. the admin panel,
  // which reads directly from Firestore instead of the signed-in user's
  // providers) share the exact same scoring logic instead of re-deriving
  // their own numbers.
  static SafetyScore calculateFromCounts({
    required int total,
    required int completed,
    required int cancelled,
    required int contactsCount,
    required bool locationOn,
  }) {
    final contacts = contactsCount;

    final tripScore = total == 0 ? 0.0 : (completed / total * 100).clamp(0.0, 100.0);

    final reliabilityScore = total == 0 ? 0.0 : (100.0 - (cancelled / total * 100)).clamp(0.0, 100.0);

    final locationScore = locationOn ? 100.0 : 0.0;

    final contactsScore = (contacts * 20.0).clamp(0.0, 100.0);

    final readinessScore = (contacts > 0 ? 50.0 : 0.0) + (locationOn ? 50.0 : 0.0);

    // Trip Completion (25%) and Trip Reliability (20%) only mean something
    // once the user has actually taken a trip. Scoring them as a flat 0 for
    // someone who simply hasn't traveled yet unfairly drags their overall
    // score down for something outside their control. Once there's at
    // least one trip, use the full weighted formula as before; until then,
    // drop those two factors out and redistribute their 45% weight across
    // Location Sharing, Trusted Contacts, and Emergency Readiness — so the
    // percentage genuinely reflects what the user HAS set up so far.
    final double overall;
    if (total > 0) {
      overall = (tripScore * 0.25 + reliabilityScore * 0.20 + locationScore * 0.20 + contactsScore * 0.25 + readinessScore * 0.10)
          .clamp(0.0, 100.0);
    } else {
      const remainingWeight = 0.20 + 0.25 + 0.10; // 0.55
      overall = (locationScore * (0.20 / remainingWeight) + contactsScore * (0.25 / remainingWeight) + readinessScore * (0.10 / remainingWeight))
          .clamp(0.0, 100.0);
    }

    return SafetyScore(
      overall: overall,
      tripCompletion: tripScore,
      tripReliability: reliabilityScore,
      locationSharing: locationScore,
      trustedContacts: contactsScore,
      emergencyReadiness: readinessScore,
      totalTrips: total,
      completedTrips: completed,
      cancelledTrips: cancelled,
    );
  }
}

class SafetyScoreScreen extends StatefulWidget {
  const SafetyScoreScreen({super.key});

  @override
  State<SafetyScoreScreen> createState() => _SafetyScoreScreenState();
}

class _SafetyScoreScreenState extends State<SafetyScoreScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scoreAnimation;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _scoreAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    Future.delayed(const Duration(milliseconds: 300), () => _animController.forward());
  }

  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  SafetyScore _calculateScore(TripProvider trips, AuthProvider auth) =>
      SafetyScore.calculate(trips, auth);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final trips = context.watch<TripProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final score = _calculateScore(trips, auth);
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        title: const Text('Safety Score', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [

          // Score Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [score.color, score.color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: score.color.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.shield_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                const Text('Your Safety Score', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ]),
              const SizedBox(height: 16),

              // Animated score circle — until the first trip, we show
              // "Not Enough Data" instead of a number so nothing here
              // reads as a real (and misleadingly positive) score.
              AnimatedBuilder(
                animation: _scoreAnimation,
                builder: (_, __) {
                  final displayScore = (score.overall * _scoreAnimation.value).round();
                  return Stack(alignment: Alignment.center, children: [
                    SizedBox(
                      width: 160, height: 160,
                      child: CircularProgressIndicator(
                        value: score.hasNoActivity ? 0 : score.overall / 100 * _scoreAnimation.value,
                        strokeWidth: 12,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    score.hasNoActivity
                        ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Not Enough Data',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    )
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('$displayScore', style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Text('/100', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ]),
                  ]);
                },
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (!score.hasNoActivity) ...[
                    Text(score.grade, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(width: 8),
                    Text('· ${score.label}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ] else
                    Text(score.label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ]),
              ),

              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _ScoreStat(label: 'Trips', value: '${score.totalTrips}', icon: Icons.directions_car),
                _ScoreStat(label: 'Completed', value: '${score.completedTrips}', icon: Icons.check_circle_outline),
                _ScoreStat(label: 'Cancelled', value: '${score.cancelledTrips}', icon: Icons.cancel_outlined),
              ]),
            ]),
          ),

          const SizedBox(height: 24),

          // Friendly empty-state — shown until the user has done anything
          if (score.hasNoActivity)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                const Text('🚗', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text('Start your first trip to build your Safety Score.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Your score grows as you complete trips, share your location, and add trusted contacts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ts, fontSize: 12, height: 1.4)),
              ]),
            ),

          // Score Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Score Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showDetails = !_showDetails),
                  child: Text(_showDetails ? 'Hide' : 'Details',
                      style: const TextStyle(color: Color(0xFF1A73E8), fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 16),
              _ScoreBar(label: 'Trip Completion', score: score.tripCompletion, icon: Icons.directions_car_rounded, color: const Color(0xFF1A73E8), tp: tp, ts: ts, detail: _showDetails ? '${score.completedTrips}/${score.totalTrips} trips completed' : null),
              _ScoreBar(label: 'Trip Reliability', score: score.tripReliability, icon: Icons.cancel_outlined, color: const Color(0xFF22C55E), tp: tp, ts: ts, notEnoughData: score.hasNoActivity, detail: _showDetails ? (score.hasNoActivity ? 'Not enough data yet' : '${score.cancelledTrips}/${score.totalTrips} trips cancelled') : null),
              _ScoreBar(label: 'Location Sharing', score: score.locationSharing, icon: Icons.location_on_rounded, color: const Color(0xFF8B5CF6), tp: tp, ts: ts, notEnoughData: score.hasNoActivity, detail: _showDetails ? (score.hasNoActivity ? 'Not enough data yet' : (auth.currentUser?.isLocationSharing == true ? 'Location sharing is on' : 'Location sharing is off')) : null),
              _ScoreBar(label: 'Trusted Contacts', score: score.trustedContacts, icon: Icons.group_rounded, color: const Color(0xFFF59E0B), tp: tp, ts: ts, notEnoughData: score.hasNoActivity, detail: _showDetails ? (score.hasNoActivity ? 'Not enough data yet' : '${auth.currentUser?.emergencyContacts.length ?? 0} trusted contacts added') : null),
              _ScoreBar(label: 'Emergency Readiness', score: score.emergencyReadiness, icon: Icons.sos_rounded, color: const Color(0xFFEF4444), tp: tp, ts: ts, notEnoughData: score.hasNoActivity, detail: _showDetails ? (score.hasNoActivity ? 'Not enough data yet' : score.emergencyReadiness == 0 ? 'Add a contact and enable location sharing to set up SOS' : score.emergencyReadiness < 100 ? 'Partially set up — complete both steps below' : 'SOS fully configured') : null, isLast: true),
            ]),
          ),

          const SizedBox(height: 20),

          // Tips to improve
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.tips_and_updates_rounded, color: Color(0xFF1A73E8), size: 20),
                const SizedBox(width: 8),
                Text('Tips to Improve Score', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 14)),
              ]),
              const SizedBox(height: 12),
              ..._getTips(score, auth).map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('💡 ', style: TextStyle(fontSize: 13)),
                  Expanded(child: Text(tip, style: TextStyle(fontSize: 12, color: ts, height: 1.4))),
                ]),
              )),
            ]),
          ),

          const SizedBox(height: 20),

          // Score Snapshot — a real month-by-month history isn't tracked
          // in this project, so we show today's true breakdown instead of
          // fabricated past months.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: ts, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                  score.hasNoActivity
                      ? 'Score history will start building once you begin using the app.'
                      : 'This score reflects your current activity as of today. Keep completing trips and maintaining your trusted network to improve it.',
                  style: TextStyle(fontSize: 12, color: ts, height: 1.4))),
            ]),
          ),

          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  List<String> _getTips(SafetyScore score, AuthProvider auth) {
    final tips = <String>[];
    if (score.totalTrips == 0) tips.add('Create or join your first trip to start building your Trip Completion and Reliability scores.');
    if (score.totalTrips > 0 && score.tripReliability < 80) tips.add('Avoid cancelling trips after creating or joining them to improve reliability.');
    if (auth.currentUser?.isLocationSharing != true) tips.add('Turn on location sharing so you get credit for it during trips.');
    if (score.trustedContacts < 100) tips.add('Add more trusted contacts (up to 5) so they can be notified in an emergency.');
    if (score.emergencyReadiness < 100) tips.add('Add a trusted contact and enable location sharing to fully set up SOS.');
    if (tips.isEmpty) tips.add('Great job! Keep completing trips and maintaining your trusted network to stay on top!');
    return tips;
  }
}

class _ScoreStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _ScoreStat({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: Colors.white70, size: 18),
    const SizedBox(height: 2),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
  ]);
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double score;
  final IconData icon;
  final Color color;
  final Color tp, ts;
  final String? detail;
  final bool isLast;
  // When true, this factor hasn't been earned by real activity yet
  // (no trips taken), so we show "Not Enough Data" instead of a 0
  // that could read as a bad score.
  final bool notEnoughData;

  const _ScoreBar({required this.label, required this.score, required this.icon, required this.color, required this.tp, required this.ts, this.detail, this.isLast = false, this.notEnoughData = false});

  @override
  Widget build(BuildContext context) {
    final barColor = notEnoughData ? ts.withValues(alpha: 0.5) : color;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: barColor, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: tp, fontSize: 13, fontWeight: FontWeight.w500))),
          notEnoughData
              ? Text('Not Enough Data', style: TextStyle(color: ts, fontWeight: FontWeight.w600, fontSize: 12))
              : Text('${score.round()}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: notEnoughData ? 0 : score / 100,
            backgroundColor: barColor.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(barColor),
            minHeight: 8,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 3),
          Text(detail!, style: TextStyle(fontSize: 11, color: ts)),
        ],
      ]),
    );
  }
}