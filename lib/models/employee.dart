enum EmployeeStatus { active, suspended, inactive, terminated }

enum EmployeeRole { owner, manager, sales_employee, inventory_employee }

class Employee {
  final String? id;
  final String? userId;
  final String businessId;
  final String employeeCode;
  final String name;
  final EmployeeRole role;
  final String? email;
  final String? phone;
  final EmployeeStatus status;
  final DateTime? createdAt;

  Employee({
    this.id,
    this.userId,
    required this.businessId,
    required this.employeeCode,
    required this.name,
    required this.role,
    this.email,
    this.phone,
    required this.status,
    this.createdAt,
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'],
      userId: map['user_id'],
      businessId: map['business_id'],
      employeeCode: map['employee_code'],
      name: map['name'] ?? '',
      role: EmployeeRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => EmployeeRole.sales_employee,
      ),
      email: map['email'],
      phone: map['phone'],
      status: EmployeeStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => EmployeeStatus.active,
      ),
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'business_id': businessId,
      'employee_code': employeeCode,
      'name': name,
      'role': role.name,
      'email': email,
      'phone': phone,
      'status': status.name,
    };
  }

  String get roleDisplay {
    switch (role) {
      case EmployeeRole.owner: return 'Owner';
      case EmployeeRole.manager: return 'Manager';
      case EmployeeRole.sales_employee: return 'Sales Employee';
      case EmployeeRole.inventory_employee: return 'Inventory Employee';
    }
  }

  String get statusDisplay {
    return status.name[0].toUpperCase() + status.name.substring(1);
  }
}
