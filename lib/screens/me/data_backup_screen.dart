import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/business_data_export_service.dart';

class DataBackupScreen extends StatefulWidget {
  const DataBackupScreen({super.key});

  @override
  State<DataBackupScreen> createState() => _DataBackupScreenState();
}

class _DataBackupScreenState extends State<DataBackupScreen> {
  final _exports = BusinessDataExportService();
  String? _exportingType;

  bool get _isExporting => _exportingType != null;

  // Dedicated app-owned staging directories only; never sweep general temp files.
  Future<void> _cleanExpiredExports(Directory root) async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory ||
          !entry.path.split(Platform.pathSeparator).last.startsWith('export_')) continue;
      try {
        if ((await entry.stat()).modified.isBefore(cutoff)) {
          await entry.delete(recursive: true);
        }
      } on FileSystemException {
        // OS cache eviction can also remove copies; cleanup is best effort.
      }
    }
  }

  Future<void> _exportData(String type, BuildContext source) async {
    if (_isExporting || !mounted) return;
    setState(() => _exportingType = type);
    Directory? staging;
    bool handedOff = false;
    try {
      final data = await _exports.load(type);
      if (!mounted || !source.mounted) return;
      final csv = ListToCsvConverter().convert([
        for (final row in data.rows)
          [for (final cell in row) BusinessDataExportService.csvCell(cell)],
      ]);
      final temporary = await getTemporaryDirectory();
      final root = Directory('${temporary.path}/trexven_csv_exports');
      await root.create(recursive: true);
      await _cleanExpiredExports(root);
      await _exports.verifyScope(data);
      if (!mounted || !source.mounted) return;
      staging = await root.createTemp('export_');
      final name = 'trexven_${data.businessId}_${data.type}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${staging.path}/$name');
      await file.writeAsString('\ufeff$csv', flush: true);
      await _exports.verifyScope(data);
      if (!mounted || !source.mounted) return;
      final box = source.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) {
        throw StateError('Reopen this screen before sharing.');
      }
      // Recompute the tile anchor after asynchronous reads, including rotation.
      final origin = box.localToGlobal(Offset.zero) & box.size;
      handedOff = true;
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        text: 'TREXVEN selected-business export',
        sharePositionOrigin: origin,
      );
      if (mounted) {
        final message = switch (result.status) {
          ShareResultStatus.success => 'Export shared. Saving is handled by the chosen app.',
          ShareResultStatus.dismissed => 'Export sharing canceled.',
          _ => 'Your device did not confirm sharing. Check the chosen app before exporting again.',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(CustomerPresentation.error(e,
              fallback: 'Export failed. Please try again.')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      // Share completion does not prove recipients have finished reading on every
      // platform. Keep handed-off copies for bounded delayed cleanup instead.
      if (!handedOff && staging != null) {
        try { await staging.delete(recursive: true); } on FileSystemException {}
      }
      if (mounted) setState(() => _exportingType = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Data & Backup',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: TrexvenSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoCard(theme),
            SizedBox(height: TrexvenSpacing.sectionGap),
            Text(
              'Export Data',
              style: TextStyle(
                fontSize: TrexvenFontSize.input,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12),
            _exportItem(
              theme,
              'Product Catalog',
              'Export catalog prices and stock; branch balances are excluded',
              (source) => _exportData('products', source),
              isLoading: _exportingType == 'products',
            ),
            SizedBox(height: 12),
            _exportItem(
              theme,
              'Sales History',
              'Export sales headers across this business; excludes item, repayment and return details',
              (source) => _exportData('sales', source),
              isLoading: _exportingType == 'sales',
            ),
            SizedBox(height: 40),
            Text(
              'Backup Status',
              style: TextStyle(
                fontSize: TrexvenFontSize.input,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: TrexvenSpacing.cardPadding,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(TrexvenRadii.card),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_outlined, color: statusColor),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Automated backup status unavailable',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          'This screen cannot verify scheduled backups or restore readiness. CSV exports are manual extracts.',
                          style: TextStyle(
                            fontSize: TrexvenFontSize.caption,
                            color: statusColor,
                          ),
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
      padding: TrexvenSpacing.cardPadding,
      decoration: BoxDecoration(
        color: brandBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: brandBlue),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Exports include only your selected business. Data may change during export. CSV extracts do not include every record needed to restore your business.',
              style: TextStyle(
                fontSize: TrexvenFontSize.body,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportItem(
    ThemeData theme,
    String title,
    String sub,
    ValueChanged<BuildContext> onTap, {
    required bool isLoading,
  }) {
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted!;

    return Builder(
      builder: (source) => ListTile(
        onTap: _isExporting ? null : () => onTap(source),
        tileColor: theme.trexvenColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
          side: BorderSide(color: theme.trexvenColors.border!),
        ),
        leading: Icon(Icons.file_download_outlined, color: brandBlue),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: TrexvenFontSize.body,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          sub,
          style: TextStyle(fontSize: TrexvenFontSize.caption, color: muted),
        ),
        trailing: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: Icon(Icons.more_horiz_rounded, size: 16),
              )
            : Icon(Icons.chevron_right, color: muted.withValues(alpha: 0.5)),
        ),
    );
  }
}
