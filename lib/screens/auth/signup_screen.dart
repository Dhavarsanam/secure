import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import '../../utils/app_icon_colors.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose(); _emailController.dispose();
    _phoneController.dispose(); _passwordController.dispose(); _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await context.read<AuthProvider>().signUp(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );
    if (!mounted) return;
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Account created successfully! 🎉'),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['error'] ?? 'Signup failed'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Widget _buildField({
    required TextEditingController controller, required String label,
    required String hint, required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false, Widget? suffixIcon,
    required String? Function(String?) validator,
  }) {
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final fill = isDark ? const Color(0xFF252538) : Colors.white;
    final bdr = isDark ? const Color(0xFF2D2D44) : const Color(0xFFE5E7EB);
    return TextFormField(
      controller: controller, keyboardType: keyboardType,
      obscureText: obscureText, validator: validator,
      style: TextStyle(color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: TextStyle(color: ts),
        prefixIcon: Icon(icon, color: appIconColor(icon)),
        suffixIcon: suffixIcon,
        filled: true, fillColor: fill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: bdr)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: bdr)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: tp), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('Create Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: tp)),
              const SizedBox(height: 6),
              Text('Sign up to get started with SecureRide', style: TextStyle(fontSize: 14, color: ts)),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(children: [
                  _buildField(isDark: isDark, controller: _nameController, label: 'Full Name', hint: 'Enter your full name', icon: Icons.person_outline,
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your full name' : null),
                  const SizedBox(height: 16),
                  _buildField(isDark: isDark, controller: _emailController, label: 'Email', hint: 'Enter your email', icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email cannot be empty';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Enter a valid email';
                        return null;
                      }),
                  const SizedBox(height: 16),
                  _buildField(isDark: isDark, controller: _phoneController, label: 'Phone Number', hint: 'Enter your phone number', icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().length < 10) ? 'Enter a valid phone number' : null),
                  const SizedBox(height: 16),
                  _buildField(isDark: isDark, controller: _passwordController, label: 'Password', hint: 'Enter your password', icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: appIconColor(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null),
                  const SizedBox(height: 16),
                  _buildField(isDark: isDark, controller: _confirmController, label: 'Confirm Password', hint: 'Re-enter your password', icon: Icons.lock_outline,
                      obscureText: _obscureConfirm,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: appIconColor(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2,
                      ),
                      child: isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 28),
              Center(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Already have an account? ', style: TextStyle(color: ts)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('Login Here', style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
