import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import '../admin/admin_login_screen.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _remember = false;
  final PageController _pageCtrl = PageController();

  // Fixed dark-branded palette for the auth flow (over the background image)
  static const Color _tp = Colors.white;                 // primary text
  static const Color _ts = Color(0xFFB8C2D9);            // secondary text
  static const Color _accent = Color(0xFF1A73E8);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await context.read<AuthProvider>().login(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );
    if (!mounted) return;
    if (result['success']) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(result['error'] ?? 'Login failed')),
        ]),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

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

          // ---- Dark gradient scrim (readability) ----
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF060A14).withValues(alpha: 0.30),
                  const Color(0xFF060A14).withValues(alpha: 0.22),
                  const Color(0xFF060A14).withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ---- Content (NO card — fields sit directly on the background) ----
          PageView(
            controller: _pageCtrl,
            onPageChanged: (i) {
              if (i == 1) {
                _pageCtrl.jumpToPage(0);
                Navigator.push(context, PageRouteBuilder(
                  pageBuilder: (_, anim, __) => const AdminLoginScreen(),
                  transitionsBuilder: (_, anim, __, child) =>
                      SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(anim), child: child),
                ));
              }
            },
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 52),

                      // Shield + Car Logo (centered)
                      Center(
                        child: Container(
                          width: 88, height: 88,
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.5), blurRadius: 28, offset: const Offset(0, 10))],
                          ),
                          child: Stack(alignment: Alignment.center, children: [
                            const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 44),
                            Positioned(bottom: 10, right: 10,
                                child: Container(width: 22, height: 22,
                                    decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 13))),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('SecureRide',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _tp,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 12)])),
                      const Text('Safe. Private. Connected.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: _ts)),
                      const SizedBox(height: 40),

                      // ---- Form directly on background ----
                      Form(
                        key: _formKey,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Welcome Back!',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _tp,
                                  shadows: [Shadow(color: Colors.black54, blurRadius: 10)])),
                          const SizedBox(height: 4),
                          const Text('Login to continue',
                              style: TextStyle(fontSize: 14, color: _ts)),
                          const SizedBox(height: 26),

                          // Email field
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: _tp, fontSize: 14),
                            decoration: _deco('Email', Icons.email_outlined),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email required';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            style: const TextStyle(color: _tp, fontSize: 14),
                            decoration: _deco('Password', Icons.lock_outline).copyWith(
                              suffixIcon: IconButton(
                                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _ts, size: 20),
                                  onPressed: () => setState(() => _obscure = !_obscure)),
                            ),
                            validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                          ),
                          const SizedBox(height: 12),

                          // Remember me + Forgot
                          Row(children: [
                            SizedBox(width: 18, height: 18,
                                child: Checkbox(
                                    value: _remember,
                                    onChanged: (v) => setState(() => _remember = v ?? false),
                                    activeColor: _accent,
                                    checkColor: Colors.white,
                                    side: const BorderSide(color: _ts),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)))),
                            const SizedBox(width: 6),
                            const Text('Remember me', style: TextStyle(fontSize: 12, color: _ts)),
                            const Spacer(),
                            GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                                child: const Text('Forgot Password?',
                                    style: TextStyle(color: Color(0xFF5BA3FF), fontSize: 12, fontWeight: FontWeight.w600))),
                          ]),
                          const SizedBox(height: 24),

                          // Login Button
                          SizedBox(width: double.infinity, height: 52,
                              child: ElevatedButton(
                                  onPressed: isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: _accent, foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                                  child: isLoading
                                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                      : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
                        ]),
                      ),
                      const SizedBox(height: 22),

                      // Don't have account
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text("Don't have an account? ", style: TextStyle(color: _ts, fontSize: 14)),
                        GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                            child: const Text('Sign up', style: TextStyle(color: Color(0xFF5BA3FF), fontWeight: FontWeight.w700, fontSize: 14))),
                      ]),
                      const SizedBox(height: 16),

                      // Swipe hint for admin
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.swipe_left_rounded, color: _ts.withValues(alpha: 0.6), size: 16),
                        const SizedBox(width: 4),
                        Text('Swipe left for Admin Panel',
                            style: TextStyle(fontSize: 11, color: _ts.withValues(alpha: 0.6))),
                      ]),
                      const SizedBox(height: 8),
                      // Page dots
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(width: 20, height: 4, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 4),
                        Container(width: 6, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
                      ]),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              const SizedBox(), // dummy page for swipe
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: _ts, size: 20),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.08),
    labelStyle: const TextStyle(color: _ts, fontSize: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 2)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}