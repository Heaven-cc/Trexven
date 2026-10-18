import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:odt/main.dart';
import 'package:odt/core/theme_provider.dart';
import 'package:odt/screens/splash_screen.dart';
import 'package:odt/screens/welcome_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.invalid',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
  });
  testWidgets('Signed-out app boots and navigates to welcome', (tester) async {
    final originalErrorBuilder = ErrorWidget.builder;
    addTearDown(() => ErrorWidget.builder = originalErrorBuilder);
    late ThemeProvider theme;
    await tester.runAsync(() async {
      theme = ThemeProvider();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: theme,
        child: const TrexvenApp(),
      ),
    );
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    ErrorWidget.builder = originalErrorBuilder;
    theme.dispose();
  });
}
