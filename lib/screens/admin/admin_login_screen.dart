import 'package:flutter/material.dart';
import 'admin_dashboard_screen.dart';
import '../../utils/app_icon_colors.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl = TextEditingController(text: 'admin@secureride.com');
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  // Demo credentials
  static const _adminEmail = 'admin@secureride.com';
  static const _adminPass = 'admin123';

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(seconds: 1));
    if (_emailCtrl.text.trim() == _adminEmail && _passCtrl.text.trim() == _adminPass) {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
      }
    } else {
      setState(() { _error = 'Invalid admin credentials!'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF9333EA)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 40),
              Container(width: 90, height: 90,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 10))]),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF7C3AED), size: 48)),
              const SizedBox(height: 20),
              const Text('Admin Panel', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const Text('SecureRide Management', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 48),

              // Login Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Sign In', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 4),
                  const Text('Enter your admin credentials', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration('Admin Email', Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: appIconColor(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
                          onPressed: () => setState(() => _obscure = !_obscure)),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
                          const SizedBox(width: 6),
                          Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                        ])),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        child: _loading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Login as Admin'),
                      )),

                  const SizedBox(height: 16),
                  Container(padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        const Icon(Icons.info_outline, color: Color(0xFF7C3AED), size: 16),
                        const SizedBox(width: 8),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Demo Credentials', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                          Text('Email: admin@secureride.com', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                          Text('Password: admin123', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                        ])),
                      ])),
                ]),
              ),

              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← Back to App', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon, color: appIconColor(icon)),
    filled: true, fillColor: const Color(0xFFF5F7FA),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
  );
}
