import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/trexven_logo.dart';
import 'welcome_screen.dart';
import 'main_screen.dart';

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

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();

    _checkSession();
  }

  Future<void> _checkSession() async {
    // Wait for animation and a small delay
    await Future.delayed(const Duration(milliseconds: 2200));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      _navigateTo(const WelcomeScreen());
    } else {
      // Fetch user data to see if they have a business
      try {
        final userId = session.user.id;
        final businessData = await Supabase.instance.client
            .from('businesses')
            .select('business_name')
            .eq('owner_id', userId)
            .maybeSingle();

        if (businessData == null) {
          // No business set up yet
          _navigateTo(const WelcomeScreen());
        } else {
          _navigateTo(MainScreen(
            businessName: businessData['business_name'] ?? 'Your Business',
            ownerName: session.user.userMetadata?['full_name'] ?? 'Owner',
          ));
        }
      } catch (e) {
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: .85,
              end: 1,
            ).animate(_animation),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TrexvenLogo(size: 72),
                SizedBox(height: 20),
                Text(
                  'TREXVEN',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Smart management for your business.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
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
