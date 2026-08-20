import 'package:flutter/material.dart';
import '../../widgets/trexven_logo.dart';
import '../main_screen.dart';

class SetupCompleteScreen extends StatelessWidget {
  final String businessName;
  final String businessType;
  final String ownerName;

  const SetupCompleteScreen({
    super.key,
    required this.businessName,
    required this.businessType,
    required this.ownerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 82, height: 82,
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 48, color: Color(0xFF16A34A)),
              ),
              const SizedBox(height: 26),
              const Text("You're all set!", textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 10),
              const Text('Your business has been successfully created.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Color(0xFF64748B))),
              const SizedBox(height: 32),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 20, offset: const Offset(0, 8))]),
                child: Column(
                  children: [
                    const TrexvenLogo(size: 58),
                    const SizedBox(height: 18),
                    Text(businessName.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: .8, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                        SizedBox(width: 6),
                        Text('Business setup complete', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => MainScreen(
                        businessName: businessName, 
                        ownerName: ownerName
                      )
                    ), 
                    (route) => false
                  );
                },
                child: const Text('Go to Dashboard'),
              ),
              const SizedBox(height: 20),
              const Text('Powered by TREXVEN', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
