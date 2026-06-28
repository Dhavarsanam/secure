import 'package:flutter/material.dart';

/// Custom Icon Widgets — Realistic & Beautiful
class AppIcons {
  // Vehicle Icons with realistic styling
  static Widget vehicle(String type, {double size = 32, Color? color}) {
    final c = color ?? const Color(0xFF1A73E8);
    switch (type.toLowerCase()) {
      case 'car':
        return _VehicleIcon(icon: Icons.directions_car_filled_rounded, color: c, size: size);
      case 'bike':
        return _VehicleIcon(icon: Icons.two_wheeler_rounded, color: c, size: size);
      case 'auto':
        return _VehicleIcon(icon: Icons.electric_rickshaw_rounded, color: c, size: size);
      case 'van':
        return _VehicleIcon(icon: Icons.airport_shuttle_rounded, color: c, size: size);
      case 'bus':
        return _VehicleIcon(icon: Icons.directions_bus_filled_rounded, color: c, size: size);
      case 'suv':
        return _VehicleIcon(icon: Icons.directions_car_filled_rounded, color: c, size: size);
      default:
        return _VehicleIcon(icon: Icons.directions_car_filled_rounded, color: c, size: size);
    }
  }

  // Passenger type icons
  static Widget passenger(String type, {double size = 28, Color? color}) {
    final c = color ?? const Color(0xFF22C55E);
    switch (type.toLowerCase()) {
      case 'solo':
        return Icon(Icons.person_rounded, color: c, size: size);
      case 'family':
        return Icon(Icons.family_restroom_rounded, color: c, size: size);
      case 'group':
        return Icon(Icons.groups_rounded, color: c, size: size);
      case 'women only':
        return Icon(Icons.female_rounded, color: c, size: size);
      case 'corporate':
        return Icon(Icons.business_center_rounded, color: c, size: size);
      default:
        return Icon(Icons.person_rounded, color: c, size: size);
    }
  }

  // Animated SOS Icon
  static Widget sos({double size = 64, bool isActive = false}) {
    return _SosIcon(size: size, isActive: isActive);
  }

  // Shield with score
  static Widget safetyShield({required double score, double size = 56}) {
    return _SafetyShieldIcon(score: score, size: size);
  }

  // Location pin with pulse
  static Widget locationPin({Color color = const Color(0xFF1A73E8), double size = 32, bool pulse = false}) {
    return _LocationPinIcon(color: color, size: size, pulse: pulse);
  }

  // Star rating display
  static Widget starRating(double rating, {double size = 16, bool showNumber = true}) {
    return _StarRatingWidget(rating: rating, size: size, showNumber: showNumber);
  }

  // Verified badge
  static Widget verified({double size = 20, bool showLabel = false}) {
    if (showLabel) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified_rounded, color: const Color(0xFF1A73E8), size: size),
        const SizedBox(width: 4),
        Text('Verified', style: TextStyle(color: const Color(0xFF1A73E8), fontSize: size * 0.7, fontWeight: FontWeight.w600)),
      ]);
    }
    return Icon(Icons.verified_rounded, color: const Color(0xFF1A73E8), size: size);
  }

  // OTP lock icon
  static Widget otpLock({double size = 48, bool isVerified = false}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: isVerified ? const Color(0xFF22C55E).withValues(alpha: 0.1) : const Color(0xFF1A73E8).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Icon(
        isVerified ? Icons.lock_open_rounded : Icons.lock_rounded,
        color: isVerified ? const Color(0xFF22C55E) : const Color(0xFF1A73E8),
        size: size * 0.5,
      ),
    );
  }
}

class _VehicleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _VehicleIcon({required this.icon, required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(size * 0.25),
    ),
    child: Icon(icon, color: color, size: size * 0.6),
  );
}

class _SosIcon extends StatefulWidget {
  final double size;
  final bool isActive;
  const _SosIcon({required this.size, required this.isActive});
  @override
  State<_SosIcon> createState() => _SosIconState();
}

class _SosIconState extends State<_SosIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Container(
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3), width: 2),
        ),
        child: Icon(Icons.sos_rounded, color: const Color(0xFFEF4444), size: widget.size * 0.5),
      );
    }
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 4)],
        ),
        child: Icon(Icons.sos_rounded, color: Colors.white, size: widget.size * 0.5),
      ),
    );
  }
}

class _SafetyShieldIcon extends StatelessWidget {
  final double score;
  final double size;
  const _SafetyShieldIcon({required this.score, required this.size});

  Color get _color {
    if (score >= 80) return const Color(0xFF22C55E);
    if (score >= 60) return const Color(0xFF1A73E8);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Icon(Icons.shield_rounded, color: _color, size: size),
      Text('${score.round()}', style: TextStyle(
        fontSize: size * 0.22, fontWeight: FontWeight.bold,
        color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
      )),
    ]);
  }
}

class _LocationPinIcon extends StatefulWidget {
  final Color color;
  final double size;
  final bool pulse;
  const _LocationPinIcon({required this.color, required this.size, required this.pulse});
  @override
  State<_LocationPinIcon> createState() => _LocationPinIconState();
}

class _LocationPinIconState extends State<_LocationPinIcon> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = Tween<double>(begin: 0.0, end: 1.0).animate(_ctrl);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) return Icon(Icons.location_on_rounded, color: widget.color, size: widget.size);
    return SizedBox(
      width: widget.size * 1.5, height: widget.size * 1.5,
      child: Stack(alignment: Alignment.center, children: [
        AnimatedBuilder(animation: _anim, builder: (_, __) => Opacity(
          opacity: 1 - _anim.value,
          child: Container(
            width: widget.size * (1 + _anim.value),
            height: widget.size * (1 + _anim.value),
            decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.3), shape: BoxShape.circle),
          ),
        )),
        Icon(Icons.location_on_rounded, color: widget.color, size: widget.size),
      ]),
    );
  }
}

class _StarRatingWidget extends StatelessWidget {
  final double rating;
  final double size;
  final bool showNumber;
  const _StarRatingWidget({required this.rating, required this.size, required this.showNumber});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ...List.generate(5, (i) {
        if (i < rating.floor()) return Icon(Icons.star_rounded, color: const Color(0xFFF59E0B), size: size);
        if (i < rating) return Icon(Icons.star_half_rounded, color: const Color(0xFFF59E0B), size: size);
        return Icon(Icons.star_outline_rounded, color: const Color(0xFFF59E0B), size: size);
      }),
      if (showNumber) ...[
        const SizedBox(width: 4),
        Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: size * 0.8, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
      ],
    ]);
  }
}
