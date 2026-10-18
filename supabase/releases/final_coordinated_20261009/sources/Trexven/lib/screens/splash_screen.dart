import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/trexven_logo.dart';
import 'welcome_screen.dart';
import 'auth/account_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();

    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      // Let the entrance animation finish without an additional idle delay.
      await Future.delayed(const Duration(milliseconds: 900));

      if (!mounted) return;

      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        _navigateTo(const WelcomeScreen());
      } else {
        _navigateTo(const AccountGate());
      }
    } catch (e) {
      debugPrint('SplashScreen Error: $e');
      if (mounted) {
        _navigateTo(const WelcomeScreen());
      }
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: .85, end: 1).animate(_animation),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TrexvenLogo(size: 72),
                const SizedBox(height: 20),
                const Text(
                  'TREXVEN',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Smart management for your business.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
