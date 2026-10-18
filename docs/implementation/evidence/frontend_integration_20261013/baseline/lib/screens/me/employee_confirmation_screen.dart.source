import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
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
    final muted = theme.trexvenColors.muted!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TrexvenLogo(size: 80),
              SizedBox(height: 40),
              Icon(
                Icons.check_circle_rounded,
                color: theme.trexvenColors.success!,
                size: 64,
              ),
              SizedBox(height: TrexvenSpacing.sectionGap),
              Text(
                'Account Created',
                style: TextStyle(
                  fontSize: TrexvenFontSize.title,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Initial login credentials have been created successfully for $name.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, height: 1.5),
              ),
              SizedBox(height: 40),
              Container(
                padding: TrexvenSpacing.pagePadding,
                decoration: BoxDecoration(
                  color: theme.trexvenColors.cardBackground,
                  borderRadius: BorderRadius.circular(TrexvenRadii.card),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.2 : 0.03,
                      ),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _infoRow(theme, 'Employee', name),
                    Divider(
                      height: 32,
                      color: theme.trexvenColors.border?.withValues(alpha: 0.5),
                    ),
                    _infoRow(theme, 'Role', role),
                    Divider(
                      height: 32,
                      color: theme.trexvenColors.border?.withValues(alpha: 0.5),
                    ),
                    _infoRow(theme, 'Employee ID', employeeCode, isCode: true),
                  ],
                ),
              ),
              SizedBox(height: 40),
              Text(
                'Share this Employee ID with the staff member. They will use it to sign in to Trexven POS.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: TrexvenFontSize.caption,
                  color: muted.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(height: 48),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: TrexvenSpacing.buttonHeight,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandBlue,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: Text(
                      'Return to Personnel',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    ThemeData theme,
    String label,
    String value, {
    bool isCode = false,
  }) {
    final muted = theme.trexvenColors.muted!;

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
            fontSize: isCode ? TrexvenFontSize.input : TrexvenFontSize.body,
            fontFamily: isCode ? 'monospace' : null,
            letterSpacing: isCode ? 1 : 0,
          ),
        ),
      ],
    );
  }
}
