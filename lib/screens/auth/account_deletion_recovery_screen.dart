import 'package:flutter/material.dart';
import '../../services/account_deletion_service.dart';
import 'account_gate.dart';

/// Available even after Auth removes the old session. Its secure credential can
/// only complete the previously confirmed deletion, never select another user.
class AccountDeletionRecoveryScreen extends StatefulWidget {
  const AccountDeletionRecoveryScreen({super.key});
  @override
  State<AccountDeletionRecoveryScreen> createState() =>
      _AccountDeletionRecoveryScreenState();
}

class _AccountDeletionRecoveryScreenState
    extends State<AccountDeletionRecoveryScreen> {
  bool busy = false;
  String? error;
  Future<void> resume() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AccountDeletionService().recover();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AccountGate()),
        (_) => false,
      );
    } catch (failure) {
      if (mounted)
        setState(
          () => error = failure is AccountDeletionError
              ? failure.message
              : 'Deletion could not be confirmed. Keep the original recovery record and try again.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account deletion')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Finish your confirmed deletion',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          const Text(
            'An account deletion was interrupted. Recover its original outcome before starting another request. Business and financial history are retained.',
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy ? null : resume,
            child: Text(
              busy ? 'Recovering deletion…' : 'Recover account deletion',
            ),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) =>
                          const AccountGate(skipDeletionRecovery: true),
                    ),
                    (_) => false,
                  ),
            child: const Text('Return to app'),
          ),
        ],
      ),
    ),
  );
}
