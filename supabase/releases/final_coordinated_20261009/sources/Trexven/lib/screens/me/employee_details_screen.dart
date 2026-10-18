import 'permissions_screen.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/employee.dart';
import '../../services/employee_service.dart';
import 'edit_employee_screen.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeDetailsScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  final _service = EmployeeService();
  bool _isLoading = false;
  late Employee _currentEmployee;

  @override
  void initState() {
    super.initState();
    _currentEmployee = widget.employee;
  }

  Future<void> _toggleStatus() async {
    final newStatus = _currentEmployee.status == EmployeeStatus.active
        ? EmployeeStatus.suspended
        : EmployeeStatus.active;

    setState(() => _isLoading = true);
    try {
      await _service.updateEmployeeStatus(_currentEmployee.id!, newStatus);
      if (mounted) {
        setState(() {
          _currentEmployee = Employee(
            id: _currentEmployee.id,
            userId: _currentEmployee.userId,
            businessId: _currentEmployee.businessId,
            employeeCode: _currentEmployee.employeeCode,
            name: _currentEmployee.name,
            role: _currentEmployee.role,
            email: _currentEmployee.email,
            phone: _currentEmployee.phone,
            status: newStatus,
            createdAt: _currentEmployee.createdAt,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Employee ${newStatus.name} successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showResetPasswordDialog() {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Reset Password',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter a new password for this employee. They will need this to log in.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                hintText: 'Minimum 6 characters',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password too short')),
                );
                return;
              }
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await _service.resetPassword(
                  businessId: _currentEmployee.businessId,
                  employeeId: _currentEmployee.id!,
                  newPassword: passCtrl.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final brandBlue = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Employee Details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EditEmployeeScreen(employee: _currentEmployee),
                ),
              );
              if (result != null && mounted) {
                setState(() => _currentEmployee = result as Employee);
              }
            },
            icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: brandBlue.withOpacity(0.1),
                        child: Icon(Icons.person, size: 40, color: brandBlue),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentEmployee.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        _currentEmployee.roleDisplay,
                        style: TextStyle(
                          color: brandBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                _infoSection(theme, [
                  _infoTile(
                    theme,
                    'Employee ID',
                    _currentEmployee.employeeCode,
                    Icons.badge_outlined,
                    isCode: true,
                  ),
                  _infoTile(
                    theme,
                    'Email',
                    _currentEmployee.email ?? 'No email',
                    Icons.email_outlined,
                  ),
                  _infoTile(
                    theme,
                    'Phone',
                    _currentEmployee.phone ?? 'No phone',
                    Icons.phone_outlined,
                  ),
                  _infoTile(
                    theme,
                    'Status',
                    _currentEmployee.statusDisplay,
                    Icons.info_outline,
                    color: _currentEmployee.status == EmployeeStatus.active
                        ? (theme.trexvenColors.success ?? Colors.green)
                        : (theme.trexvenColors.error ?? Colors.red),
                  ),
                ]),
                const SizedBox(height: 24),
                _infoSection(theme, [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Permissions',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: muted,
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Review current employee permissions'),
                    subtitle: const Text(
                      'Access comes from the current role and explicit owner grants. Role labels alone do not grant sensitive actions.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PermissionsScreen(),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 40),
                _actionButton(
                  theme,
                  _currentEmployee.status == EmployeeStatus.active
                      ? 'Suspend Employee'
                      : 'Activate Employee',
                  _currentEmployee.status == EmployeeStatus.active
                      ? (theme.trexvenColors.error ?? Colors.red)
                      : (theme.trexvenColors.success ?? Colors.green),
                  Icons.block_flipped,
                  onTap: _toggleStatus,
                ),
                const SizedBox(height: 12),
                _actionButton(
                  theme,
                  'Reset Password',
                  theme.colorScheme.onSurface,
                  Icons.lock_reset_outlined,
                  onTap: _showResetPasswordDialog,
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator(color: brandBlue)),
            ),
        ],
      ),
    );
  }

  Widget _infoSection(ThemeData theme, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoTile(
    ThemeData theme,
    String label,
    String value,
    IconData icon, {
    bool isCode = false,
    Color? color,
  }) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return ListTile(
      leading: Icon(icon, size: 20, color: muted),
      title: Text(label, style: TextStyle(fontSize: 12, color: muted)),
      subtitle: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: color ?? theme.colorScheme.onSurface,
          fontSize: 15,
          fontFamily: isCode ? 'monospace' : null,
        ),
      ),
    );
  }

  Widget _actionButton(
    ThemeData theme,
    String label,
    Color color,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : onTap,
        icon: Icon(icon, color: color, size: 20),
        label: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
