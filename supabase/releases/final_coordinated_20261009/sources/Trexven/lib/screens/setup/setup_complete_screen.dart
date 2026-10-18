import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
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
    final theme = Theme.of(context);
    final successColor = theme.trexvenColors.success ?? Colors.green;
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: successColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, size: 48, color: successColor),
              ),
              const SizedBox(height: 26),
              Text(
                "You're all set!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your business has been successfully created.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: muted),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.trexvenColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        theme.brightness == Brightness.dark ? 0.2 : 0.04,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const TrexvenLogo(size: 58),
                    const SizedBox(height: 18),
                    Text(
                      businessName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: successColor, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Business setup complete',
                          style: TextStyle(
                            color: successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MainScreen()),
                  (_) => false,
                ),
                child: const Text('Go to Dashboard'),
              ),
              const SizedBox(height: 20),
              Text(
                'Powered by TREXVEN',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.trexvenColors.muted?.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
