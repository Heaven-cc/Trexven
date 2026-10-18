import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'core/theme_provider.dart';
import 'core/user_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/account_gate.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/welcome_screen.dart';
import 'widgets/build_error_fallback.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler for Flutter framework errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  try {
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://ufehcfrlygqvminfjumf.supabase.co',
      ),
      publishableKey: const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
        defaultValue: 'sb_publishable_xSChVTnwM2kTfbcllAXlvA_7MZC4_Yt',
      ),
    );
  } catch (e) {
    debugPrint('Supabase initialization failed.');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to initialize TREXVEN. Check your connection.',
                ),
                TextButton(onPressed: main, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const TrexvenApp(),
    ),
  );
}

class TrexvenApp extends StatefulWidget {
  const TrexvenApp({super.key});

  @override
  State<TrexvenApp> createState() => _TrexvenAppState();
}

class _TrexvenAppState extends State<TrexvenApp> {
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSubscription;
  String? _userId;
  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        final nextId = state.session?.user.id;
        Widget? destination;
        if (state.event == AuthChangeEvent.passwordRecovery) {
          destination = const ResetPasswordScreen();
        } else if (state.event == AuthChangeEvent.signedOut) {
          destination = const WelcomeScreen();
        } else if (state.event == AuthChangeEvent.signedIn &&
            nextId != _userId) {
          destination = const AccountGate();
        }
        _userId = nextId;
        if (destination != null) {
          final page = destination;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _navigator.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => page),
                (_) => false,
              );
            }
          });
          WidgetsBinding.instance.ensureVisualUpdate();
        }
      },
      onError: (Object error) {
        // Network/refresh failures should not become unhandled stream errors.
        debugPrint('Authentication refresh failed.');
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: _navigator,
          title: 'TREXVEN',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
          builder: (context, child) {
            // Global error boundary to prevent blank screens
            ErrorWidget.builder = (details) => BuildErrorFallback(
              onRetry: () => _navigator.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              ),
            );
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}
