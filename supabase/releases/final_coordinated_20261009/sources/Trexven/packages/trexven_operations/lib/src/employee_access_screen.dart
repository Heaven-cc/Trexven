import 'package:flutter/material.dart';
import 'operations_client.dart';

/// Uses the existing employee RPCs. Role labels never authorize a write.
class EmployeeAccessScreen extends StatefulWidget {
  final OperationsClient api;
  const EmployeeAccessScreen({super.key, required this.api});
  @override
  State<EmployeeAccessScreen> createState() => _EmployeeAccessScreenState();
}

class _EmployeeAccessScreenState extends State<EmployeeAccessScreen> {
  late Future<List<Map<String, dynamic>>> rows;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    rows = widget.api.list('employees');
  }

  Future<void> permissions(Map<String, dynamic> employee) async {
    final client = widget.api.client;
    final user = client.auth.currentUser?.id;
    if (user == null) return;
    // Verify actual ownership before exposing permission controls. The existing
    // RPC independently verifies ownership and current employee role on each write.
    final owned = await client
        .from('businesses')
        .select('id')
        .eq('id', widget.api.businessId)
        .eq('owner_id', user)
        .maybeSingle();
    if (!mounted) return;
    if (owned == null)
      throw StateError('Only the verified owner can grant permissions.');
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            _PermissionOverrides(api: widget.api, employee: employee),
      ),
    );
  }

  Future<void> act(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Access change was not confirmed. Refresh and ask the owner to review.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Employees & permissions'),
      actions: [
        IconButton(
          tooltip: 'Refresh employees',
          onPressed: busy
              ? null
              : () => setState(() => rows = widget.api.list('employees')),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: rows,
      builder: (context, state) {
        if (state.hasError)
          return const Center(
            child: Text(
              'Employee access is unavailable. No permission grant is assumed.',
            ),
          );
        if (!state.hasData)
          return const Center(child: CircularProgressIndicator());
        final staff = state.data!;
        if (staff.isEmpty)
          return const Center(
            child: Text('No employees are visible in this business.'),
          );
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Only the verified business owner can change explicit permission grants. Managers remain limited to current server permissions.',
              ),
            ),
            for (final employee in staff)
              ListTile(
                title: Text(employee['name']?.toString() ?? 'Employee'),
                subtitle: Text('${employee['role']} · ${employee['status']}'),
                onTap:
                    busy ||
                        employee['user_id'] ==
                            widget.api.client.auth.currentUser?.id ||
                        employee['role'] == 'owner'
                    ? null
                    : () => act(() => permissions(employee)),
                trailing: employee['role'] == 'owner'
                    ? null
                    : const Icon(Icons.chevron_right),
              ),
          ],
        );
      },
    ),
  );
}

class _PermissionOverrides extends StatefulWidget {
  final OperationsClient api;
  final Map<String, dynamic> employee;
  const _PermissionOverrides({required this.api, required this.employee});
  @override
  State<_PermissionOverrides> createState() => _PermissionOverridesState();
}

class _PermissionOverridesState extends State<_PermissionOverrides> {
  List<Map<String, dynamic>>? definitions;
  final Map<String, bool> overrides = {};
  String? error;
  bool busy = true;
  static const forbidden = {
    'owner_app',
    'manage_permissions',
    'assign_roles',
    'view_camera_events',
    'view_profit',
  };
  static const priceOrFinance = {
    'override_price',
    'edit_prices',
    'change_prices',
    'manage_prices',
    'set_prices',
    'branch_price_override',
    'view_finance',
  };
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final client = widget.api.client;
      final entries = await client
          .from('employee_permissions')
          .select('permission_id,granted')
          .eq('employee_id', widget.employee['id'] as String);
      final catalog = await client
          .from('permissions')
          .select('id,description')
          .order('id');
      if (!mounted) return;
      setState(() {
        overrides.clear();
        for (final row in entries) {
          overrides[row['permission_id'] as String] = row['granted'] == true;
        }
        definitions = catalog;
        busy = false;
        error = null;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          error =
              'Permission records could not be loaded. Refresh before changing access.';
        });
    }
  }

  Future<void> change(String id, bool value) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.api.client.rpc(
        'set_trexven_employee_permission',
        params: {
          'p_employee_id': widget.employee['id'],
          'p_permission': id,
          'p_granted': value,
        },
      );
      await load();
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          error =
              'Change was not confirmed. Server access may have changed; refresh before retrying.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.employee['name']} permissions'),
      actions: [
        IconButton(
          tooltip: 'Refresh permissions',
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'These are explicit overrides. “Role default” means no override has been recorded. Grant and Deny take effect on the server immediately. Owner access and restricted pricing cannot be delegated to sales or inventory employees.',
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
        for (final definition in definitions ?? <Map<String, dynamic>>[])
          if (!forbidden.contains(definition['id']))
            ListTile(
              title: Text(
                definition['description']?.toString() ??
                    definition['id'].toString(),
              ),
              subtitle: Text(
                '${definition['id']} · ${overrides[definition['id']] == null
                    ? 'Role default'
                    : overrides[definition['id']]!
                    ? 'Granted'
                    : 'Denied'}',
              ),
              trailing: PopupMenuButton<bool>(
                enabled: !busy,
                tooltip: 'Set explicit permission',
                onSelected: (value) =>
                    change(definition['id'] as String, value),
                itemBuilder: (_) => [
                  if ((!priceOrFinance.contains(definition['id']) ||
                          widget.employee['role'] == 'manager') &&
                      !(definition['id'] == 'apply_discount' &&
                          widget.employee['role'] == 'inventory_employee'))
                    const PopupMenuItem(value: true, child: Text('Grant')),
                  const PopupMenuItem(value: false, child: Text('Deny')),
                ],
              ),
            ),
      ],
    ),
  );
}
