import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _textCtrl;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(_textCtrl);
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 600), () => _textCtrl.forward());
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    final auth = context.read<AuthProvider>();
    if (auth.isLoading) {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return auth.isLoading;
      });
    }
    if (!mounted) return;

    Navigator.pushReplacement(context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
          auth.isLoggedIn && auth.currentUser != null
              ? const HomeScreen()
              : const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ));
  }

  @override
  void dispose() { _textCtrl.dispose(); super.dispose(); }

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
            errorBuilder: (_, __, ___) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1A73E8), Color(0xFF0EA5E9)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // ---- Gradient scrim (keeps text/lottie readable) ----
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF060A14).withValues(alpha: 0.35),
                  const Color(0xFF060A14).withValues(alpha: 0.30),
                  const Color(0xFF060A14).withValues(alpha: 0.65),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ---- Content ----
          Column(children: [
            const Spacer(flex: 2),

            // 🚗 Car Driving Lottie
            Lottie.asset(
              'assets/animations/car_driving.json',
              width: 220, height: 160,
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (_, __, ___) => Stack(alignment: Alignment.center, children: [
                Container(width: 110, height: 110,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 40, offset: const Offset(0, 12))]),
                    child: Stack(alignment: Alignment.center, children: [
                      const Icon(Icons.directions_car_filled_rounded, color: Color(0xFF1A73E8), size: 56),
                      Positioned(bottom: 18, right: 18,
                          child: Container(width: 22, height: 22,
                              decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 13))),
                    ])),
              ]),
            ),

            const SizedBox(height: 20),

            // App name + tagline
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textFade,
                child: Column(children: [
                  const Text('SecureRide',
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white,
                          letterSpacing: 1.0, shadows: [Shadow(color: Colors.black54, blurRadius: 12)])),
                  const SizedBox(height: 10),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
                      child: const Text('Safe. Private. Connected.',
                          style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 0.5))),
                  const SizedBox(height: 24),
                  Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center,
                      children: const [
                        _Pill(icon: Icons.verified_user_rounded, label: 'Verified'),
                        _Pill(icon: Icons.location_on_rounded, label: 'Live Track'),
                        _Pill(icon: Icons.sos_rounded, label: 'SOS Alert'),
                      ]),
                ]),
              ),
            ),

            const Spacer(flex: 2),

            // Loading lottie
            FadeTransition(
              opacity: _textFade,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(children: [
                  Lottie.asset('assets/animations/loading.json',
                      width: 60, height: 60, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => SizedBox(width: 28, height: 28,
                          child: CircularProgressIndicator(color: Colors.white.withValues(alpha: 0.7), strokeWidth: 2.5))),
                  const SizedBox(height: 8),
                  Consumer<AuthProvider>(builder: (_, auth, __) =>
                      Text(auth.isLoading ? 'Checking session...' : 'Loading...',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12))),
                ]),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 14),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    ]),
  );
}