import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odt/core/trexven_motion.dart';
import 'package:odt/screens/welcome_screen.dart';
import 'package:odt/screens/auth/login_screen.dart';
import 'package:odt/screens/auth/register_screen.dart';
import 'package:odt/widgets/trexven_auth_design.dart';
import 'package:trexven_design_system/trexven_design_system.dart';

void main() {
  testWidgets('Welcome screen renders reference UI and navigates to Register and Login',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TrexvenTheme.lightTheme,
        home: const WelcomeScreen(),
      ),
    );

    expect(find.text('TREXVEN'), findsOneWidget);
    expect(find.textContaining('smarter.'), findsOneWidget);
    expect(find.text('Create an Account'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    // Tap Create an Account
    await tester.tap(find.text('Create an Account'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.textContaining('Create your '), findsOneWidget);

    // Tap back button
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);

    // Tap Sign In
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Register screen renders country phone picker and input components',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TrexvenTheme.lightTheme,
        home: const RegisterScreen(),
      ),
    );

    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.byType(TrexvenAuthPhoneField), findsOneWidget);

    // Ensure Phone Field is visible and tap Country Flag Picker
    await tester.ensureVisible(find.byType(TrexvenAuthPhoneField));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(TrexvenAuthPhoneField),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();

    // Verify country picker dialog opens
    expect(find.text('Search country'), findsOneWidget);
  });

  testWidgets('TrexvenAnimatedPress animates on touch', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrexvenAnimatedPress(
            onTap: () => tapped = true,
            child: const Text('Press Me'),
          ),
        ),
      ),
    );

    expect(find.text('Press Me'), findsOneWidget);
    await tester.tap(find.text('Press Me'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });
}
