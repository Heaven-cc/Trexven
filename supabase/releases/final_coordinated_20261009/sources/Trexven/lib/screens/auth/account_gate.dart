import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/database_service.dart';
import '../main_screen.dart';
import '../welcome_screen.dart';
import '../setup/business_setup_screen.dart';

/// Shared destination for email, Google, and restored sessions.
class AccountGate extends StatefulWidget {
  const AccountGate({super.key});
  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  late Future<Widget> _destination;
  @override
  void initState() {
    super.initState();
    _destination = _resolve();
  }

  Future<Widget> _resolve() async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      return const WelcomeScreen();
    }
    if (auth.currentSession!.isExpired) {
      await auth.refreshSession();
    }
    final user = auth.currentUser;
    if (user == null) {
      return const WelcomeScreen();
    }
    final database = DatabaseService();
    late final dynamic business;
    try {
      business = await database.getBusinessProfile();
    } on OwnerBusinessSelectionRequired {
      final businesses = await database.getOwnedBusinesses();
      if (auth.currentUser?.id != user.id) return const WelcomeScreen();
      return Scaffold(
        appBar: AppBar(title: const Text('Select your business')),
        body: ListView(children: [
          for (final row in businesses) ListTile(
            title: Text(row['business_name']?.toString() ?? 'Business'),
            onTap: () async {
              await database.selectOwnedBusiness(row['id'].toString());
              if (mounted) setState(() => _destination = _resolve());
            },
          ),
        ]),
      );
    }
    if (auth.currentUser?.id != user.id) {
      return const WelcomeScreen();
    }
    if (business != null) {
      return const MainScreen();
    }
    return BusinessSetupScreen(
      ownerName:
          user.userMetadata?['full_name']?.toString() ??
          user.userMetadata?['name']?.toString() ??
          '',
      email: user.email ?? '',
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _destination,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.error is OwnerAppAccessDenied
                        ? 'TREXVEN is for business owners. Sign in to TREXVEN POS with your employee account.'
                        : 'Unable to load your business. Check your connection or contact your business owner.',
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.error is! OwnerAppAccessDenied) ElevatedButton(
                    onPressed: () => setState(() => _destination = _resolve()),
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: () async {
                      DatabaseService().clearBusinessSelection();
                      await Supabase.instance.client.auth.signOut();
                      if (mounted) setState(() => _destination = _resolve());
                    },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return snapshot.data ??
          const Scaffold(body: Center(child: CircularProgressIndicator()));
    },
  );
}
