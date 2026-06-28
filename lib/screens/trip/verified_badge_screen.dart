import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_icon_colors.dart';

enum VerificationStatus { notStarted, pending, verified, rejected }

class VerificationStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  bool isCompleted;

  VerificationStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.isCompleted = false,
  });
}

class VerifiedBadgeScreen extends StatefulWidget {
  const VerifiedBadgeScreen({super.key});

  @override
  State<VerifiedBadgeScreen> createState() => _VerifiedBadgeScreenState();
}

class _VerifiedBadgeScreenState extends State<VerifiedBadgeScreen>
    with SingleTickerProviderStateMixin {
  VerificationStatus _status = VerificationStatus.notStarted;
  bool _isLoading = false;
  int _currentStep = 0;

  late AnimationController _badgeController;
  late Animation<double> _badgeAnimation;

  final List<VerificationStep> _steps = [
    VerificationStep(
      title: 'Phone Verification',
      description: 'Verify your mobile number via OTP',
      icon: Icons.phone_android,
      color: const Color(0xFF1A73E8),
    ),
    VerificationStep(
      title: 'Email Verification',
      description: 'Confirm your email address',
      icon: Icons.email_outlined,
      color: const Color(0xFF22C55E),
    ),
    VerificationStep(
      title: 'Government ID',
      description: 'Upload Aadhaar / Driving License',
      icon: Icons.badge_outlined,
      color: const Color(0xFFF59E0B),
    ),
    VerificationStep(
      title: 'Profile Photo',
      description: 'Upload a clear selfie photo',
      icon: Icons.camera_alt_outlined,
      color: const Color(0xFF8B5CF6),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _badgeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _badgeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _badgeController.dispose();
    super.dispose();
  }

  Future<void> _completeStep(int index) async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    // TODO: Real verification via Firebase
    setState(() {
      _steps[index].isCompleted = true;
      _isLoading = false;
      if (index < _steps.length - 1) _currentStep = index + 1;
    });

    // Check if all done
    if (_steps.every((s) => s.isCompleted)) {
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _status = VerificationStatus.pending);
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _status = VerificationStatus.verified);
      _badgeController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        title: const Text('Get Verified', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [

          // Badge Display
          if (_status == VerificationStatus.verified)
            _VerifiedBadgeWidget(animation: _badgeAnimation, userName: user?.fullName ?? 'User')
          else
            _UnverifiedCard(status: _status, card: card, tp: tp, ts: ts),

          const SizedBox(height: 28),

          // Benefits
          if (_status != VerificationStatus.verified) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF1A73E8), size: 20),
                  const SizedBox(width: 8),
                  Text('Benefits of Verification', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 14)),
                ]),
                const SizedBox(height: 12),
                ...[
                  '✅ Blue verified badge on your profile',
                  '🔒 Trusted by other users in the community',
                  '⭐ Higher visibility in trip listings',
                  '🚀 Priority support from SecureRide',
                  '🎯 Access to premium trip features',
                ].map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(b, style: TextStyle(fontSize: 13, color: tp, height: 1.4)),
                )),
              ]),
            ),
            const SizedBox(height: 24),
          ],

          // Verification Steps
          if (_status != VerificationStatus.verified) ...[
            Row(children: [
              Text('Verification Steps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
              const Spacer(),
              Text('${_steps.where((s) => s.isCompleted).length}/${_steps.length}',
                  style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),

            // Progress bar
            LinearProgressIndicator(
              value: _steps.where((s) => s.isCompleted).length / _steps.length,
              backgroundColor: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1A73E8)),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 16),

            // Steps list
            ...List.generate(_steps.length, (index) {
              final step = _steps[index];
              final isActive = index == _currentStep && !step.isCompleted;
              final isLocked = index > _currentStep && !step.isCompleted;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: isActive ? Border.all(color: step.color, width: 2) : null,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: step.isCompleted
                          ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                          : isLocked
                          ? (isDark ? Colors.white10 : const Color(0xFFF5F7FA))
                          : step.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      step.isCompleted ? Icons.check_circle_rounded : (isLocked ? Icons.lock_outline : step.icon), color: appIconColor(step.isCompleted ? Icons.check_circle_rounded : (isLocked ? Icons.lock_outline : step.icon)),
                      size: 22),
                  ),
                  title: Text(step.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600, color: isLocked ? ts : tp, fontSize: 14,
                      )),
                  subtitle: Text(step.description,
                      style: TextStyle(fontSize: 12, color: ts)),
                  trailing: step.isCompleted
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 22)
                      : isLocked
                      ? Icon(Icons.chevron_right, color: ts)
                      : _isLoading && isActive
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8)))
                      : ElevatedButton(
                    onPressed: () => _completeStep(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: step.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(60, 32),
                    ),
                    child: const Text('Verify'),
                  ),
                ),
              );
            }),
          ],

          // Final verified state
          if (_status == VerificationStatus.verified) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF22C55E), size: 20),
                  const SizedBox(width: 8),
                  Text('All Steps Completed!', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 14)),
                ]),
                const SizedBox(height: 8),
                Text('Your profile is now verified. The blue badge will appear on your profile and trip listings.',
                    style: TextStyle(fontSize: 12, color: ts, height: 1.5), textAlign: TextAlign.center),
              ]),
            ),
          ],

          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _VerifiedBadgeWidget extends StatelessWidget {
  final Animation<double> animation;
  final String userName;
  const _VerifiedBadgeWidget({required this.animation, required this.userName});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: animation,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: const Color(0xFF1A73E8).withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(children: [
          Stack(alignment: Alignment.bottomRight, children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(userName[0].toUpperCase(),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.verified_rounded, color: Color(0xFF1A73E8), size: 24),
            ),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 6),
            const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
          ]),
          const SizedBox(height: 4),
          const Text('✅ Verified User', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _BadgeStat(label: 'Phone', icon: Icons.check_circle, color: Colors.greenAccent),
            _BadgeStat(label: 'Email', icon: Icons.check_circle, color: Colors.greenAccent),
            _BadgeStat(label: 'ID', icon: Icons.check_circle, color: Colors.greenAccent),
            _BadgeStat(label: 'Photo', icon: Icons.check_circle, color: Colors.greenAccent),
          ]),
        ]),
      ),
    );
  }
}

class _BadgeStat extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _BadgeStat({required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: color, size: 20),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
  ]);
}

class _UnverifiedCard extends StatelessWidget {
  final VerificationStatus status;
  final Color card, tp, ts;
  const _UnverifiedCard({required this.status, required this.card, required this.tp, required this.ts});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)],
      ),
      child: Column(children: [
        Icon(
          status == VerificationStatus.pending ? Icons.hourglass_top_rounded : Icons.verified_user_outlined,
          size: 56, color: appIconColor(status == VerificationStatus.pending ? Icons.hourglass_top_rounded : Icons.verified_user_outlined)),
        const SizedBox(height: 12),
        Text(
          status == VerificationStatus.pending ? 'Verification Pending...' : 'Not Verified Yet',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tp),
        ),
        const SizedBox(height: 6),
        Text(
          status == VerificationStatus.pending
              ? 'Your documents are being reviewed. This usually takes 24 hours.'
              : 'Complete all steps below to get your verified badge!',
          style: TextStyle(fontSize: 13, color: ts, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}
