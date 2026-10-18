import 'package:flutter/material.dart';
import 'operations_client.dart';
import 'cash_shift_screen.dart';

class FinancialOperationsScreen extends StatefulWidget {
  final OperationsClient api;
  final bool owner;
  const FinancialOperationsScreen({
    super.key,
    required this.api,
    required this.owner,
  });
  @override
  State<FinancialOperationsScreen> createState() =>
      _FinancialOperationsScreenState();
}

class _FinancialOperationsScreenState extends State<FinancialOperationsScreen> {
  late Future<List<List<Map<String, dynamic>>>> data;
  bool busy = false;
  Future<Map<String, dynamic>>? summary;
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    data = Future.wait([
      widget.api.list('credit_approvals'),
      widget.api.list('credit_accounts'),
      widget.api.list('sale_returns'),
      widget.api.list('credit_entries'),
      widget.api.list('offline_sale_reconciliations'),
    ]);
    if (widget.owner) summary = today();
  }

  Future<Map<String, dynamic>> today() async {
    final day = Map<String, dynamic>.from(
      await widget.api.call('get_trexven_business_day', {
            'p_business_id': widget.api.businessId,
          })
          as Map,
    );
    final totals = Map<String, dynamic>.from(
      await widget.api.call('get_trexven_financial_summary', {
            'p_business_id': widget.api.businessId,
            'p_start': day['starts_at'],
            'p_end': day['ends_at'],
          })
          as Map,
    );
    return {...totals, 'day': day['local_date'], 'timezone': day['timezone']};
  }

  Future<void> execute(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
      if (mounted)
        setState(() {
          message = 'Server confirmed the operation.';
          load();
        });
    } catch (e) {
      if (mounted) setState(() => message = 'Operation is not confirmed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Map<String, String>?> form(
    String title,
    List<String> fields, {
    bool confirm = false,
  }) async {
    final controls = {for (final name in fields) name: TextEditingController()};
    var checked = false;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in controls.entries)
                  TextField(
                    controller: entry.value,
                    decoration: InputDecoration(labelText: entry.key),
                  ),
                if (confirm)
                  CheckboxListTile(
                    value: checked,
                    onChanged: (v) => update(() => checked = v ?? false),
                    title: const Text(
                      'I verified the actual cash, bank-account or external-terminal outcome. A screenshot alone is insufficient.',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: confirm && !checked
                  ? null
                  : () => Navigator.pop(
                      context,
                      controls.map((k, v) => MapEntry(k, v.text.trim())),
                    ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    for (final c in controls.values) {
      c.dispose();
    }
    return result;
  }

  Future<void> decide(Map<String, dynamic> a, bool approve) async {
    final input = await form(
      approve ? 'Approve this exact credit sale' : 'Reject credit sale',
      widget.owner && approve
          ? ['Over-limit exception reason (leave blank for ordinary approval)']
          : [],
    );
    if (input == null) return;
    await execute(() async {
      await widget.api.call('decide_trexven_credit_approval', {
        'p_approval_id': a['id'],
        'p_approve': approve,
        'p_over_limit_reason':
            input.values.isEmpty || input.values.first.isEmpty
            ? null
            : input.values.first,
      });
    });
  }

  Future<void> repay(Map<String, dynamic> a) async {
    final input = await form('Record a confirmed repayment', [
      'Amount',
      'Method: cash / bank_transfer / card',
      'Verified external reference (noncash)',
    ], confirm: true);
    if (input == null) return;
    final shift =
        input['Method: cash / bank_transfer / card'] == 'cash' && mounted
        ? await chooseCashShift(context, widget.api)
        : null;
    final request = widget.api.requestId();
    await execute(() async {
      await widget.api.call('repay_trexven_credit', {
        'p_sale_id': a['sale_id'],
        'p_request_id': request,
        'p_amount': OperationsClient.amount(
          OperationsClient.moneyCents(input['Amount']!),
        ),
        'p_method': input['Method: cash / bank_transfer / card'],
        'p_confirmed': true,
        'p_evidence': input['Verified external reference (noncash)'],
        'p_shift_id': shift,
      });
    });
  }

  Future<void> inspect(Map<String, dynamic> r) async {
    final items =
        (await widget.api.call('get_trexven_return_inspection_items', {
                  'p_return_id': r['id'],
                })
                as List)
            .map((i) => Map<String, dynamic>.from(i as Map))
            .toList();
    if (!mounted) return;
    final fields = items
        .map(
          (i) =>
              '${i['name']} (${i['quantity']}): sellable / damaged / defective',
        )
        .toList();
    final input = await form('Inspect every returned item', fields);
    if (input == null) return;
    await execute(() async {
      await widget.api.call('inspect_trexven_return', {
        'p_return_id': r['id'],
        'p_request_id': widget.api.requestId(),
        'p_conditions': [
          for (var i = 0; i < items.length; i++)
            {
              'sale_item_id': items[i]['sale_item_id'],
              'condition': input[fields[i]],
            },
        ],
      });
    });
  }

  Future<void> approveReturn(Map<String, dynamic> r) async {
    final input =
        await form('Approve inspected return; debt is reduced first', [
          'Method: cash / bank_transfer / card',
          'Verified external refund reference (noncash)',
        ], confirm: true);
    if (input == null) return;
    final shift =
        input['Method: cash / bank_transfer / card'] == 'cash' && mounted
        ? await chooseCashShift(context, widget.api)
        : null;
    await execute(() async {
      await widget.api.call('approve_trexven_return', {
        'p_return_id': r['id'],
        'p_request_id': widget.api.requestId(),
        'p_method': input['Method: cash / bank_transfer / card'],
        'p_confirmed': true,
        'p_evidence': input['Verified external refund reference (noncash)'],
        'p_shift_id': shift,
      });
    });
  }

  Future<void> requestReturn() async {
    final sales = await widget.api.list('sales');
    if (!mounted) return;
    final sale = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select the original receipt'),
        children: [
          for (final s in sales.where((s) => s['status'] == 'completed'))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s),
              child: Text(
                '${s['created_at']} · ${s['total']} · ${s['payment_kind'] ?? s['payment_method']}',
              ),
            ),
        ],
      ),
    );
    if (sale == null) return;
    final items = await widget.api.list(
      'sale_items',
      foreignKey: 'sale_id',
      foreignId: sale['id'] as String,
    );
    final products = await widget.api.list('products');
    if (!mounted) return;
    final item = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select the returned item'),
        children: [
          for (final i in items)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text(
                '${products.where((p) => p['id'] == i['product_id']).firstOrNull?['name'] ?? 'Original product'} · sold ${i['quantity']}',
              ),
            ),
        ],
      ),
    );
    if (item == null) return;
    final input = await form('Return original item', ['Quantity', 'Reason']);
    if (input == null) return;
    await execute(() async {
      await widget.api.call('request_trexven_return', {
        'p_sale_id': sale['id'],
        'p_request_id': widget.api.requestId(),
        'p_items': [
          {'sale_item_id': item['id'], 'quantity': input['Quantity']},
        ],
        'p_reason': input['Reason'],
      });
    });
  }

  Future<void> history(
    Map<String, dynamic> a,
    List<Map<String, dynamic>> entries,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('${a['debtor_name']} · payment history'),
        children: [
          for (final e in entries.where((e) => e['sale_id'] == a['sale_id']))
            ListTile(
              title: Text(
                '${e['kind']} · ${e['amount']} · ${e['method'] ?? 'Debt adjustment'}',
              ),
              subtitle: Text(
                '${e['created_at']} · ${e['reason'] ?? e['evidence'] ?? ''}',
              ),
              trailing: widget.owner && e['kind'] == 'repayment'
                  ? TextButton(
                      child: const Text('Reverse'),
                      onPressed: () {
                        Navigator.pop(context);
                        reverse(e);
                      },
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  Future<void> reverse(Map<String, dynamic> e) async {
    final input = await form('Confirm repayment reversal', [
      'Reason',
      'Verified external reference (noncash)',
    ], confirm: true);
    if (input == null) return;
    final shift = e['method'] == 'cash' && mounted
        ? await chooseCashShift(context, widget.api)
        : null;
    await execute(() async {
      await widget.api.call('reverse_trexven_credit_repayment', {
        'p_entry_id': e['id'],
        'p_request_id': widget.api.requestId(),
        'p_reason': input['Reason'],
        'p_confirmed': true,
        'p_evidence': input['Verified external reference (noncash)'],
        'p_shift_id': shift,
      });
    });
  }

  Future<void> limit() async {
    final input = await form('Set business credit exposure limit', ['Amount']);
    if (input == null) return;
    await execute(() async {
      await widget.api.call('set_trexven_credit_limit', {
        'p_business_id': widget.api.businessId,
        'p_amount': OperationsClient.amount(
          OperationsClient.moneyCents(input['Amount']!, allowZero: true),
        ),
      });
    });
  }

  Future<void> discard() async {
    final input = await form(
      'Discard only an uncommitted operation with no money collected or returned',
      [],
      confirm: true,
    );
    if (input == null) return;
    await execute(() => widget.api.discardUncommitted(noMoneyMoved: true));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Credit and returns'),
      actions: [
        IconButton(
          onPressed: busy ? null : () => setState(load),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<List<Map<String, dynamic>>>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Operational data is unavailable. This backend may not yet have the new migration.',
                ),
                TextButton(
                  onPressed: () => setState(load),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        final rows = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (message != null) Text(message!),
            if (busy) const LinearProgressIndicator(),
            if (summary != null)
              FutureBuilder<Map<String, dynamic>>(
                future: summary,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Text(
                      'Financial totals unavailable. No estimated totals shown.',
                    );
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final t = snapshot.data!;
                  return Text(
                    '${t['day']} · ${t['timezone']}\nGross sales ${t['gross_sales']} · net collected ${t['net_collected']}\nOutstanding debt ${t['receivables']} · overdue ${t['overdue']} · refunds ${t['refunds']}',
                  );
                },
              ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : requestReturn,
                  child: const Text('Request return'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => execute(() async {
                          await widget.api.recoverPending();
                        }),
                  child: const Text('Recover interrupted operation'),
                ),
                TextButton(
                  onPressed: busy ? null : discard,
                  child: const Text('Discard uncommitted intent'),
                ),
                if (widget.owner)
                  OutlinedButton(
                    onPressed: busy ? null : limit,
                    child: const Text('Credit limit'),
                  ),
              ],
            ),
            const Text('Credit approvals'),
            for (final a in rows[0])
              ListTile(
                title: Text(
                  '${((a['payload'] as Map)['credit'] as Map)['debtor_name']} · ${((a['payload'] as Map)['credit'] as Map)['contact']}',
                ),
                subtitle: Text(
                  '${a['status']} · total ${(a['payload'] as Map)['total']}',
                ),
                trailing: a['status'] == 'pending'
                    ? Wrap(
                        children: [
                          TextButton(
                            onPressed: busy ? null : () => decide(a, true),
                            child: const Text('Approve'),
                          ),
                          TextButton(
                            onPressed: busy ? null : () => decide(a, false),
                            child: const Text('Reject'),
                          ),
                        ],
                      )
                    : null,
              ),
            const Text('Customer balances'),
            for (final a in rows[1])
              ListTile(
                title: Text('${a['debtor_name']} · ${a['contact']}'),
                subtitle: Text(
                  'Outstanding ${a['outstanding']} · due ${a['due_date']} · sale ${a['sale_id']}',
                ),
                trailing: IconButton(
                  tooltip: 'Payment history',
                  icon: const Icon(Icons.history),
                  onPressed: busy ? null : () => history(a, rows[3]),
                ),
                onTap: busy ? null : () => repay(a),
              ),
            const Text('Returns and refunds'),
            for (final r in rows[2])
              ListTile(
                title: Text('${r['reason']}'),
                subtitle: Text(
                  '${r['status']} · sale ${r['sale_id']} · refund ${r['refund_amount'] ?? "—"}',
                ),
                onTap: busy
                    ? null
                    : r['status'] == 'requested'
                    ? () => inspect(r)
                    : r['status'] == 'inspected'
                    ? () => approveReturn(r)
                    : null,
              ),
            const Text('Offline cash reconciliation'),
            for (final r in rows[4])
              ListTile(
                title: Text(
                  r['reviewed_by'] == null ? 'Requires review' : 'Reviewed',
                ),
                subtitle: Text(
                  '${r['occurred_at']} · ${r['discrepancies']}\n${r['review_reason'] ?? ''}',
                ),
                onTap: busy || r['reviewed_by'] != null
                    ? null
                    : () async {
                        final input = await form(
                          'Explain the reviewed discrepancy',
                          ['Review reason'],
                        );
                        if (input == null) return;
                        await execute(() async {
                          await widget.api
                              .call('review_trexven_offline_reconciliation', {
                                'p_reconciliation_id': r['id'],
                                'p_request_id': widget.api.requestId(),
                                'p_reason': input['Review reason'],
                              });
                        });
                      },
              ),
          ],
        );
      },
    ),
  );
}
