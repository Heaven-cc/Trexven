import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/database_service.dart';
import '../../services/account_deletion_service.dart';
import 'account_deletion_recovery_screen.dart';
import '../main_screen.dart';
import '../welcome_screen.dart';
import '../setup/business_setup_screen.dart';

/// Shared destination for email, Google, and restored sessions.
class AccountGate extends StatefulWidget {
  const AccountGate({super.key, this.skipDeletionRecovery = false});
  final bool skipDeletionRecovery;
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
    if (!widget.skipDeletionRecovery) {
      final deletion = AccountDeletionService();
      final pending = await deletion.pending();
      if (pending != null) {
        if (pending['confirmed_deleted'] == true) {
          await deletion.recover();
        } else {
          return const AccountDeletionRecoveryScreen();
        }
      }
    }
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      return WelcomeScreen();
    }
    if (auth.currentSession!.isExpired) {
      await auth.refreshSession();
    }
    final user = auth.currentUser;
    if (user == null) {
      return WelcomeScreen();
    }
    final database = DatabaseService();
    late final dynamic business;
    try {
      business = await database.getBusinessProfile();
    } on OwnerBusinessSelectionRequired {
      final businesses = await database.getOwnedBusinesses();
      if (auth.currentUser?.id != user.id) return WelcomeScreen();
      return Scaffold(
        appBar: AppBar(title: Text('Select your business')),
        body: ListView(
          children: [
            for (final row in businesses)
              ListTile(
                title: Text(row['business_name']?.toString() ?? 'Business'),
                onTap: () async {
                  await database.selectOwnedBusiness(row['id'].toString());
                  if (mounted) setState(() => _destination = _resolve());
                },
              ),
          ],
        ),
      );
    }
    if (auth.currentUser?.id != user.id) {
      return WelcomeScreen();
    }
    if (business != null) {
      return MainScreen();
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
              padding: TrexvenSpacing.pagePadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.error is OwnerAppAccessDenied
                        ? 'TREXVEN is for business owners. Sign in to TREXVEN POS with your employee account.'
                        : 'Unable to load your business. Check your connection or contact your business owner.',
                  ),
                  SizedBox(height: TrexvenSpacing.fieldGap),
                  if (snapshot.error is! OwnerAppAccessDenied)
                    ElevatedButton(
                      onPressed: () =>
                          setState(() => _destination = _resolve()),
                      child: Text('Retry'),
                    ),
                  TextButton(
                    onPressed: () async {
                      DatabaseService().clearBusinessSelection();
                      await Supabase.instance.client.auth.signOut();
                      if (mounted) setState(() => _destination = _resolve());
                    },
                    child: Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return snapshot.data ?? Scaffold(body: Center(child: TrexvenLoading()));
    },
  );
}
