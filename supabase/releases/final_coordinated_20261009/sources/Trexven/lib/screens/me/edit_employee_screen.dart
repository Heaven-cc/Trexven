import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
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
        const SnackBar(content: Text('Employee updated successfully'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
        title: const Text('Edit Employee', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(theme, _nameCtrl, 'Full Name', Icons.person_outline, validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              _field(theme, _phoneCtrl, 'Phone Number (Optional)', Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _field(theme, _emailCtrl, 'Email (Optional)', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _dropdown(theme),
              const SizedBox(height: 32),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandBlue, 
                    foregroundColor: Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(ThemeData theme, TextEditingController ctrl, String hint, IconData icon, {TextInputType? keyboardType, String? Function(String?)? validator}) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: muted.withOpacity(0.5)),
        prefixIcon: Icon(icon, size: 20, color: muted),
        filled: true,
        fillColor: theme.trexvenColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), 
          borderSide: BorderSide(color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), 
          borderSide: BorderSide(color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _dropdown(ThemeData theme) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return DropdownButtonFormField<EmployeeRole>(
      value: _selectedRole,
      style: TextStyle(color: theme.colorScheme.onSurface),
      dropdownColor: theme.trexvenColors.cardBackground,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.security, size: 20, color: muted),
        filled: true,
        fillColor: theme.trexvenColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), 
          borderSide: BorderSide(color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), 
          borderSide: BorderSide(color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0)),
        ),
      ),
      items: [
        EmployeeRole.manager,
        EmployeeRole.sales_employee,
        EmployeeRole.inventory_employee,
      ].map((r) => DropdownMenuItem(
        value: r,
        child: Text(r.name.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 14)),
      )).toList(),
      onChanged: (v) => setState(() => _selectedRole = v!),
    );
  }
}
