import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../widgets/trexven_logo.dart';

class EmployeeConfirmationScreen extends StatelessWidget {
  final String name;
  final String employeeCode;
  final String role;

  const EmployeeConfirmationScreen({
    super.key,
    required this.name,
    required this.employeeCode,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const TrexvenLogo(size: 80),
              const SizedBox(height: 40),
              Icon(Icons.check_circle_rounded, color: theme.trexvenColors.success ?? Colors.green, size: 64),
              const SizedBox(height: 24),
              Text(
                'Account Created',
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.w900, 
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Initial login credentials have been created successfully for $name.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.trexvenColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.03), 
                      blurRadius: 10, 
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _infoRow(theme, 'Employee', name),
                    Divider(height: 32, color: theme.trexvenColors.border?.withOpacity(0.5)),
                    _infoRow(theme, 'Role', role),
                    Divider(height: 32, color: theme.trexvenColors.border?.withOpacity(0.5)),
                    _infoRow(theme, 'Employee ID', employeeCode, isCode: true),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Share this Employee ID with the staff member. They will use it to sign in to Trexven POS.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: muted.withOpacity(0.6)),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Return to Personnel', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, String label, String value, {bool isCode = false}) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label, 
          style: TextStyle(color: muted, fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
            fontSize: isCode ? 16 : 14,
            fontFamily: isCode ? 'monospace' : null,
            letterSpacing: isCode ? 1 : 0,
          ),
        ),
      ],
    );
  }
}
