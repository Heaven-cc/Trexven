import 'package:flutter/material.dart';
import 'operations_client.dart';

/// Cash context is chosen before payment confirmation and retained in its journal.
Future<String?> chooseCashShift(
  BuildContext context,
  OperationsClient api, {
  bool allowNoDrawer = false,
  Map<String, dynamic>? cashContext,
}) async {
  final current = cashContext ?? await api.cashContext();
  if (current['configured'] != true) return null;
  final shifts = (current['shifts'] as List).map(
    (r) => Map<String, dynamic>.from(r as Map),
  );
  if (!context.mounted) throw StateError('Cash drawer selection interrupted.');
  final shift = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Select your joined cash drawer'),
      children: [
        for (final s in shifts.where(
          (s) =>
              s['status'] == 'open' &&
              s['joined'] == true &&
              s['register_active'] == true,
        ))
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, s['id'] as String),
            child: Text('${s['register_name']} · shared drawer'),
          ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Open or join your assigned register in Cash shifts first. Server authorization checks membership.',
          ),
        ),
        if (allowNoDrawer)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue without cash payment'),
          ),
      ],
    ),
  );
  if (shift == null && !allowNoDrawer)
    throw StateError('Cash drawer selection cancelled.');
  return shift;
}

class CashShiftScreen extends StatefulWidget {
  final OperationsClient api;
  final bool owner;
  final bool reviewer;
  const CashShiftScreen({
    super.key,
    required this.api,
    required this.owner,
    this.reviewer = false,
  });
  @override
  State<CashShiftScreen> createState() => _CashShiftScreenState();
}

