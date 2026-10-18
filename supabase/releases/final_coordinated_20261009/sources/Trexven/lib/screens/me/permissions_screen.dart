import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../../services/database_service.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  late final business = DatabaseService().getCurrentBusinessId();
  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: business,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const Scaffold(
          body: Center(
            child: Text('Verified owner business access is required.'),
          ),
        );
      if (snapshot.connectionState != ConnectionState.done)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final id = snapshot.data;
      if (id == null)
        return const Scaffold(
          body: Center(child: Text('Select an owned business first.')),
        );
      return EmployeeAccessScreen(
        api: OperationsClient(Supabase.instance.client, id),
      );
    },
  );
}
