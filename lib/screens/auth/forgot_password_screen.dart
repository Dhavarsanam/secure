import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_icon_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) setState(() => _emailSent = true);
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to send reset email.';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: tp),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _emailSent ? _buildSuccessView(isDark) : _buildFormView(isDark),
        ),
      ),
    );
  }

  Widget _buildFormView(bool isDark) {
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final fill = isDark ? const Color(0xFF252538) : Colors.white;
    final bdr = isDark ? const Color(0xFF2D2D44) : const Color(0xFFE5E7EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.lock_reset, color: Color(0xFF1A73E8), size: 40),
          ),
        ),
        const SizedBox(height: 32),
        Text('Forgot Password?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: tp)),
        const SizedBox(height: 8),
        Text(
          'Enter your registered email address. We\'ll send you a link to reset your password.',
          style: TextStyle(fontSize: 14, color: ts, height: 1.5),
        ),
        const SizedBox(height: 36),
        Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: tp),
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your registered email',
                labelStyle: TextStyle(color: ts),
                prefixIcon: Icon(Icons.email_outlined, color: appIconColor(Icons.email_outlined)),
                filled: true,
                fillColor: fill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: bdr)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: bdr)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2)),
                errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Email cannot be empty';
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(value.trim())) return 'Please enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Send Reset Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildSuccessView(bool isDark) {
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        Center(
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.mark_email_read_outlined, color: Color(0xFF22C55E), size: 50),
          ),
        ),
        const SizedBox(height: 32),
        Text('Email Sent!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: tp),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'Password reset link sent to\n${_emailController.text.trim()}',
          style: TextStyle(fontSize: 14, color: ts, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Check your inbox and follow the instructions to reset your password.',
          style: TextStyle(fontSize: 13, color: ts, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            child: const Text('Back to Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _resetPassword,
          child: const Text('Resend Email', style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
