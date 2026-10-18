import 'package:flutter/material.dart';
import 'operations_client.dart';

class InventoryOperationsScreen extends StatefulWidget {
  final OperationsClient api;
  final Future<String?> Function(BuildContext)? scanBarcode;
  const InventoryOperationsScreen({
    super.key,
    required this.api,
    this.scanBarcode,
  });
  @override
  State<InventoryOperationsScreen> createState() =>
      _InventoryOperationsScreenState();
}

class _InventoryOperationsScreenState extends State<InventoryOperationsScreen> {
  late Future<List<List<Map<String, dynamic>>>> data;
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    data = Future.wait([
      widget.api.list('products'),
      widget.api.list('stocktake_sessions'),
      widget.api.list('stock_condition_entries'),
      widget.api.list('inventory_reconciliation_reviews'),
      widget.api.list('supplier_stock_returns'),
    ]);
  }

  Future<Map<String, String>?> fields(String title, List<String> names) async {
    final controls = {for (final n in names) n: TextEditingController()};
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in controls.entries)
                TextField(
                  controller: c.value,
                  maxLines: c.key == 'Barcode counts' ? 6 : 1,
                  decoration: InputDecoration(labelText: c.key),
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
            onPressed: () => Navigator.pop(
              context,
              controls.map((k, v) => MapEntry(k, v.text.trim())),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    for (final c in controls.values) {
      c.dispose();
    }
    return result;
  }

  Future<void> run(String rpc, Map<String, dynamic> args) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.api.call(rpc, {
        'p_request_id': widget.api.requestId(),
        ...args,
      });
      if (mounted)
        setState(() {
          message = 'Server confirmed the operation.';
          load();
        });
    } catch (e) {
      if (mounted) setState(() => message = 'Not confirmed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> start() async {
    final f = await fields('Start online stocktaking', ['Count name']);
    if (f == null) return;
    await run('start_trexven_stocktake', {
      'p_business_id': widget.api.businessId,
      'p_name': f['Count name'],
    });
  }

  Future<void> session(
    Map<String, dynamic> s,
    List<Map<String, dynamic>> products,
  ) async {
    final counts = await widget.api.list(
      'stocktake_counts',
      foreignKey: 'session_id',
      foreignId: s['id'] as String,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('${s['name']} · ${s['status']}'),
        children: [
          for (final c in counts)
            ListTile(
              title: Text(
                '${products.where((p) => p['id'] == c['product_id']).firstOrNull?['name'] ?? 'Product'}',
              ),
              subtitle: Text(
                'Count ${c['counted'] ?? 'not entered'} · stock at count ${c['expected_at_count'] ?? '—'} · adjustment ${c['applied_delta'] ?? '—'}',
              ),
              onTap: s['status'] != 'open'
                  ? null
                  : () {
                      Navigator.pop(context);
                      count(s, c);
                    },
              onLongPress: s['status'] != 'open'
                  ? null
                  : () {
                      Navigator.pop(context);
                      reassign(s, c);
                    },
            ),
          if (s['status'] == 'open')
            if (widget.scanBarcode != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  scannedCount(s, counts, products);
                },
                child: const Text('Scan a product to count'),
              ),
          if (s['status'] == 'open')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                bulkCount(s, counts, products);
              },
              child: const Text('Enter counts by barcode'),
            ),
          if (s['status'] == 'open')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                run('submit_trexven_stocktake', {'p_session_id': s['id']});
              },
              child: const Text('Submit complete count for review'),
            ),
          if (s['status'] == 'review')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                approve(s);
              },
              child: const Text('Approve reconciliation'),
            ),
          if (s['status'] == 'review')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                manage(s, 'reopen');
              },
              child: const Text('Reopen for recount'),
            ),
          if (s['status'] == 'open' || s['status'] == 'review')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                manage(s, 'cancel');
              },
              child: const Text('Cancel count with reason'),
            ),
        ],
      ),
    );
  }

  Future<void> count(Map<String, dynamic> s, Map<String, dynamic> c) async {
    final f = await fields('Physical count', ['Quantity']);
    if (f == null) return;
    await run('count_trexven_stock', {
      'p_session_id': s['id'],
      'p_counts': [
        {
          'product_id': c['product_id'],
          'version': c['version'],
          'quantity': f['Quantity'],
        },
      ],
    });
  }

  Future<void> scannedCount(
    Map<String, dynamic> s,
    List<Map<String, dynamic>> counts,
    List<Map<String, dynamic>> products,
  ) async {
    try {
      final barcode = await widget.scanBarcode!(context);
      if (barcode == null) return;
      final matches = products.where((p) => p['barcode'] == barcode).toList();
      if (matches.length != 1)
        throw StateError('Barcode is missing or ambiguous.');
      final matchesInCount = counts
          .where((c) => c['product_id'] == matches.single['id'])
          .toList();
      if (matchesInCount.length != 1)
        throw StateError('This product is not in the selected count session.');
      await count(s, matchesInCount.single);
    } catch (e) {
      if (mounted) setState(() => message = 'Count not submitted: $e');
    }
  }

  Future<void> bulkCount(
    Map<String, dynamic> s,
    List<Map<String, dynamic>> counts,
    List<Map<String, dynamic>> products,
  ) async {
    final f = await fields('Barcode counts: one barcode,quantity per line', [
      'Barcode counts',
    ]);
    if (f == null) return;
    try {
      final lines = <Map<String, dynamic>>[];
      for (final line
          in f['Barcode counts']!
              .split('\n')
              .where((l) => l.trim().isNotEmpty)) {
        final parts = line.split(',');
        if (parts.length != 2)
          throw const FormatException('Use barcode,quantity.');
        final matches = products
            .where((p) => p['barcode'] == parts[0].trim())
            .toList();
        if (matches.length != 1)
          throw const FormatException('Barcode is missing or ambiguous.');
        final c = counts
            .where((c) => c['product_id'] == matches.single['id'])
            .first;
        lines.add({
          'product_id': c['product_id'],
          'version': c['version'],
          'quantity': parts[1].trim(),
        });
      }
      await run('count_trexven_stock', {
        'p_session_id': s['id'],
        'p_counts': lines,
      });
    } catch (e) {
      if (mounted) setState(() => message = 'Counts were not submitted: $e');
    }
  }

  Future<void> approve(Map<String, dynamic> s) async {
    final f = await fields(
      'Approve physical discrepancy; later movements are retained',
      ['Reason'],
    );
    if (f == null) return;
    await run('approve_trexven_stocktake', {
      'p_session_id': s['id'],
      'p_reason': f['Reason'],
    });
  }

  Future<void> manage(Map<String, dynamic> s, String action) async {
    final f = await fields('$action count session', ['Reason']);
    if (f == null) return;
    await run('manage_trexven_stocktake', {
      'p_session_id': s['id'],
      'p_action': action,
      'p_reason': f['Reason'],
    });
  }

  Future<void> reassign(
    Map<String, dynamic> s,
    Map<String, dynamic> count,
  ) async {
    final members = await widget.api.list('business_members');
    if (!mounted) return;
    final user = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Reassign this count to an active employee'),
        children: [
          for (final m in members.where((m) => m['status'] == 'active'))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, m['user_id'] as String),
              child: Text('${m['full_name'] ?? m['role']}'),
            ),
        ],
      ),
    );
    if (user == null || !mounted) return;
    final f = await fields('Explain count reassignment', ['Reason']);
    if (f == null) return;
    await run('manage_trexven_stocktake', {
      'p_session_id': s['id'],
      'p_action': 'reassign',
      'p_product_id': count['product_id'],
      'p_counter_id': user,
      'p_reason': f['Reason'],
    });
  }

  Future<Map<String, dynamic>?> product(
    List<Map<String, dynamic>> products,
  ) async => showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Select product'),
      children: [
        for (final p in products)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, p),
            child: Text(
              '${p['name']} · available ${p['quantity']} ${p['unit']}',
            ),
          ),
      ],
    ),
  );
  Future<void> classify(List<Map<String, dynamic>> products) async {
    final p = await product(products);
    if (p == null) return;
    final f = await fields('Classify ${p['name']}', [
      'Quantity',
      'Condition: damaged / expired / defective / lost',
      'Reason',
    ]);
    if (f == null) return;
    await run('classify_trexven_stock', {
      'p_business_id': widget.api.businessId,
      'p_product_id': p['id'],
      'p_quantity': f['Quantity'],
      'p_condition': f['Condition: damaged / expired / defective / lost'],
      'p_reason': f['Reason'],
    });
  }

  Future<void> resolve(
    List<Map<String, dynamic>> products,
    String action,
  ) async {
    final p = await product(products);
    if (p == null) return;
    final f = await fields(
      action == 'supplier'
          ? 'Dispatch nonsellable supplier return'
          : '$action inspected stock',
      [
        'Quantity',
        'Condition: damaged / expired / defective',
        if (action == 'supplier') 'Supplier name',
        'Inspection and reason',
      ],
    );
    if (f == null) return;
    await run(
      action == 'supplier'
          ? 'dispatch_trexven_supplier_return'
          : 'resolve_trexven_condition_stock',
      {
        'p_business_id': widget.api.businessId,
        'p_product_id': p['id'],
        'p_quantity': f['Quantity'],
        'p_condition': f['Condition: damaged / expired / defective'],
        'p_reason': f['Inspection and reason'],
        if (action == 'supplier')
          'p_supplier_name': f['Supplier name']
        else
          'p_action': action,
      },
    );
  }

  Future<void> review(Map<String, dynamic> r) async {
    final f = await fields(
      'Review late offline movement; closed counts remain unchanged',
      ['Reconciliation reason'],
    );
    if (f == null) return;
    await run('review_trexven_inventory_discrepancy', {
      'p_review_id': r['id'],
      'p_reason': f['Reconciliation reason'],
    });
  }

  Future<void> supplier(Map<String, dynamic> r) async {
    final f = await fields('Supplier acknowledgment: ${r['supplier_name']}', [
      'Accepted quantity',
      'Returned nonsellable quantity',
      'Acknowledgment and discrepancy reason',
    ]);
    if (f == null) return;
    await run('acknowledge_trexven_supplier_return', {
      'p_return_id': r['id'],
      'p_accepted': f['Accepted quantity'],
      'p_returned': f['Returned nonsellable quantity'],
      'p_reason': f['Acknowledgment and discrepancy reason'],
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Inventory operations'),
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
          return const Center(
            child: Text(
              'Inventory operations unavailable. Retry after the backend is ready.',
            ),
          );
        final rows = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (message != null) Text(message!),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: busy ? null : start,
                  child: const Text('Start stocktake'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => classify(rows[0]),
                  child: const Text('Damaged, expired or lost'),
                ),
                for (final action in ['restore', 'writeoff', 'supplier'])
                  OutlinedButton(
                    onPressed: busy ? null : () => resolve(rows[0], action),
                    child: Text(action),
                  ),
              ],
            ),
            const Text('Count sessions'),
            for (final s in rows[1])
              ListTile(
                title: Text('${s['name']}'),
                subtitle: Text('${s['status']}'),
                onTap: busy ? null : () => session(s, rows[0]),
              ),
            const Text('Nonsellable stock ledger'),
            for (final e in rows[2])
              ListTile(
                title: Text(
                  '${rows[0].where((p) => p['id'] == e['product_id']).firstOrNull?['name'] ?? 'Product'} · ${e['condition']} · ${e['quantity']}',
                ),
                subtitle: Text('${e['kind']} · ${e['reason']}'),
              ),
            const Text('Late offline reconciliation'),
            for (final r in rows[3])
              ListTile(
                title: Text('Late cash sale · ${r['quantity']}'),
                subtitle: Text('${r['status']} · ${r['reason'] ?? ''}'),
                onTap: busy || r['status'] != 'pending'
                    ? null
                    : () => review(r),
              ),
            const Text('Supplier returns'),
            for (final r in rows[4])
              ListTile(
                title: Text('${r['supplier_name']} · ${r['quantity']}'),
                subtitle: Text('${r['status']}'),
                onTap: busy || r['status'] != 'dispatched'
                    ? null
                    : () => supplier(r),
              ),
            const Text('Branch transfers remain disabled.'),
          ],
        );
      },
    ),
  );
}
