import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import '../../services/initial_load_timeout.dart';
import '../../models/employee.dart';
import '../../services/employee_service.dart';
import '../../services/database_service.dart';
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
        Duration(seconds: 20),
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
        title: Text('Personnel', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!),
                  TextButton(onPressed: _loadBusinessId, child: Text('Retry')),
                ],
              ),
            )
          : _businessId == null
          ? const Center(child: TrexvenLoading())
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
        label: Text(
          'Add Employee',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        icon: Icon(Icons.add, color: Colors.white),
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
          padding: TrexvenSpacing.cardPadding,
          child: Row(
            children: [
              _statItem(theme, 'Total', total.toString(), Icons.people_outline),
              SizedBox(width: 15),
              _statItem(
                theme,
                'Active',
                active.toString(),
                Icons.check_circle_outline,
                color: theme.trexvenColors.success!,
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
    final muted = theme.trexvenColors.muted!;

    return Expanded(
      child: Container(
        padding: TrexvenSpacing.cardPadding,
        decoration: BoxDecoration(
          color: theme.trexvenColors.cardBackground,
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? brandBlue, size: 20),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: TrexvenFontSize.section,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: TrexvenFontSize.caption,
                    color: muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TrexvenTextField(
            variant: TrexvenFieldVariant.search,
            gap: 0,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: TrexvenInputDecoration(
              hintText: 'Search employees...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text('All'),
                  selected: _filterRole == null,
                  onSelected: (s) => setState(() => _filterRole = null),
                ),
                ...EmployeeRole.values.map(
                  (r) => Padding(
                    padding: EdgeInsets.only(left: 8),
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
                Text('Unable to load personnel. Please retry.'),
                TextButton(onPressed: _loadBusinessId, child: Text('Retry')),
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
          padding: TrexvenSpacing.cardPadding,
          itemCount: list.length,
          itemBuilder: (context, index) => _employeeCard(theme, list[index]),
        );
      },
    );
  }

  Widget _employeeCard(ThemeData theme, Employee emp) {
    final successColor = theme.trexvenColors.success!;
    final errorColor = theme.trexvenColors.error!;

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
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
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  fontSize: TrexvenFontSize.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                emp.employeeCode,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: TrexvenFontSize.caption,
                  color: theme.trexvenColors.muted,
                ),
              ),
            ],
          ),
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  (emp.status == EmployeeStatus.active
                          ? successColor
                          : errorColor)
                      .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(TrexvenRadii.status),
            ),
            child: Text(
              emp.statusDisplay,
              style: TextStyle(
                color: emp.status == EmployeeStatus.active
                    ? successColor
                    : errorColor,
                fontSize: TrexvenFontSize.caption,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
