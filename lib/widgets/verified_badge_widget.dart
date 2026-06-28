import 'package:flutter/material.dart';

/// Reusable verified badge — use anywhere in the app
class VerifiedBadge extends StatelessWidget {
  final double size;
  final bool showLabel;

  const VerifiedBadge({super.key, this.size = 16, this.showLabel = false});

  @override
  Widget build(BuildContext context) {
    if (showLabel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified_rounded, color: const Color(0xFF1A73E8), size: size),
          const SizedBox(width: 4),
          Text('Verified', style: TextStyle(
            color: const Color(0xFF1A73E8),
            fontSize: size * 0.75,
            fontWeight: FontWeight.w600,
          )),
        ]),
      );
    }
    return Icon(Icons.verified_rounded, color: const Color(0xFF1A73E8), size: size);
  }
}

/// Safety Score Badge
class SafetyScoreBadge extends StatelessWidget {
  final double score; // 0.0 - 5.0
  final bool compact;

  const SafetyScoreBadge({super.key, required this.score, this.compact = false});

  Color get _color {
    if (score >= 4.5) return const Color(0xFF22C55E);
    if (score >= 3.5) return const Color(0xFF1A73E8);
    if (score >= 2.5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get _label {
    if (score >= 4.5) return 'Excellent';
    if (score >= 3.5) return 'Good';
    if (score >= 2.5) return 'Fair';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shield_rounded, color: _color, size: 12),
          const SizedBox(width: 3),
          Text(score.toStringAsFixed(1), style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shield_rounded, color: _color, size: 28),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(score.toStringAsFixed(1),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _color)),
          Text('Safety Score · $_label', style: TextStyle(fontSize: 11, color: _color)),
        ]),
      ]),
    );
  }
}

/// User Avatar with verified badge overlay
class UserAvatarWithBadge extends StatelessWidget {
  final String name;
  final double radius;
  final bool isVerified;
  final Color? backgroundColor;

  const UserAvatarWithBadge({
    super.key,
    required this.name,
    this.radius = 24,
    this.isVerified = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? const Color(0xFF1A73E8).withValues(alpha: 0.1),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style: TextStyle(
              fontSize: radius * 0.7,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A73E8),
            ),
          ),
        ),
        if (isVerified)
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(Icons.verified_rounded, color: const Color(0xFF1A73E8), size: radius * 0.5),
            ),
          ),
      ],
    );
  }
}
