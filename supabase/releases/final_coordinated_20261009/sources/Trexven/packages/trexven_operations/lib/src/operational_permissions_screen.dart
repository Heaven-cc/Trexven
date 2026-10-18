import 'package:flutter/material.dart';
import 'operations_client.dart';

class OperationalPermissionsScreen extends StatefulWidget {
  final OperationsClient api;
  const OperationalPermissionsScreen({super.key, required this.api});
  @override
  State<OperationalPermissionsScreen> createState() =>
      _OperationalPermissionsScreenState();
}

class _OperationalPermissionsScreenState
    extends State<OperationalPermissionsScreen> {
  late final Future<List<Map<String, dynamic>>> employees = widget.api.list(
    'employees',
  );
  Future<void> edit(Map<String, dynamic> e) async {
    final rows = await widget.api.list(
      'employee_permissions',
      foreignKey: 'employee_id',
      foreignId: e['id'] as String,
    );
    if (!mounted) return;
    final granted = {
      for (final p in rows) p['permission_id'] as String: p['granted'] == true,
    };
    var busy = false;
    String? error;
    const operational = [
      'offline_cash',
      'approve_credit',
      'record_credit_repayment',
      'approve_refund',
      'inspect_returns',
      'reverse_credit_repayment',
      'stocktake',
      'approve_stocktake',
      'dispose_stock',
      'restore_stock',
      'writeoff_stock',
      'supplier_returns',
      'approve_supplier_returns',
      'cash_shifts',
      'cash_movements',
      'review_cash_shifts',
    ];
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            '${e['full_name'] ?? e['name'] ?? 'Employee'} · permissions',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null) Text(error!),
                  for (final p in operational)
                    CheckboxListTile(
                      title: Text(p.replaceAll('_', ' ')),
                      value: granted[p] ?? false,
                      onChanged: busy
                          ? null
                          : (value) async {
                              update(() => busy = true);
                              try {
                                await widget.api
                                    .call('set_trexven_employee_permission', {
                                      'p_employee_id': e['id'],
                                      'p_permission': p,
                                      'p_granted': value == true,
                                    });
                                if (context.mounted)
                                  update(() => granted[p] = value == true);
                              } catch (ex) {
                                if (context.mounted)
                                  update(
                                    () => error = 'Change not confirmed: $ex',
                                  );
                              } finally {
                                if (context.mounted) update(() => busy = false);
                              }
                            },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Operational permissions')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: employees,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('Employee access unavailable.'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sensitive operations remain restricted to owners and explicitly authorized managers. Grants never change a role.',
              ),
            ),
            for (final e in snapshot.data!)
              ListTile(
                title: Text('${e['full_name'] ?? e['name'] ?? 'Employee'}'),
                subtitle: Text('${e['role']} · ${e['status']}'),
                onTap: () => edit(e),
              ),
          ],
        );
      },
    ),
  );
}
