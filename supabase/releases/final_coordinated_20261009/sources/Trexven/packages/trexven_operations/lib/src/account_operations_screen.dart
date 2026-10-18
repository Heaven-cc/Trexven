import 'package:flutter/material.dart';
import 'operations_client.dart';

class AccountOperationsScreen extends StatefulWidget {
  final OperationsClient api;
  const AccountOperationsScreen({super.key, required this.api});
  @override
  State<AccountOperationsScreen> createState() =>
      _AccountOperationsScreenState();
}

class _AccountOperationsScreenState extends State<AccountOperationsScreen> {
  late Future<Map<String, dynamic>> health;
  late Future<List<Map<String, dynamic>>> requests;
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    health = widget.api
        .call('get_trexven_operational_health', {
          'p_business_id': widget.api.businessId,
        })
        .then((v) => Map<String, dynamic>.from(v as Map));
    requests = widget.api.list('account_lifecycle_requests');
  }

  Future<void> request(String kind) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request account $kind'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A verified owner request starts a reviewed workflow. Financial records, pending sales and authentication accounts are retained.',
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit request'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await widget.api.call('request_trexven_account_lifecycle', {
        'p_business_id': widget.api.businessId,
        'p_request_id': widget.api.requestId(),
        'p_kind': kind,
        'p_reason': text,
      });
      if (mounted)
        setState(() {
          message = 'Owner request recorded. No records were deleted.';
          load();
        });
    } catch (e) {
      if (mounted) setState(() => message = 'Request not confirmed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account and recovery')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (message != null) Text(message!),
        if (busy) const LinearProgressIndicator(),
        Wrap(
          spacing: 8,
          children: [
            for (final kind in ['recovery', 'deletion'])
              OutlinedButton(
                onPressed: busy ? null : () => request(kind),
                child: Text('Request $kind'),
              ),
          ],
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: health,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Text('Operational status unavailable.');
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final h = snapshot.data!, backup = h['latest_backup'] as Map?;
            return Text(
              'Failed billing events ${h['failed_billing_events']} · recent application errors ${h['recent_application_errors']}\n${backup == null ? 'No recovery verification metadata recorded.' : 'Backup ${backup['status']} · captured ${backup['captured_at']} · recovery checked ${backup['recovery_checked_at'] ?? "not verified"}'}',
            );
          },
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: requests,
          builder: (context, snapshot) => Column(
            children: [
              for (final r in snapshot.data ?? <Map<String, dynamic>>[])
                ListTile(
                  title: Text('${r['kind']} · ${r['status']}'),
                  subtitle: Text('${r['created_at']} · ${r['reason']}'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
