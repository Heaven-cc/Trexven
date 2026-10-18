import 'package:trexven_design_system/trexven_design_system.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'core/theme_provider.dart';
import 'core/user_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/account_gate.dart';
import 'screens/auth/reset_password_screen.dart';
import 'widgets/build_error_fallback.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler for Flutter framework errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  try {
    await Supabase.initialize(
      url: String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://ufehcfrlygqvminfjumf.supabase.co',
      ),
      publishableKey: String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
        defaultValue: 'sb_publishable_xSChVTnwM2kTfbcllAXlvA_7MZC4_Yt',
      ),
    );
  } catch (e) {
    debugPrint('Supabase initialization failed.');
    runApp(
      MaterialApp(
        theme: TrexvenTheme.lightTheme,
        darkTheme: TrexvenTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Unable to initialize TREXVEN. Check your connection.'),
                TextButton(onPressed: main, child: Text('Retry')),
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
      child: TrexvenApp(),
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
          destination = ResetPasswordScreen();
        } else if (state.event == AuthChangeEvent.signedOut) {
          // A deleted account may still need its durable completion receipt.
          destination = AccountGate();
        } else if (state.event == AuthChangeEvent.signedIn &&
            nextId != _userId) {
          destination = AccountGate();
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
          theme: TrexvenTheme.lightTheme,
          darkTheme: TrexvenTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: SplashScreen(),
          builder: (context, child) {
            // Global error boundary to prevent blank screens
            ErrorWidget.builder = (details) => BuildErrorFallback(
              onRetry: () => _navigator.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => SplashScreen()),
                (route) => false,
              ),
            );
            return child ?? SizedBox.shrink();
          },
        );
      },
    );
  }
}
