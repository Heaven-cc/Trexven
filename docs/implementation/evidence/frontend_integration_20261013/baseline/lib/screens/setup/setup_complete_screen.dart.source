import 'package:trexven_design_system/trexven_design_system.dart';
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
    final theme = Theme.of(context);
    final successColor = theme.trexvenColors.success!;
    final muted = theme.trexvenColors.muted!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            children: [
              Spacer(),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: successColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, size: 48, color: successColor),
              ),
              SizedBox(height: 26),
              Text(
                "You're all set!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: TrexvenFontSize.display,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Your business has been successfully created.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: TrexvenFontSize.input, color: muted),
              ),
              SizedBox(height: TrexvenSpacing.sectionGap),
              Container(
                width: double.infinity,
                padding: TrexvenSpacing.pagePadding,
                decoration: BoxDecoration(
                  color: theme.trexvenColors.cardBackground,
                  borderRadius: BorderRadius.circular(TrexvenRadii.card),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.2 : 0.04,
                      ),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TrexvenLogo(size: 58),
                    SizedBox(height: TrexvenSpacing.fieldGap),
                    Text(
                      businessName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: TrexvenFontSize.section,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: successColor, size: 18),
                        SizedBox(width: 6),
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
              Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => MainScreen()),
                  (_) => false,
                ),
                child: Text('Go to Dashboard'),
              ),
              SizedBox(height: TrexvenSpacing.fieldGap),
              Text(
                'Powered by TREXVEN',
                style: TextStyle(
                  fontSize: TrexvenFontSize.caption,
                  color: theme.trexvenColors.muted?.withValues(alpha: 0.5),
                ),
              ),
              SizedBox(height: TrexvenSpacing.sectionGap),
            ],
          ),
        ),
      ),
    );
  }
}
