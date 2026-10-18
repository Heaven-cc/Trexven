import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/employee.dart';
import '../../services/employee_service.dart';
import 'employee_confirmation_screen.dart';

class AddEmployeeScreen extends StatefulWidget {
  final String businessId;

  const AddEmployeeScreen({super.key, required this.businessId});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = EmployeeService();

  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  EmployeeRole _selectedRole = EmployeeRole.sales_employee;
  bool _isLoading = false;

  Future<void> _submit() async {
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) {
      _showSnackBar(
        "Your session has expired. Please sign in again.",
        isError: true,
      );
      return;
    }

    if (widget.businessId.isEmpty) {
      _showSnackBar("Your business could not be identified.", isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final name = [
      _firstCtrl.text.trim(),
      _lastCtrl.text.trim(),
    ].where((val) => val.isNotEmpty).join(' ');

    if (name.isEmpty) {
      _showSnackBar('Employee name is required', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _service.createEmployee(
        businessId: widget.businessId,
        name: name,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        role: _selectedRole.name,
        password: _passCtrl.text.trim(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EmployeeConfirmationScreen(
            name: name,
            employeeCode: result['employee_code'],
            role: _selectedRole.name.replaceAll('_', ' ').toUpperCase(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String message = e.toString();
      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }

      _showSnackBar(message, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).trexvenColors.success!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Employee',
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
                _firstCtrl,
                'First Name',
                Icons.person_outline,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              _field(
                theme,
                _lastCtrl,
                'Last Name',
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
              Divider(
                height: 32,
                color: theme.trexvenColors.border?.withValues(alpha: 0.5),
              ),
              Text(
                'Login Credentials',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: TrexvenFontSize.input,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'The employee will use their Employee ID and this password to log in.',
                style: TextStyle(
                  fontSize: TrexvenFontSize.caption,
                  color: muted,
                ),
              ),
              SizedBox(height: TrexvenSpacing.fieldGap),
              _field(
                theme,
                _passCtrl,
                'Create Password',
                Icons.lock_outline,
                obscure: true,
                validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
              ),
              SizedBox(height: TrexvenSpacing.sectionGap),
              TrexvenButton(
                text: 'Create Employee Profile',
                onPressed: _submit,
                isLoading: _isLoading,
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
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final muted = theme.trexvenColors.muted!;

    return TrexvenTextFormField(
      controller: ctrl,
      obscureText: obscure,
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
