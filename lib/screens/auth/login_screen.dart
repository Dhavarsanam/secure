import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../home/home_screen.dart';
import '../admin/admin_login_screen.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import '../../utils/app_icon_colors.dart';

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
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      body: PageView(
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                const SizedBox(height: 48),

                // Shield + Car Logo (spec requirement)
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: const Color(0xFF1A73E8).withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 44),
                    Positioned(bottom: 10, right: 10,
                        child: Container(width: 22, height: 22,
                            decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 13))),
                  ]),
                ),
                const SizedBox(height: 14),
                Text('SecureRide',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: tp)),
                Text('Safe. Private. Connected.',
                    style: TextStyle(fontSize: 13, color: ts)),
                const SizedBox(height: 40),

                // Login Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07), blurRadius: 20)],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Welcome Back!',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tp)),
                      Text('Login to continue',
                          style: TextStyle(fontSize: 13, color: ts)),
                      const SizedBox(height: 22),

                      // Email field
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: tp, fontSize: 14),
                        decoration: _deco('Email', Icons.email_outlined, isDark),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        style: TextStyle(color: tp, fontSize: 14),
                        decoration: _deco('Password', Icons.lock_outline, isDark).copyWith(
                          suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: appIconColor(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined), size: 20),
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
                                activeColor: const Color(0xFF1A73E8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                side: BorderSide(color: ts))),
                        const SizedBox(width: 6),
                        Text('Remember me', style: TextStyle(fontSize: 12, color: ts)),
                        const Spacer(),
                        GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                            child: const Text('Forgot Password?',
                                style: TextStyle(color: Color(0xFF1A73E8), fontSize: 12, fontWeight: FontWeight.w600))),
                      ]),
                      const SizedBox(height: 22),

                      // Login Button
                      SizedBox(width: double.infinity, height: 50,
                          child: ElevatedButton(
                              onPressed: isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                              child: isLoading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),

                // Don't have account
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text("Don't have an account? ", style: TextStyle(color: ts, fontSize: 14)),
                  GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                      child: const Text('Sign up', style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.w700, fontSize: 14))),
                ]),
                const SizedBox(height: 16),

                // Swipe hint for admin
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.swipe_left_rounded, color: appIconColor(Icons.swipe_left_rounded), size: 16),
                  const SizedBox(width: 4),
                  Text('Swipe left for Admin Panel',
                      style: TextStyle(fontSize: 11, color: ts.withValues(alpha: 0.4))),
                ]),
                const SizedBox(height: 8),
                // Page dots
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 20, height: 4, decoration: BoxDecoration(color: const Color(0xFF1A73E8), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Container(width: 6, height: 4, decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
                ]),
                const SizedBox(height: 24),
              ]),
            ),
          ),
          const SizedBox(), // dummy page for swipe
        ],
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon, bool isDark) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: appIconColor(icon), size: 20),
    filled: true,
    fillColor: isDark ? const Color(0xFF252538) : const Color(0xFFF9FAFB),
    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280), fontSize: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF2D2D44) : const Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF2D2D44) : const Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
