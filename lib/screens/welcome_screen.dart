import 'package:flutter/material.dart';

import '../core/trexven_motion.dart';
import '../widgets/trexven_auth_design.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TrexvenAuthShell(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const TrexvenAuthBrand(size: 96),
                  const SizedBox(height: 32),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Run your business\n',
                          style: TextStyle(
                            color: TrexvenAuthColors.navy(context),
                          ),
                        ),
                        const TextSpan(
                          text: 'smarter.',
                          style: TextStyle(
                            color: TrexvenAuthColors.blue,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Manage your store, inventory, employees, sales '
                    'and security from one powerful platform.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TrexvenAuthColors.muted(context),
                      fontSize: 15,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 44),
                  TrexvenAuthPrimaryButton(
                    label: 'Create an Account',
                    onPressed: () => Navigator.push(
                      context,
                      TrexvenPageRoute(page: const RegisterScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TrexvenAuthSecondaryButton(
                    label: 'Sign In',
                    onPressed: () => Navigator.push(
                      context,
                      TrexvenPageRoute(page: const LoginScreen()),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Secure • Simple • Built for growing businesses',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: TrexvenAuthColors.muted(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
