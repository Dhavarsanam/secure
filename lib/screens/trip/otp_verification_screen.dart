import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../home/home_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String tripCode;
  final String tripId;
  final bool isDriver;

  const OtpVerificationScreen({
    super.key, required this.tripCode, required this.tripId, this.isDriver = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  bool _isVerified = false;
  int _resendTimer = 30;
  Timer? _timer;
  String? _errorMsg;

  // Demo OTP
  final String _dummyOtp = '123456';

  @override
  void initState() { super.initState(); _startTimer(); }

  void _startTimer() {
    _resendTimer = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendTimer == 0) t.cancel();
      else setState(() => _resendTimer--);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get _entered => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_entered.length != 6) { setState(() => _errorMsg = 'Enter all 6 digits'); return; }
    setState(() { _isVerifying = true; _errorMsg = null; });
    await Future.delayed(const Duration(seconds: 1));

    if (_entered == _dummyOtp) {
      setState(() { _isVerifying = false; _isVerified = true; });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [Icon(Icons.verified, color: Colors.white), SizedBox(width: 8), Text('OTP Verified! Ride started.')]),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16)));
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
      }
    } else {
      setState(() { _isVerifying = false; _errorMsg = 'Invalid OTP. Try again!'; });
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final border = isDark ? const Color(0xFF2D2D44) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
          title: const Text('OTP Verification', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 16),

          // Success or Lock animation
          if (_isVerified)
            Lottie.asset('assets/animations/success_check.json',
                width: 160, height: 160, repeat: false,
                errorBuilder: (_, __, ___) => const Icon(Icons.verified_rounded, color: Color(0xFF22C55E), size: 80))
          else
            Lottie.asset('assets/animations/loading.json',
                width: 100, height: 100, repeat: _isVerifying,
                animate: _isVerifying,
                errorBuilder: (_, __, ___) => Container(width: 80, height: 80,
                    decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF1A73E8), size: 40))),

          const SizedBox(height: 20),
          Text(_isVerified ? 'Verified! 🎉' : 'Enter OTP',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 6),
          Text(_isVerified
              ? 'Your ride has been verified!'
              : widget.isDriver
              ? 'Ask the passenger for OTP'
              : 'Enter the 6-digit code',
              style: TextStyle(fontSize: 13, color: ts), textAlign: TextAlign.center),
          const SizedBox(height: 10),

          // Trip badge
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.directions_car, color: Color(0xFF1A73E8), size: 16),
                const SizedBox(width: 6),
                Text('Trip: ${widget.tripCode}', style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold, fontSize: 13)),
              ])),
          const SizedBox(height: 32),

          if (!_isVerified) ...[
            // OTP fields
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) => SizedBox(width: 46, height: 56,
                    child: TextFormField(
                      controller: _controllers[i], focusNode: _focusNodes[i],
                      keyboardType: TextInputType.number, textAlign: TextAlign.center,
                      maxLength: 1,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: tp),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(counterText: '',
                          filled: true, fillColor: card,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2)),
                          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2))),
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
                        if (v.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
                        if (_entered.length == 6) _verify();
                        setState(() => _errorMsg = null);
                      },
                    )))),

            if (_errorMsg != null) ...[
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 6),
                Text(_errorMsg!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
              ]),
            ],
            const SizedBox(height: 28),

            SizedBox(width: double.infinity, height: 50,
                child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verify,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isVerifying
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Verify OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
            const SizedBox(height: 16),

            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text("Didn't receive? ", style: TextStyle(color: ts, fontSize: 13)),
              _isResending
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : GestureDetector(
                  onTap: _resendTimer == 0 ? () async {
                    setState(() => _isResending = true);
                    await Future.delayed(const Duration(seconds: 1));
                    setState(() => _isResending = false);
                    _startTimer();
                  } : null,
                  child: Text(_resendTimer > 0 ? 'Resend in ${_resendTimer}s' : 'Resend OTP',
                      style: TextStyle(color: _resendTimer > 0 ? ts : const Color(0xFF1A73E8),
                          fontWeight: FontWeight.w600, fontSize: 13))),
            ]),
            const SizedBox(height: 24),

            // Demo hint
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3))),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Demo OTP: 123456', style: TextStyle(fontSize: 12, color: ts))),
                ])),
          ],
        ]),
      ),
    );
  }
}