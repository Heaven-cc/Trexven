import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employee.dart';

class EmployeeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Employee>> getEmployees(String businessId) async {
    final response = await _supabase
        .from('employees')
        .select()
        .eq('business_id', businessId)
        .order('created_at', ascending: false);

    return response.map<Employee>((m) => Employee.fromMap(m)).toList();
  }

  Stream<List<Employee>> getEmployeesStream(String businessId) {
    return _supabase
        .from('employees')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .order('created_at')
        .map((data) => data.map((m) => Employee.fromMap(m)).toList());
  }

  Future<Map<String, dynamic>> createEmployee({
    required String businessId,
    required String name,
    String? email,
    String? phone,
    required String role,
    required String password,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-employee',
        body: {
          'business_id': businessId,
          'name': name,
          'email': email,
          'phone': phone,
          'role': role,
          'password': password,
        },
      );

      if (response.status != 200) {
        final error = response.data['error'] ?? 'Failed to create employee';
        throw Exception(error);
      }

      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateEmployee(Employee employee) async {
    await _supabase.rpc('update_trexven_employee', params: {
      'p_employee_id': employee.id, 'p_name': employee.name,
      'p_phone': employee.phone, 'p_email': employee.email,
      'p_role': employee.role.name, 'p_status': employee.status.name,
    });
  }

  Future<void> resetPassword({
      required String businessId,
      required String employeeId,
      required String newPassword,
  }) async {
      final response = await _supabase.functions.invoke(
          'manage-employee',
          body: {
              'action': 'reset_password',
              'business_id': businessId,
              'employee_id': employeeId,
              'new_password': newPassword,
          },
      );

      if (response.status != 200) {
          throw Exception(response.data['error'] ?? 'Failed to reset password');
      }
  }

  Future<void> updateEmployeeStatus(String employeeId, EmployeeStatus status) async {
    await _supabase.rpc('set_trexven_employee_status', params: {
      'p_employee_id': employeeId, 'p_status': status.name,
    });
  }
}
