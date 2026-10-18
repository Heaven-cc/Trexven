import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/core/constants.dart';
import 'src/features/auth/auth_provider.dart';
import 'src/features/auth/login_screen.dart';
import 'src/features/auth/branch_context.dart';
import 'src/features/pos/pos_shell.dart';
import 'src/features/pos/employee_settings_screen.dart';
import 'src/features/pos/offline_cash_screen.dart';
import 'src/features/pos/pending_sale_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConstants.url,
    publishableKey: SupabaseConstants.anonKey,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // TREXVEN Apple-inspired colors.
  static const Color _primaryBlue = Color(0xFF2F66B0);
  static const Color _background = Color(0xFFF2F2F7);
  static const Color _cardBackground = Colors.white;

  static const Color _primaryText = Color(0xFF1C1C1E);
  static const Color _secondaryText = Color(0xFF6B6B70);
  static const Color _separator = Color(0xFFE5E5EA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    Widget home;

    if (authState.employee == null) {
      home = const LoginScreen();
    } else if (authState.activeBusiness == null) {
      home = const BusinessLoadingScreen();
    } else if (authState.offlineCashOnly) {
      home = const PendingSaleGate(child: OfflineCashScreen());
    } else {
      home = const PendingSaleGate(child: BranchGate(child: PosShell()));
    }

    return MaterialApp(
      title: 'Trexven POS',
      debugShowCheckedModeBanner: false,

      themeMode: ref.watch(posThemeProvider),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryBlue,
          brightness: Brightness.dark,
        ),
      ),
      // Global iOS-inspired TREXVEN theme.
      theme: ThemeData(
        useMaterial3: true,

        scaffoldBackgroundColor: _background,

        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryBlue,
          brightness: Brightness.light,
          primary: _primaryBlue,
          surface: _cardBackground,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: _primaryText,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: _primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: _primaryText),
        ),

        cardTheme: CardThemeData(
          color: _cardBackground,
          elevation: 0,
          margin: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _separator),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: _primaryBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFB8C7DD),
            disabledForegroundColor: Colors.white70,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primaryBlue,
            minimumSize: const Size.fromHeight(50),
            side: const BorderSide(color: _separator),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          labelStyle: const TextStyle(color: _secondaryText),
          hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _separator),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _separator),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5484D)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5484D), width: 1.5),
          ),
        ),

        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _primaryText,
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),

        dividerTheme: const DividerThemeData(
          color: _separator,
          thickness: 1,
          space: 1,
        ),

        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: _primaryBlue,
        ),

        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),

        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: _primaryText),
          bodyMedium: TextStyle(color: _primaryText),
          bodySmall: TextStyle(color: _secondaryText),
          titleLarge: TextStyle(
            color: _primaryText,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: _primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      home: home,
    );
  }
}

class BusinessLoadingScreen extends StatelessWidget {
  const BusinessLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF2F66B0),
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Loading your business...',
                style: TextStyle(
                  color: Color(0xFF1C1C1E),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Please wait a moment',
                style: TextStyle(color: Color(0xFF6B6B70), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
