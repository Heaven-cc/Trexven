import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:flutter/material.dart';
import '../../models/employee.dart';
import '../../services/employee_service.dart';

class EditEmployeeScreen extends StatefulWidget {
  final Employee employee;

  const EditEmployeeScreen({super.key, required this.employee});

  @override
  State<EditEmployeeScreen> createState() => _EditEmployeeScreenState();
}

class _EditEmployeeScreenState extends State<EditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = EmployeeService();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late EmployeeRole _selectedRole;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.employee.name);
    _phoneCtrl = TextEditingController(text: widget.employee.phone);
    _emailCtrl = TextEditingController(text: widget.employee.email);
    _selectedRole = widget.employee.role;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updated = Employee(
        id: widget.employee.id,
        userId: widget.employee.userId,
        businessId: widget.employee.businessId,
        employeeCode: widget.employee.employeeCode,
        name: _nameCtrl.text.trim(),
        role: _selectedRole,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        status: widget.employee.status,
      );

      await _service.updateEmployee(updated);

      if (!mounted) return;
      Navigator.pop(context, updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Employee updated successfully'),
          backgroundColor: Theme.of(context).trexvenColors.success!,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CustomerPresentation.error(
              e,
              fallback: 'We could not complete this action. Please try again.',
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Employee',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: TrexvenSpacing.pagePadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(
                theme,
                _nameCtrl,
                'Full Name',
                Icons.person_outline,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              _field(
                theme,
                _phoneCtrl,
                'Phone Number (Optional)',
                Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              _field(
                theme,
                _emailCtrl,
                'Email (Optional)',
                Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              _dropdown(theme),
              SizedBox(height: TrexvenSpacing.sectionGap),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: TrexvenSpacing.buttonHeight,
                ),
                child: SizedBox(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandBlue,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.onPrimary,
                          )
                        : Text(
                            'Save Changes',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    ThemeData theme,
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final muted = theme.trexvenColors.muted!;

    return TrexvenTextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      decoration: TrexvenInputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: muted),
      ),
    );
  }

  Widget _dropdown(ThemeData theme) {
    final muted = theme.trexvenColors.muted!;

    return TrexvenDropdown<EmployeeRole>(
      label: 'Role',
      value: _selectedRole,
      decoration: TrexvenInputDecoration(
        prefixIcon: Icon(Icons.security, size: 20, color: muted),
      ),
      items:
          [
                EmployeeRole.manager,
                EmployeeRole.sales_employee,
                EmployeeRole.inventory_employee,
              ]
              .map(
                (r) => DropdownMenuItem(
                  value: r,
                  child: Text(
                    r.name.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(fontSize: TrexvenFontSize.body),
                  ),
                ),
              )
              .toList(),
      onChanged: (v) => setState(() => _selectedRole = v!),
    );
  }
}
