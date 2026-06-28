import 'package:flutter/material.dart';

/// Colored rounded-square icon tile (squircle) with a white glyph inside —
/// matches the SecureRide spec icon set.
///
/// Usage:
///   FeatureIcon.createTrip()                 // preset, default size
///   FeatureIcon.sos(size: 56)                // preset with custom size
///   FeatureIcon(color: Colors.blue, icon: Icons.map_rounded)  // custom
class FeatureIcon extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String? text; // for SOS-style text tiles
  final double size; // outer tile size
  final double radiusFactor; // corner radius as a fraction of size

  const FeatureIcon({
    super.key,
    required this.color,
    this.icon,
    this.text,
    this.size = 56,
    this.radiusFactor = 0.28,
  }) : assert(icon != null || text != null, 'Provide an icon or text');

  // ---- Brand colors (same as the reference sheet) ----
  static const Color _blue = Color(0xFF1A73E8);
  static const Color _red = Color(0xFFEF4444);
  static const Color _green = Color(0xFF16A34A);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _gray = Color(0xFF4B5563);

  // ---- Presets (color + glyph from the spec) ----
  factory FeatureIcon.login({double size = 56}) =>
      FeatureIcon(color: _blue, icon: Icons.directions_car_filled_rounded, size: size);
  factory FeatureIcon.dashboard({double size = 56}) =>
      FeatureIcon(color: _blue, icon: Icons.bar_chart_rounded, size: size);
  factory FeatureIcon.createTrip({double size = 56}) =>
      FeatureIcon(color: _blue, icon: Icons.add_rounded, size: size);
  factory FeatureIcon.joinTrip({double size = 56}) =>
      FeatureIcon(color: _blue, icon: Icons.group_rounded, size: size);
  factory FeatureIcon.myTrips({double size = 56}) =>
      FeatureIcon(color: _blue, icon: Icons.format_list_bulleted_rounded, size: size);
  factory FeatureIcon.liveMap({double size = 56}) =>
      FeatureIcon(color: _blue, icon: Icons.location_on_rounded, size: size);
  factory FeatureIcon.sos({double size = 56}) =>
      FeatureIcon(color: _red, text: 'SOS', size: size);
  factory FeatureIcon.locationShare({double size = 56}) =>
      FeatureIcon(color: _green, icon: Icons.share_location_rounded, size: size);
  factory FeatureIcon.notifications({double size = 56}) =>
      FeatureIcon(color: _amber, icon: Icons.notifications_rounded, size: size);
  factory FeatureIcon.settings({double size = 56}) =>
      FeatureIcon(color: _gray, icon: Icons.settings_rounded, size: size);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * radiusFactor),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.10),
          ),
        ],
      ),
      child: Center(
        child: text != null
            ? Text(
                text!,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.30,
                  letterSpacing: 0.5,
                ),
              )
            : Icon(icon, color: Colors.white, size: size * 0.52),
      ),
    );
  }
}

/// Optional: tile + label stacked vertically (like the reference sheet rows).
class FeatureIconLabeled extends StatelessWidget {
  final FeatureIcon iconTile;
  final String label;
  final Color labelColor;
  final VoidCallback? onTap;

  const FeatureIconLabeled({
    super.key,
    required this.iconTile,
    required this.label,
    this.labelColor = const Color(0xFFF1F5F9),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconTile,
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: labelColor, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
