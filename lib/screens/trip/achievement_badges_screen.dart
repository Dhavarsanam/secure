import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_icon_colors.dart';

class AchievementBadge {
  final String id, emoji, title, description, requirement;
  final bool isUnlocked;
  final Color color;
  const AchievementBadge({required this.id, required this.emoji, required this.title,
    required this.description, required this.requirement, required this.isUnlocked, required this.color});
}

class AchievementBadgesScreen extends StatefulWidget {
  const AchievementBadgesScreen({super.key});
  @override
  State<AchievementBadgesScreen> createState() => _AchievementBadgesScreenState();
}

class _AchievementBadgesScreenState extends State<AchievementBadgesScreen> {

  List<AchievementBadge> _getBadges(TripProvider trips, AuthProvider auth) {
    final completed = trips.completedTrips.length;
    final total = trips.myTrips.length;
    final contacts = auth.currentUser?.approvedContacts.length ?? 0;
    return [
      AchievementBadge(id: 'first_ride', emoji: '🚗', title: 'First Ride', description: 'Completed your first trip',
          requirement: 'Complete 1 trip', isUnlocked: completed >= 1, color: const Color(0xFF1A73E8)),
      AchievementBadge(id: 'safe_traveler', emoji: '🥇', title: 'Safe Traveler', description: 'Completed 5 rides',
          requirement: 'Complete 5 trips', isUnlocked: completed >= 5, color: const Color(0xFFF59E0B)),
      AchievementBadge(id: 'road_warrior', emoji: '🏆', title: 'Road Warrior', description: 'Completed 10 trips',
          requirement: 'Complete 10 trips', isUnlocked: completed >= 10, color: const Color(0xFFEF4444)),
      AchievementBadge(id: 'trip_creator', emoji: '🌟', title: 'Trip Creator', description: 'Created your first trip',
          requirement: 'Create 1 trip', isUnlocked: total >= 1, color: const Color(0xFF8B5CF6)),
      AchievementBadge(id: 'community', emoji: '🤝', title: 'Community Hero', description: 'Added 3 trusted contacts',
          requirement: 'Add 3 contacts', isUnlocked: contacts >= 3, color: const Color(0xFF22C55E)),
      AchievementBadge(id: 'safety', emoji: '🛡️', title: 'Safety First', description: 'Used SOS & stayed safe',
          requirement: 'Use SOS once', isUnlocked: false, color: const Color(0xFFDC2626)),
      AchievementBadge(id: 'verified', emoji: '✅', title: 'Verified Rider', description: 'Completed verification',
          requirement: 'Get verified', isUnlocked: false, color: const Color(0xFF1A73E8)),
      AchievementBadge(id: 'night_owl', emoji: '🦉', title: 'Night Owl', description: 'Completed a night trip',
          requirement: 'Complete night trip', isUnlocked: completed >= 2, color: const Color(0xFF374151)),
      AchievementBadge(id: 'eco', emoji: '🌿', title: 'Eco Rider', description: 'Shared rides & saved fuel',
          requirement: 'Join 3 shared trips', isUnlocked: total >= 3, color: const Color(0xFF22C55E)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final trips = context.watch<TripProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final badges = _getBadges(trips, auth);
    final unlocked = badges.where((b) => b.isUnlocked).length;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
          title: const Text('Achievement Badges', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [

          // Progress Header with Trophy lottie
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1A73E8), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFF1A73E8).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]),
            child: Row(children: [
              // Trophy lottie
              Lottie.asset('assets/animations/trophy.json',
                  width: 80, height: 80, repeat: unlocked > 0,
                  errorBuilder: (_, __, ___) => const Text('🏆', style: TextStyle(fontSize: 56))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$unlocked / ${badges.length} Unlocked',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: unlocked / badges.length,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white), minHeight: 8)),
                const SizedBox(height: 4),
                Text('Keep completing trips!', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          // Unlocked
          Align(alignment: Alignment.centerLeft,
              child: Text('Unlocked 🔓', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp))),
          const SizedBox(height: 12),
          ...badges.where((b) => b.isUnlocked).map((b) => _BadgeCard(badge: b, card: card, tp: tp, ts: ts)),

          const SizedBox(height: 20),

          // Locked
          Align(alignment: Alignment.centerLeft,
              child: Text('Locked 🔒', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ts))),
          const SizedBox(height: 12),
          ...badges.where((b) => !b.isUnlocked).map((b) => _BadgeCard(badge: b, card: card, tp: tp, ts: ts, locked: true)),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final AchievementBadge badge;
  final Color card, tp, ts;
  final bool locked;
  const _BadgeCard({required this.badge, required this.card, required this.tp, required this.ts, this.locked = false});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: locked ? card.withValues(alpha: 0.5) : card,
        borderRadius: BorderRadius.circular(14),
        border: locked ? null : Border.all(color: badge.color.withValues(alpha: 0.2)),
        boxShadow: locked ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
    child: Row(children: [
      Container(width: 56, height: 56,
          decoration: BoxDecoration(
              color: locked ? const Color(0xFF6B7280).withValues(alpha: 0.1) : badge.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(locked ? '🔒' : badge.emoji, style: TextStyle(fontSize: locked ? 24 : 28)))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(badge.title, style: TextStyle(fontWeight: FontWeight.bold, color: locked ? ts : tp, fontSize: 14)),
          if (!locked) ...[const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: badge.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('Earned!', style: TextStyle(color: badge.color, fontSize: 10, fontWeight: FontWeight.bold)))],
        ]),
        const SizedBox(height: 3),
        Text(badge.description, style: TextStyle(fontSize: 12, color: ts, height: 1.3)),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.flag_outlined, size: 11, color: appIconColor(Icons.flag_outlined)), const SizedBox(width: 3),
          Text(badge.requirement, style: TextStyle(fontSize: 11, color: ts, fontStyle: FontStyle.italic)),
        ]),
      ])),
      if (!locked) Icon(Icons.check_circle_rounded, color: badge.color, size: 22),
    ]),
  );
}