class _CashShiftScreenState extends State<CashShiftScreen> {
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
      widget.api.list('cash_registers'),
      widget.api.list('cash_shifts'),
      widget.api.list('cash_events'),
      widget.api.list('cash_handovers'),
    ]);
  }

  Future<Map<String, String>?> fields(
    String title,
    List<String> names, {
    bool confirm = false,
  }) async {
    final controls = {for (final n in names) n: TextEditingController()};
    var checked = false;
    String? formError;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in controls.entries)
                  TextField(
                    controller: c.value,
                    decoration: InputDecoration(labelText: c.key),
                  ),
                if (confirm)
                  CheckboxListTile(
                    value: checked,
                    onChanged: (v) => update(() => checked = v ?? false),
                    title: const Text(
                      'The drawer has been physically counted. All employees have checked pending cash requests; late synchronization will require reconciliation.',
                    ),
                  ),
                if (formError != null)
                  Text(
                    formError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
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
                  : () {
                      try {
                        for (final entry in controls.entries) {
                          if (entry.key == 'Amount' ||
                              entry.key.startsWith('Actual '))
                            OperationsClient.moneyCents(
                              entry.value.text,
                              allowZero: entry.key != 'Amount',
                            );
                        }
                        Navigator.pop(
                          context,
                          controls.map((k, v) => MapEntry(k, v.text.trim())),
                        );
                      } catch (e) {
                        update(() => formError = '$e');
                      }
                    },
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
          message = 'Server confirmed.';
          load();
        });
    } catch (e) {
      if (mounted) setState(() => message = 'Not confirmed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> configure() async {
    final members = await widget.api.list('business_members');
    if (!mounted) return;
    final selected = <String>{};
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Named shared register'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Register name'),
                ),
                for (final m in members.where((m) => m['status'] == 'active'))
                  CheckboxListTile(
                    title: Text('${m['full_name']}'),
                    value: selected.contains(m['id']),
                    onChanged: (v) => update(() {
                      if (v == true) {
                        selected.add(m['id'] as String);
                      } else {
                        selected.remove(m['id']);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save assignments'),
            ),
          ],
        ),
      ),
    );
    final text = name.text.trim();
    name.dispose();
    if (ok != true) return;
    await run('configure_trexven_register', {
      'p_business_id': widget.api.businessId,
      'p_name': text,
      'p_members': selected.toList(),
    });
  }

  Future<void> open(Map<String, dynamic> r) async {
    final f = await fields('Open ${r['name']}', ['Actual opening cash']);
    if (f == null) return;
    await run('open_trexven_cash_shift', {
      'p_register_id': r['id'],
      'p_opening': OperationsClient.amount(
        OperationsClient.moneyCents(f['Actual opening cash']!, allowZero: true),
      ),
    });
  }

  Future<void> move(Map<String, dynamic> s, String kind) async {
    final f = await fields(kind, ['Amount', 'Reason']);
    if (f == null) return;
    await run('move_trexven_cash', {
      'p_shift_id': s['id'],
      'p_amount': OperationsClient.amount(
        OperationsClient.moneyCents(f['Amount']!),
      ),
      'p_kind': kind,
      'p_reason': f['Reason'],
    });
  }

  Future<void> close(Map<String, dynamic> s) async {
    final f = await fields('Close the shared drawer once', [
      'Actual counted cash',
      'Discrepancy reason',
    ], confirm: true);
    if (f == null) return;
    await run('close_trexven_cash_shift', {
      'p_shift_id': s['id'],
      'p_counted': OperationsClient.amount(
        OperationsClient.moneyCents(f['Actual counted cash']!, allowZero: true),
      ),
      'p_reason': f['Discrepancy reason'],
      'p_no_pending_cash': true,
    });
  }

  Future<void> recoverShift(Map<String, dynamic> s) async {
    final f = await fields(
      'Owner or authorized manager recovery: retain all pending cash',
      ['Actual counted cash', 'Recovery reason'],
      confirm: true,
    );
    if (f == null) return;
    await run('force_close_trexven_cash_shift', {
      'p_shift_id': s['id'],
      'p_counted': OperationsClient.amount(
        OperationsClient.moneyCents(f['Actual counted cash']!, allowZero: true),
      ),
      'p_reason': f['Recovery reason'],
      'p_review_pending_cash': true,
    });
  }

  Future<void> review(Map<String, dynamic> s) async {
    final f = await fields('Review closure and late events', ['Review reason']);
    if (f == null) return;
    await run('review_trexven_cash_shift', {
      'p_shift_id': s['id'],
      'p_reason': f['Review reason'],
    });
  }

  Future<void> handover(Map<String, dynamic> s) async {
    final members = await widget.api.list('business_members');
    if (!mounted) return;
    final member = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Incoming employee'),
        children: [
          for (final m in members.where((m) => m['status'] == 'active'))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, m),
              child: Text('${m['full_name']}'),
            ),
        ],
      ),
    );
    if (member == null) return;
    final f = await fields('Request shared drawer handover', [
      'Actual counted cash',
      'Reason',
    ]);
    if (f == null) return;
    await run('request_trexven_cash_handover', {
      'p_shift_id': s['id'],
      'p_incoming_member': member['id'],
      'p_counted': OperationsClient.amount(
        OperationsClient.moneyCents(f['Actual counted cash']!, allowZero: true),
      ),
      'p_reason': f['Reason'],
    });
  }

  Future<void> accept(Map<String, dynamic> h) async {
    final f = await fields('Incoming employee handover confirmation', [
      'Actual counted cash',
    ], confirm: true);
    if (f == null) return;
    await run('confirm_trexven_cash_handover', {
      'p_handover_id': h['id'],
      'p_accept': true,
      'p_counted': OperationsClient.amount(
        OperationsClient.moneyCents(f['Actual counted cash']!, allowZero: true),
      ),
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Shared cash drawers'),
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
              'Cash drawer contracts unavailable. Retry after the backend is ready.',
            ),
          );
        final rows = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (message != null) Text(message!),
            if (busy) const LinearProgressIndicator(),
            if (widget.owner)
              OutlinedButton(
                onPressed: busy ? null : configure,
                child: const Text('Configure register assignments'),
              ),
            for (final r in rows[0])
              ListTile(
                title: Text('${r['name']}'),
                trailing: TextButton(
                  onPressed: busy ? null : () => open(r),
                  child: const Text('Open drawer'),
                ),
              ),
            const Text('Shift history'),
            for (final s in rows[1]) ...[
              ListTile(
                title: Text(
                  '${rows[0].where((r) => r['id'] == s['register_id']).firstOrNull?['name'] ?? 'Register'} · ${s['status']}',
                ),
                subtitle: Text(
                  'Opening ${s['opening_amount']} · expected now ${s['expected_current']}\nOriginal close ${s['expected_at_close'] ?? '—'} · counted ${s['counted_amount'] ?? '—'} · difference ${s['difference_at_close'] ?? '—'} · ${s['review_status']}',
                ),
              ),
              Wrap(
                spacing: 8,
                children: s['status'] == 'open'
                    ? [
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run('join_trexven_cash_shift', {
                                  'p_shift_id': s['id'],
                                }),
                          child: const Text('Join shared drawer'),
                        ),
                        for (final kind in ['cash_in', 'cash_out'])
                          TextButton(
                            onPressed: busy ? null : () => move(s, kind),
                            child: Text(kind),
                          ),
                        TextButton(
                          onPressed: busy ? null : () => handover(s),
                          child: const Text('Handover'),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => close(s),
                          child: const Text('Close'),
                        ),
                        if (widget.owner || widget.reviewer)
                          TextButton(
                            onPressed: busy ? null : () => recoverShift(s),
                            child: const Text('Recover an unclosed drawer'),
                          ),
                      ]
                    : [
                        TextButton(
                          onPressed: busy ? null : () => review(s),
                          child: const Text('Review reconciliation'),
                        ),
                      ],
              ),
              for (final e in rows[2].where((e) => e['shift_id'] == s['id']))
                ListTile(
                  title: Text(
                    '${e['kind']} · ${e['amount']}${e['late'] == true ? ' · late sync' : ''}',
                  ),
                  subtitle: Text('${e['created_at']} · ${e['reason'] ?? ''}'),
                ),
            ],
            for (final h in rows[3])
              ListTile(
                title: Text(
                  'Handover · ${h['status']} · counted ${h['counted']}',
                ),
                subtitle: Text('${h['reason']}'),
                onTap: busy || h['status'] != 'pending'
                    ? null
                    : () => accept(h),
              ),
          ],
        );
      },
    ),
  );
}
