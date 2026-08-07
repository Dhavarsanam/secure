import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/services/guardian_ai_service.dart';
import '../models/guardian_risk_event.dart';
import '../models/trip_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/app_icon_colors.dart';

/// Guardian AI Mode panel — embedded in the active trip screen.
///
/// Owns its own [GuardianAiService] instance and lifecycle:
///   • Starts monitoring when the user flips the switch on.
///   • Stops + disposes automatically when the trip is no longer active,
///     when the user logs out, or when the widget is removed from the tree.
///   • Renders nothing (SizedBox.shrink) once the trip isn't active,
///     since Guardian AI only makes sense during an active journey.
class GuardianAiPanel extends StatefulWidget {
  final TripModel trip;
  const GuardianAiPanel({super.key, required this.trip});

  @override
  State<GuardianAiPanel> createState() => _GuardianAiPanelState();
}

class _GuardianAiPanelState extends State<GuardianAiPanel> {
  late final GuardianAiService _service;
  bool _starting = false;
  bool _showDemo = false;

  @override
  void initState() {
    super.initState();
    _service = GuardianAiService();
    _service.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant GuardianAiPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trip completed/cancelled while Guardian AI was watching — stop cleanly.
    if (widget.trip.status != TripStatus.active && _service.isMonitoring) {
      _service.stop(reason: 'Destination reached safely');
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _service.stop();
    _service.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool value) async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please log in again to use Guardian AI Mode.'),
      ));
      return;
    }
    if (value) {
      setState(() => _starting = true);
      await _service.start(trip: widget.trip, userId: uid);
      if (mounted) setState(() => _starting = false);
    } else {
      await _service.stop();
    }
  }

  Color _riskColor(GuardianRiskLevel level, bool isDark) {
    switch (level) {
      case GuardianRiskLevel.safe:
        return AppColors.success;
      case GuardianRiskLevel.caution:
        return AppColors.warning;
      case GuardianRiskLevel.highRisk:
        return const Color(0xFFF97316); // distinct from critical red
      case GuardianRiskLevel.critical:
        return AppColors.error;
    }
  }

  IconData _eventIcon(GuardianEventType? type) {
    switch (type) {
      case GuardianEventType.routeDeviation:
        return Icons.alt_route_rounded;
      case GuardianEventType.unexpectedStop:
        return Icons.pause_circle_outline_rounded;
      case GuardianEventType.etaOverdue:
        return Icons.schedule_rounded;
      case GuardianEventType.locationSignalLost:
        return Icons.location_off_rounded;
      case GuardianEventType.noUserResponse:
        return Icons.notifications_off_rounded;
      case GuardianEventType.manualSOS:
        return Icons.sos_rounded;
      case null:
        return Icons.shield_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trip.status != TripStatus.active) return const SizedBox.shrink();

    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final enabled = _service.isMonitoring;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        border: enabled
            ? Border.all(color: _riskColor(_service.riskLevel, isDark).withValues(alpha: 0.35))
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: appIconColor(Icons.shield_rounded).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.shield_rounded, color: appIconColor(Icons.shield_rounded), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Guardian AI Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: tp)),
              Text(
                enabled
                    ? 'Guardian AI is actively protecting your journey'
                    : 'Smart journey monitoring for route deviation, unusual stops and safety risks.',
                style: TextStyle(fontSize: 11.5, color: ts),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          _starting
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
              : Switch(
            value: enabled,
            activeColor: AppColors.success,
            onChanged: _toggle,
          ),
        ]),

        if (enabled) ...[
          const SizedBox(height: 14),
          _statusCard(isDark, tp, ts),
          const SizedBox(height: 14),
          _monitoringIndicators(tp, ts),
          const SizedBox(height: 16),
          Text('Journey Safety Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: tp)),
          const SizedBox(height: 10),
          _timelineSection(tp, ts),
          const SizedBox(height: 16),
          _demoSection(isDark, tp, ts),
        ] else if (_service.hasLocationError) ...[
          const SizedBox(height: 10),
          Text(
            'Location access is required for Guardian AI Mode to work.',
            style: TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ],
      ]),
    );
  }

  Widget _statusCard(bool isDark, Color tp, Color ts) {
    final level = _service.riskLevel;
    final color = _riskColor(level, isDark);
    final lastChecked = _service.lastCheckedAt;
    final timeStr = lastChecked == null
        ? 'Just now'
        : '${lastChecked.hour.toString().padLeft(2, '0')}:${lastChecked.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        SizedBox(
          width: 52, height: 52,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: _service.riskScore / 100,
              strokeWidth: 5,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
            Text('${_service.riskScore}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: tp)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(level.label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('Risk Score: ${_service.riskScore}/100', style: TextStyle(fontSize: 12, color: tp, fontWeight: FontWeight.w600)),
            Text('Last checked: $timeStr', style: TextStyle(fontSize: 11, color: ts)),
          ]),
        ),
      ]),
    );
  }

  Widget _monitoringIndicators(Color tp, Color ts) {
    final chips = [
      _IndicatorData('Route', Icons.alt_route_rounded, _service.routeMonitoringAvailable, _service.routeMonitoringAvailable ? 'Active' : 'No route data'),
      _IndicatorData('Movement', Icons.directions_walk_rounded, true, 'Active'),
      _IndicatorData('ETA', Icons.schedule_rounded, _service.etaMonitoringAvailable, _service.etaMonitoringAvailable ? 'Active' : 'No ETA data'),
      _IndicatorData('Signal', Icons.gps_fixed_rounded, !_service.hasLocationError, _service.hasLocationError ? 'Lost' : 'Active'),
    ];

    return Wrap(
      spacing: 8, runSpacing: 8,
      children: chips.map((c) {
        final color = c.active ? AppColors.success : ts;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(c.icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text('${c.label}: ${c.status}', style: TextStyle(fontSize: 10.5, color: tp, fontWeight: FontWeight.w600)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _timelineSection(Color tp, Color ts) {
    final entries = _service.timeline.reversed.toList(); // newest first
    if (entries.isEmpty) {
      return Text(
        'No safety risks detected. Your journey is being monitored.',
        style: TextStyle(fontSize: 12.5, color: ts, fontStyle: FontStyle.italic),
      );
    }

    return Column(
      children: entries.take(10).map((e) {
        final color = _riskColor(e.level, false);
        final timeStr = '${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(_eventIcon(e.eventType), size: 13, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(timeStr, style: TextStyle(fontSize: 10.5, color: ts, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.title, style: TextStyle(fontSize: 12.5, color: tp, fontWeight: FontWeight.w600))),
                ]),
                if (e.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(e.description, style: TextStyle(fontSize: 11, color: ts)),
                  ),
              ]),
            ),
          ]),
        );
      }).toList(),
    );
  }

  // ─── Demo Mode (viva / presentation only) ───────────────────────
  // Lets the trip's risk state be shown off live without waiting for
  // real GPS conditions. Collapsed by default so it stays out of the
  // way during normal use.
  Widget _demoSection(bool isDark, Color tp, Color ts) {
    final amber = const Color(0xFFF59E0B);

    return Container(
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amber.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _showDemo = !_showDemo),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(Icons.science_rounded, size: 16, color: amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Demo Mode (Testing Only)',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: amber)),
              ),
              Icon(_showDemo ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: amber),
            ]),
          ),
        ),
        if (_showDemo)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'For viva/demo only — manually fires a risk event so you can show the timeline and score reacting, without waiting for real GPS conditions.',
                style: TextStyle(fontSize: 10.5, color: ts),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _demoChip('Route Deviation', Icons.alt_route_rounded, amber,
                        () => _service.simulateEvent(GuardianEventType.routeDeviation, GuardianRiskLevel.highRisk)),
                _demoChip('Unexpected Stop', Icons.pause_circle_outline_rounded, amber,
                        () => _service.simulateEvent(GuardianEventType.unexpectedStop, GuardianRiskLevel.highRisk)),
                _demoChip('ETA Overdue', Icons.schedule_rounded, amber,
                        () => _service.simulateEvent(GuardianEventType.etaOverdue, GuardianRiskLevel.caution)),
                _demoChip('Signal Lost', Icons.location_off_rounded, amber,
                        () => _service.simulateEvent(GuardianEventType.locationSignalLost, GuardianRiskLevel.caution)),
                _demoChip('Reset to Safe', Icons.restart_alt_rounded, AppColors.success, _service.resetToSafe),
              ]),
            ]),
          ),
      ]),
    );
  }

  Widget _demoChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

class _IndicatorData {
  final String label;
  final IconData icon;
  final bool active;
  final String status;
  _IndicatorData(this.label, this.icon, this.active, this.status);
}