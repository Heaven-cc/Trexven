import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:odt/models/employee.dart';
import 'package:odt/core/app_theme.dart';
import 'package:odt/screens/me/employment_screen.dart';
import 'package:odt/services/employee_service.dart';
import 'record_sale_flow_test.dart' show FakeDatabase;

class BusinessDatabase extends FakeDatabase {
  Future<String?> business = Future.value('b');
  @override
  Future<String?> getCurrentBusinessId() => business;
}

class Employees extends EmployeeService {
  final updates = StreamController<List<Employee>>.broadcast();
  int streams = 0;
  @override
  Stream<List<Employee>> getEmployeesStream(String businessId) {
    streams++;
    return updates.stream;
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.invalid',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets(
    'Personnel stream errors offer retry and stats/list share one load',
    (tester) async {
      final db = BusinessDatabase();
      final employees = Employees();
      await tester.pumpWidget(
        MaterialApp(
        theme: AppTheme.lightTheme,
          home: EmploymentScreen(database: db, employeeService: employees),
        ),
      );
      await tester.pump();
      employees.updates.addError(Exception('network unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to load personnel. Please retry.'),
        findsOneWidget,
      );
      expect(employees.streams, 1);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      employees.updates.add([]);
      await tester.pumpAndSettle();
      expect(find.text('No employees found'), findsOneWidget);
      expect(employees.streams, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await employees.updates.close();
      await db.updates.close();
    },
  );
  testWidgets(
    'Business lookup completed after leaving personnel does not setState',
    (tester) async {
      final completion = Completer<String?>();
      final db = BusinessDatabase()..business = completion.future;
      final employees = Employees();
      await tester.pumpWidget(
        MaterialApp(
        theme: AppTheme.lightTheme,
          home: EmploymentScreen(database: db, employeeService: employees),
        ),
      );
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      completion.complete('b');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(employees.streams, 0);
      await employees.updates.close();
      await db.updates.close();
    },
  );
}
