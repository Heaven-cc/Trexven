import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_theme.dart';
import '../../services/database_service.dart';

class DataBackupScreen extends StatefulWidget {
  const DataBackupScreen({super.key});

  @override
  State<DataBackupScreen> createState() => _DataBackupScreenState();
}

class _DataBackupScreenState extends State<DataBackupScreen> {
  final _db = DatabaseService();
  String? _exportingType;

  bool get _isExporting => _exportingType != null;

  Future<void> _exportData(String type) async {
    setState(() => _exportingType = type);
    try {
      List<List<dynamic>> rows = [];
      String fileName = "";

      if (type == 'products') {
        final products = await _db.getProducts();
        fileName = "trexven_products_${DateTime.now().millisecondsSinceEpoch}.csv";
        rows.add(["ID", "Name", "Category", "Price", "Stock"]);
        for (var p in products) {
          rows.add([p.id, p.name, p.category, p.isPricePending ? 'Pending' : p.price, p.stock]);
        }
      } else if (type == 'sales') {
        final sales = await _db.getSalesWithProductNames();
        fileName = "trexven_sales_${DateTime.now().millisecondsSinceEpoch}.csv";
        rows.add(["ID", "Product", "Quantity", "Total", "Date"]);
        for (var s in sales) {
          rows.add([s.id, s.productName, s.quantity, s.totalPrice, s.createdAt]);
        }
      }

      if (rows.isEmpty) return;

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/$fileName";
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(path)], text: 'Trexven Data Export ($type)');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _exportingType = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successColor = theme.trexvenColors.success ?? Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data & Backup', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoCard(theme),
            const SizedBox(height: 32),
            Text(
              'Export Data', 
              style: TextStyle(
                fontSize: 15, 
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _exportItem(
              theme,
              'Products Inventory', 
              'Download all products and stock levels as CSV', 
              () => _exportData('products'),
              isLoading: _exportingType == 'products',
            ),
            const SizedBox(height: 12),
            _exportItem(
              theme,
              'Sales History', 
              'Download all historical sales records as CSV', 
              () => _exportData('sales'),
              isLoading: _exportingType == 'sales',
            ),
            const SizedBox(height: 40),
            Text(
              'Cloud Sync', 
              style: TextStyle(
                fontSize: 15, 
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: successColor.withOpacity(0.05), 
                borderRadius: BorderRadius.circular(16), 
                border: Border.all(color: successColor.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_done_outlined, color: successColor),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Automated Backup Active', 
                          style: TextStyle(
                            fontWeight: FontWeight.w700, 
                            color: successColor,
                          ),
                        ),
                        Text(
                          'Your data is securely synced with Trexven Cloud.', 
                          style: TextStyle(fontSize: 11, color: successColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(ThemeData theme) {
    final brandBlue = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: brandBlue.withOpacity(0.08), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: brandBlue.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: brandBlue),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'You can export your business data at any time for accounting or external records.',
              style: TextStyle(
                fontSize: 13, 
                color: theme.colorScheme.onSurface.withOpacity(0.8), 
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportItem(ThemeData theme, String title, String sub, VoidCallback onTap, {required bool isLoading}) {
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return ListTile(
      onTap: _isExporting ? null : onTap,
      tileColor: theme.trexvenColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
      ),
      leading: Icon(Icons.file_download_outlined, color: brandBlue),
      title: Text(
        title, 
        style: TextStyle(
          fontWeight: FontWeight.w700, 
          fontSize: 14,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(sub, style: TextStyle(fontSize: 12, color: muted)),
      trailing: isLoading 
          ? SizedBox(
              width: 20, 
              height: 20, 
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: brandBlue,
              ),
            ) 
          : Icon(Icons.chevron_right, color: muted.withOpacity(0.5)),
    );
  }
}
