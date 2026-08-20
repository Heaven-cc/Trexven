import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_theme.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ufehcfrlygqvminfjumf.supabase.co',
    publishableKey: 'sb_publishable_xSChVTnwM2kTfbcllAXlvA_7MZC4_Yt',
  );

  runApp(const TrexvenApp());
}

class TrexvenApp extends StatelessWidget {
  const TrexvenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TREXVEN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
