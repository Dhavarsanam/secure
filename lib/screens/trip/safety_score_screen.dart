import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/theme_provider.dart';

class SafetyScore {
  final double overall;
  final double tripCompletion;
  final double otpVerification;
  final double locationSharing;
  final double communityRating;
  final double sosUsage;
  final int totalTrips;
  final int completedTrips;
  final int verifiedOtps;

  SafetyScore({
    required this.overall,
    required this.tripCompletion,
    required this.otpVerification,
    required this.locationSharing,
    required this.communityRating,
    required this.sosUsage,
    required this.totalTrips,
    required this.completedTrips,
    required this.verifiedOtps,
  });

  String get grade {
    if (overall >= 90) return 'A+';
    if (overall >= 80) return 'A';
    if (overall >= 70) return 'B+';
    if (overall >= 60) return 'B';
    if (overall >= 50) return 'C';
    return 'D';
  }

  String get label {
    if (overall >= 90) return 'Excellent';
    if (overall >= 80) return 'Very Good';
    if (overall >= 70) return 'Good';
    if (overall >= 60) return 'Fair';
    return 'Needs Improvement';
  }

  Color get color {
    if (overall >= 90) return const Color(0xFF22C55E);
    if (overall >= 70) return const Color(0xFF1A73E8);
    if (overall >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
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

  SafetyScore _calculateScore(TripProvider trips, AuthProvider auth) {
    final total = trips.myTrips.length;
    final completed = trips.completedTrips.length;
    final contacts = auth.currentUser?.approvedContacts.length ?? 0;

    final tripScore = total == 0 ? 60.0 : (completed / total * 100).clamp(0.0, 100.0);
    final otpScore = total > 0 ? 85.0 : 60.0; // dummy
    final locationScore = contacts > 0 ? 90.0 : 50.0;
    final ratingScore = 88.0; // dummy avg rating * 20
    final sosScore = 95.0; // no false alarms

    final overall = (tripScore * 0.25 + otpScore * 0.20 + locationScore * 0.20 + ratingScore * 0.25 + sosScore * 0.10).clamp(0.0, 100.0);

    return SafetyScore(
      overall: overall,
      tripCompletion: tripScore,
      otpVerification: otpScore,
      locationSharing: locationScore,
      communityRating: ratingScore,
      sosUsage: sosScore,
      totalTrips: total,
      completedTrips: completed,
      verifiedOtps: total > 0 ? (total * 0.85).round() : 0,
    );
  }

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

              // Animated score circle
              AnimatedBuilder(
                animation: _scoreAnimation,
                builder: (_, __) {
                  final displayScore = (score.overall * _scoreAnimation.value).round();
                  return Stack(alignment: Alignment.center, children: [
                    SizedBox(
                      width: 160, height: 160,
                      child: CircularProgressIndicator(
                        value: score.overall / 100 * _scoreAnimation.value,
                        strokeWidth: 12,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(mainAxisSize: MainAxisSize.min, children: [
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
                  Text(score.grade, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 8),
                  Text('· ${score.label}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                ]),
              ),

              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _ScoreStat(label: 'Trips', value: '${score.totalTrips}', icon: Icons.directions_car),
                _ScoreStat(label: 'Completed', value: '${score.completedTrips}', icon: Icons.check_circle_outline),
                _ScoreStat(label: 'OTP Verified', value: '${score.verifiedOtps}', icon: Icons.verified_user_outlined),
              ]),
            ]),
          ),

          const SizedBox(height: 24),

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
              _ScoreBar(label: 'OTP Verification', score: score.otpVerification, icon: Icons.verified_user_rounded, color: const Color(0xFF22C55E), tp: tp, ts: ts, detail: _showDetails ? '${score.verifiedOtps} OTPs verified' : null),
              _ScoreBar(label: 'Location Sharing', score: score.locationSharing, icon: Icons.location_on_rounded, color: const Color(0xFF8B5CF6), tp: tp, ts: ts, detail: _showDetails ? '${auth.currentUser?.approvedContacts.length ?? 0} trusted contacts' : null),
              _ScoreBar(label: 'Community Rating', score: score.communityRating, icon: Icons.star_rounded, color: const Color(0xFFF59E0B), tp: tp, ts: ts, detail: _showDetails ? '4.4/5.0 average rating' : null),
              _ScoreBar(label: 'SOS Discipline', score: score.sosUsage, icon: Icons.sos_rounded, color: const Color(0xFFEF4444), tp: tp, ts: ts, detail: _showDetails ? 'No false SOS alerts' : null, isLast: true),
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

          // Score History (dummy)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Score History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _HistoryBar(month: 'Feb', score: 65, maxScore: 100, color: const Color(0xFFF59E0B), tp: tp, ts: ts),
                _HistoryBar(month: 'Mar', score: 72, maxScore: 100, color: const Color(0xFF1A73E8), tp: tp, ts: ts),
                _HistoryBar(month: 'Apr', score: 78, maxScore: 100, color: const Color(0xFF1A73E8), tp: tp, ts: ts),
                _HistoryBar(month: 'May', score: 82, maxScore: 100, color: const Color(0xFF22C55E), tp: tp, ts: ts),
                _HistoryBar(month: 'Jun', score: score.overall.round(), maxScore: 100, color: score.color, tp: tp, ts: ts, isCurrent: true),
              ]),
            ]),
          ),

          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  List<String> _getTips(SafetyScore score, AuthProvider auth) {
    final tips = <String>[];
    if (score.tripCompletion < 80) tips.add('Complete more trips without cancelling to boost your trip score.');
    if (auth.currentUser?.approvedContacts.isEmpty == true) tips.add('Add trusted contacts and share your location during trips.');
    if (score.otpVerification < 80) tips.add('Always verify OTP before starting rides for better security.');
    if (score.communityRating < 85) tips.add('Be punctual and friendly to get better ratings from passengers.');
    if (tips.isEmpty) tips.add('Great job! Keep completing trips and maintaining good ratings to stay on top!');
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

  const _ScoreBar({required this.label, required this.score, required this.icon, required this.color, required this.tp, required this.ts, this.detail, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: tp, fontSize: 13, fontWeight: FontWeight.w500))),
          Text('${score.round()}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
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

class _HistoryBar extends StatelessWidget {
  final String month;
  final int score, maxScore;
  final Color color, tp, ts;
  final bool isCurrent;

  const _HistoryBar({required this.month, required this.score, required this.maxScore, required this.color, required this.tp, required this.ts, this.isCurrent = false});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('$score', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCurrent ? color : tp)),
      const SizedBox(height: 4),
      Container(
        width: 32,
        height: 80,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: score / maxScore,
          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
        ),
      ),
      const SizedBox(height: 4),
      Text(month, style: TextStyle(fontSize: 10, color: isCurrent ? color : ts, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
      if (isCurrent) Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    ]);
  }
}