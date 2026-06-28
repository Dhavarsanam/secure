import 'package:flutter/material.dart';

/// Central icon color system for SecureRide.
/// Every standalone icon gets a meaningful color (never plain black/white).
///   Green  — success / verified / safety
///   Red    — SOS / emergency / cancel / danger
///   Amber  — alerts / weather / notifications / security / rewards
///   Indigo — trips / vehicles / profile / history
///   Purple — admin / analytics / charts
///   Blue   — actions / navigation / info / contact  (default)
Color appIconColor(IconData icon) {
  const green = Color(0xFF16A34A);
  const red = Color(0xFFEF4444);
  const amber = Color(0xFFF59E0B);
  const indigo = Color(0xFF6366F1);
  const purple = Color(0xFF7C3AED);
  const blue = Color(0xFF1A73E8);

  switch (icon) {
    // ---- Green ----
    case Icons.check_circle:
    case Icons.check_circle_outline:
    case Icons.check_circle_rounded:
    case Icons.verified:
    case Icons.verified_rounded:
    case Icons.verified_user:
    case Icons.verified_user_outlined:
    case Icons.verified_user_rounded:
    case Icons.shield_rounded:
    case Icons.security_rounded:
    case Icons.radio_button_checked:
    case Icons.radio_button_checked_rounded:
    case Icons.currency_rupee_rounded:
      return green;

    // ---- Red ----
    case Icons.sos_rounded:
    case Icons.error_outline:
    case Icons.warning_amber_rounded:
    case Icons.cancel_outlined:
    case Icons.car_crash_rounded:
    case Icons.block_rounded:
    case Icons.delete_outline_rounded:
    case Icons.stop_circle_rounded:
    case Icons.logout_rounded:
    case Icons.remove_circle_outline:
    case Icons.remove_rounded:
    case Icons.clear:
    case Icons.flag_outlined:
      return red;

    // ---- Amber ----
    case Icons.notifications_outlined:
    case Icons.notifications_rounded:
    case Icons.star_rounded:
    case Icons.star_outline_rounded:
    case Icons.star_half_rounded:
    case Icons.cloud_rounded:
    case Icons.wb_cloudy_rounded:
    case Icons.wb_sunny_rounded:
    case Icons.wb_sunny_outlined:
    case Icons.thunderstorm_rounded:
    case Icons.foggy:
    case Icons.ac_unit_rounded:
    case Icons.air:
    case Icons.water_drop_rounded:
    case Icons.water_drop_outlined:
    case Icons.lock_outline:
    case Icons.lock_outline_rounded:
    case Icons.lock_rounded:
    case Icons.lock_open_outlined:
    case Icons.lock_open_rounded:
    case Icons.lock_reset:
    case Icons.vpn_key_rounded:
    case Icons.vpn_key_outlined:
    case Icons.emoji_events_rounded:
    case Icons.tips_and_updates_rounded:
    case Icons.hourglass_top_rounded:
    case Icons.traffic_rounded:
    case Icons.construction_rounded:
      return amber;

    // ---- Indigo ----
    case Icons.directions_car:
    case Icons.directions_car_filled_rounded:
    case Icons.directions_car_outlined:
    case Icons.directions_car_rounded:
    case Icons.directions_bus_filled_rounded:
    case Icons.directions_bus_rounded:
    case Icons.airport_shuttle_rounded:
    case Icons.electric_rickshaw_rounded:
    case Icons.two_wheeler_rounded:
    case Icons.person:
    case Icons.person_add:
    case Icons.person_add_rounded:
    case Icons.person_outline:
    case Icons.person_rounded:
    case Icons.person_pin_circle_rounded:
    case Icons.history:
    case Icons.history_rounded:
    case Icons.badge_outlined:
    case Icons.business_center_rounded:
    case Icons.family_restroom_rounded:
      return indigo;

    // ---- Purple ----
    case Icons.dashboard_rounded:
    case Icons.admin_panel_settings_rounded:
    case Icons.bar_chart_rounded:
    case Icons.trending_up_rounded:
    case Icons.table_chart_rounded:
      return purple;

    // ---- Blue (default) ----
    default:
      return blue;
  }
}
