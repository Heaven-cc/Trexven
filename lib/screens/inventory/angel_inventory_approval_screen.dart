import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'angel_scan_review_screen.dart';
import '../../services/angel_scan_client.dart';

class AngelInventoryApprovalScreen extends StatefulWidget {
  final SupabaseClient client;
  final String businessId, requestId;
  const AngelInventoryApprovalScreen({
    super.key,
    required this.client,
    required this.businessId,
    required this.requestId,
  });
  @override
  State<AngelInventoryApprovalScreen> createState() =>
      _AngelInventoryApprovalScreenState();
}

class _AngelInventoryApprovalScreenState
    extends State<AngelInventoryApprovalScreen> {
  late Future<Map<String, dynamic>> _request;
  late final String? _user;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _user = widget.client.auth.currentUser?.id;
    _request = _load();
  }

  void _check() {
    if (_user == null || widget.client.auth.currentUser?.id != _user)
      throw StateError('Account changed. Reopen the request.');
  }

  Future<Map<String, dynamic>> _load() async {
    _check();
    final result = await widget.client.rpc(
      'get_angel_inventory_request',
      params: {
        'p_business_id': widget.businessId,
        'p_request_id': widget.requestId,
      },
    );
    _check();
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> _decide(bool approve) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          approve ? 'Approve and post inventory?' : 'Reject this request?',
        ),
        content: Text(
          approve
              ? 'The reviewed quantities will be posted atomically. Existing selling prices stay unchanged.'
              : 'This request will be rejected. No stock changes will be made.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(approve ? 'Approve and post' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _check();
      final result = await widget.client.rpc(
        'decide_angel_inventory_approval',
        params: {
          'p_business_id': widget.businessId,
          'p_request_id': widget.requestId,
          'p_approve': approve,
        },
      );
      _check();
      if (mounted)
        setState(() {
          _request = _load();
          _error = (result as Map)['application_error'] as String?;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Decision was not confirmed. Refresh this request before retrying.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Angel inventory approval'),
      actions: [
        IconButton(
          tooltip: 'Refresh request',
          onPressed: _busy ? null : () => setState(() => _request = _load()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(
            child: Text('Request unavailable. Verify current owner access.'),
          );
        if (!snapshot.hasData)
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          );
        final row = snapshot.data!;
        final pending = row['status'] == 'pending';
        final retry =
            row['status'] == 'approved' &&
            row['application_status'] == 'failed';
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${row['employee_name']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SelectableText(
              'Request: ${row['id']}\nRequested: ${row['created_at']}\nBranch: ${row['branch_id'] ?? 'Business inventory'}',
            ),
            if (row['document_metadata'] != null)
              Text('Document details: ${row['document_metadata']}'),
            const SizedBox(height: 12),
            Text(
              'Decision: ${row['status']} • Stock: ${row['application_status']}',
            ),
            if (row['applied_at'] != null) Text('Posted: ${row['applied_at']}'),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null || row['application_error'] != null)
              Text(
                '${_error ?? row['application_error']}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            for (final item in row['items'] as List)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${item['name']} × ${item['quantity']} ${item['unit'] ?? 'piece'}',
                ),
                subtitle: Text(
                  '${item['brand'] ?? ''} ${item['sku'] ?? ''} ${item['barcode'] ?? ''}\n'
                  '${item['product_id'] == null ? 'New product' : 'Restock product ${item['product_id']}'}\n'
                  'Purchase unit cost: ${item['cost'] ?? 'Not provided'} • Line total: ${item['line_total'] ?? 'Not provided'}\n'
                  '${item['product_id'] == null ? 'New selling price: ${item['selling_price'] ?? 'Pending (not sellable)'}' : 'Existing selling price preserved: ${item['current_selling_price'] ?? 'Not set'}'}\n'
                  '${item['evidence'] ?? ''}',
                ),
              ),
            if (pending || retry)
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AngelScanReviewScreen(
                              api: AngelScanClient(
                                widget.client,
                                businessId: widget.businessId,
                                branchId: row['branch_id'] as String?,
                                inventoryMode: true,
                              ),
                              owner: true,
                              existingRequestId: widget.requestId,
                              initialItems: (row['items'] as List)
                                  .map(
                                    (i) => Map<String, dynamic>.from(i as Map),
                                  )
                                  .toList(),
                            ),
                          ),
                        );
                        if (mounted) setState(() => _request = _load());
                      },
                child: const Text('Correct reviewed products'),
              ),
            if (pending || retry)
              FilledButton(
                onPressed: _busy ? null : () => _decide(true),
                child: Text(retry ? 'Retry stock posting' : 'Approve and post'),
              ),
            if (pending)
              OutlinedButton(
                onPressed: _busy ? null : () => _decide(false),
                child: const Text('Reject'),
              ),
            const SizedBox(height: 12),
            Text(
              'Audit history',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final event in row['history'] as List? ?? [])
              Text('${event['at']} · ${event['action']}'),
            const SizedBox(height: 16),
            const Center(child: Text('Powered by TREXVEN')),
          ],
        );
      },
    ),
  );
}
