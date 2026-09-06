import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  // Admin-branded palette (purple accent kept for admin identity)
  static const Color _tp = Colors.white;        // primary text
  static const Color _ts = Color(0xFFCBC9E8);   // secondary text
  static const Color _accent = Color(0xFF9333EA);

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  // Real Firebase Auth sign-in (the password is verified by Firebase, not
  // compared against a string in the app) followed by an authorization
  // check: the signed-in account must have isAdmin: true on its Firestore
  // `users` document. Any account that isn't flagged as admin is signed
  // back out immediately, so a regular rider account can never reach the
  // dashboard just by guessing/knowing its own password.
  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });

    final result = await _authService.signIn(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );

    if (result['success'] != true) {
      setState(() { _error = result['error'] ?? 'Login failed. Please try again.'; _loading = false; });
      return;
    }

    final uid = result['user'].uid as String;
    final isAdmin = await _firestoreService.isUserAdmin(uid);

    if (!isAdmin) {
      await _authService.signOut();
      setState(() { _error = 'This account is not authorized for admin access.'; _loading = false; });
      return;
    }

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ---- Background image ----
          Image.asset(
            'assets/images/image1.png',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0A0E1A)),
          ),

          // ---- Dark + purple-tinted scrim ----
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1A0B2E).withValues(alpha: 0.38),
                  const Color(0xFF0B0716).withValues(alpha: 0.28),
                  const Color(0xFF0B0716).withValues(alpha: 0.60),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ---- Content (NO card — fields directly on background) ----
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 44),
                  Center(
                    child: Container(width: 90, height: 90,
                        decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 10))]),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 48)),
                  ),
                  const SizedBox(height: 20),
                  const Text('Admin Panel',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _tp,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 12)])),
                  const Text('SecureRide Management',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _ts, fontSize: 14)),
                  const SizedBox(height: 44),

                  const Text('Sign In', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _tp,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 10)])),
                  const SizedBox(height: 4),
                  const Text('Enter your admin credentials', style: TextStyle(color: _ts, fontSize: 13)),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: _tp),
                    decoration: _inputDecoration('Admin Email', Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: _tp),
                    decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _ts),
                          onPressed: () => setState(() => _obscure = !_obscure)),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4))),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: Color(0xFFFCA5A5), size: 16),
                          const SizedBox(width: 6),
                          Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                        ])),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _accent, foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        child: _loading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Login as Admin'),
                      )),

                  const SizedBox(height: 16),
                  Container(padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.14))),
                      child: Row(children: [
                        const Icon(Icons.info_outline, color: Color(0xFFC4B5FD), size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Admin access', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC4B5FD))),
                          Text('Sign in with a regular SecureRide account that has isAdmin: true set on its Firestore user document.',
                              style: TextStyle(fontSize: 11, color: _ts.withValues(alpha: 0.85))),
                        ])),
                      ])),

                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('← Back to App', style: TextStyle(color: _ts, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: _ts),
    prefixIcon: Icon(icon, color: _ts),
    filled: true, fillColor: Colors.white.withValues(alpha: 0.08),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 2)),
  );
}