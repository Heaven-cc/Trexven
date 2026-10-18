import 'package:flutter/material.dart';
import '../../services/initial_load_timeout.dart';
import '../../core/app_theme.dart';
import '../../models/employee.dart';
import '../../services/employee_service.dart';
import '../../services/database_service.dart';
import '../../widgets/trexven_widgets.dart';
import 'add_employee_screen.dart';
import 'employee_details_screen.dart';

class EmploymentScreen extends StatefulWidget {
  const EmploymentScreen({super.key, this.database, this.employeeService});
  final DatabaseService? database;
  final EmployeeService? employeeService;

  @override
  State<EmploymentScreen> createState() => _EmploymentScreenState();
}

class _EmploymentScreenState extends State<EmploymentScreen> {
  late final EmployeeService _service;
  late final DatabaseService _db;
  String? _businessId;
  String? _loadError;
  Stream<List<Employee>>? _employees;
  String _searchQuery = '';
  EmployeeRole? _filterRole;

  @override
  void initState() {
    super.initState();
    _db = widget.database ?? DatabaseService();
    _service = widget.employeeService ?? EmployeeService();
    _loadBusinessId();
  }

  Future<void> _loadBusinessId() async {
    setState(() => _loadError = null);
    try {
      final id = await _db.getCurrentBusinessId().timeout(
        const Duration(seconds: 20),
      );
      if (!mounted) return;
      if (id == null)
        throw StateError('No business associated with this account.');
      setState(() {
        _businessId = id;
        _employees = withInitialLoadTimeout(
          _service.getEmployeesStream(id),
        ).asBroadcastStream(onCancel: (subscription) => subscription.cancel());
      });
    } catch (_) {
      if (mounted)
        setState(() => _loadError = 'Unable to load personnel. Please retry.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Personnel',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!),
                  TextButton(
                    onPressed: _loadBusinessId,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _businessId == null
          ? Center(child: CircularProgressIndicator(color: brandBlue))
          : Column(
              children: [
                _buildStats(theme),
                _buildFilters(theme),
                Expanded(child: _buildEmployeeList(theme)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _businessId == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEmployeeScreen(businessId: _businessId!),
                ),
              ),
        backgroundColor: brandBlue,
        label: const Text(
          'Add Employee',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStats(ThemeData theme) {
    return StreamBuilder<List<Employee>>(
      stream: _employees,
      builder: (context, snapshot) {
        final total = snapshot.data?.length ?? 0;
        final active =
            snapshot.data
                ?.where((e) => e.status == EmployeeStatus.active)
                .length ??
            0;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              _statItem(theme, 'Total', total.toString(), Icons.people_outline),
              const SizedBox(width: 15),
              _statItem(
                theme,
                'Active',
                active.toString(),
                Icons.check_circle_outline,
                color: theme.trexvenColors.success ?? Colors.green,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(
    ThemeData theme,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.trexvenColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? brandBlue, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(label, style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search employees...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterRole == null,
                  onSelected: (s) => setState(() => _filterRole = null),
                ),
                ...EmployeeRole.values.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(r.name.replaceAll('_', ' ').toUpperCase()),
                      selected: _filterRole == r,
                      onSelected: (s) =>
                          setState(() => _filterRole = s ? r : null),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList(ThemeData theme) {
    return StreamBuilder<List<Employee>>(
      stream: _employees,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load personnel. Please retry.'),
                TextButton(
                  onPressed: _loadBusinessId,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        if (!snapshot.hasData)
          return Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          );

        final list = snapshot.data!.where((e) {
          final matchesSearch =
              e.name.toLowerCase().contains(_searchQuery) ||
              e.employeeCode.toLowerCase().contains(_searchQuery);
          final matchesRole = _filterRole == null || e.role == _filterRole;
          return matchesSearch && matchesRole;
        }).toList();

        if (list.isEmpty) {
          return Center(
            child: Text(
              'No employees found',
              style: TextStyle(color: theme.trexvenColors.muted),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: list.length,
          itemBuilder: (context, index) => _employeeCard(theme, list[index]),
        );
      },
    );
  }

  Widget _employeeCard(ThemeData theme, Employee emp) {
    final successColor = theme.trexvenColors.success ?? Colors.green;
    final errorColor = theme.trexvenColors.error ?? Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TrexvenTapCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmployeeDetailsScreen(employee: emp),
          ),
        ),
        borderRadius: 16,
        padding: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Text(
            emp.name,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                emp.roleDisplay,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                emp.employeeCode,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: theme.trexvenColors.muted,
                ),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  (emp.status == EmployeeStatus.active
                          ? successColor
                          : errorColor)
                      .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              emp.statusDisplay,
              style: TextStyle(
                color: emp.status == EmployeeStatus.active
                    ? successColor
                    : errorColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
