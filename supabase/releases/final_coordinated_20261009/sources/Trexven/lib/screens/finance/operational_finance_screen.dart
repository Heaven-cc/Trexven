import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../../services/database_service.dart';

class OperationalFinanceScreen extends StatefulWidget {
  const OperationalFinanceScreen({super.key});
  @override
  State<OperationalFinanceScreen> createState() =>
      _OperationalFinanceScreenState();
}

class _OperationalFinanceScreenState extends State<OperationalFinanceScreen> {
  late final Future<String?> business = DatabaseService()
      .getCurrentBusinessId();
  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: business,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (snapshot.hasError || snapshot.data == null)
        return const Scaffold(
          body: Center(child: Text('Verified owner business required.')),
        );
      final api = OperationsClient(Supabase.instance.client, snapshot.data!);
      return Scaffold(
        appBar: AppBar(title: const Text('Business operations')),
        body: ListView(
          children: [
            ListTile(
              title: const Text('Credit and returns'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FinancialOperationsScreen(api: api, owner: true),
                ),
              ),
            ),
            ListTile(
              title: const Text('Inventory operations'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InventoryOperationsScreen(api: api),
                ),
              ),
            ),
            ListTile(
              title: const Text('Shared cash drawers'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CashShiftScreen(api: api, owner: true),
                ),
              ),
            ),
            ListTile(
              title: const Text('Operational employee permissions'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OperationalPermissionsScreen(api: api),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
