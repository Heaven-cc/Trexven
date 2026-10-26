import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../../services/database_service.dart';
import '../inventory/inventory_tab.dart';
import '../inventory/angel_inventory_approval_screen.dart';
import '../finance/operational_finance_screen.dart';
import '../intelligence/alerts_screen.dart';
import 'employment_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _lowStock = true;
  bool _sales = true;
  bool _aiAlerts = true;
  bool _security = true;

  String _frequency = 'Instant';

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _openInbox() async {
    try {
      final id = await DatabaseService().getCurrentBusinessId();
      if (!mounted) return;
      if (id == null) throw StateError('Verified owner business required.');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationCenterScreen(
            api: OperationsClient(Supabase.instance.client, id),
            open: (context, route, referenceId) {
              final Widget screen = switch (route) {
                'angel_inventory_approval' when referenceId != null => AngelInventoryApprovalScreen(client: Supabase.instance.client, businessId: id, requestId: referenceId),
                'credit' || 'returns' => FinancialOperationsScreen(api: OperationsClient(Supabase.instance.client, id), owner: true, notificationReferenceId:referenceId, notificationIsReturn:route == 'returns'),
                'inventory' => InventoryTab(),
                'cash' => OperationalFinanceScreen(),
                'employees' => EmploymentScreen(),
                'vision' => AlertsScreen(),
                _ => Scaffold(
                  body: Center(
                    child: Text(
                      'This notification has no supported destination.',
                    ),
                  ),
                ),
              };
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => screen),
              );
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        _showMessage(
          'Verified owner notification access is unavailable.',
          isError: true,
        );
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _lowStock = prefs.getBool('notify_low_stock') ?? true;
        _sales = prefs.getBool('notify_sales') ?? true;
        _aiAlerts = prefs.getBool('notify_ai_alerts') ?? true;
        _security = prefs.getBool('notify_security') ?? true;
        _frequency = 'Instant';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load notification settings.';
        _loading = false;
      });
    }
  }

  Future<void> _updateBool(String key, bool value) async {
    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);

      if (!mounted) return;

      setState(() {
        switch (key) {
          case 'notifications_enabled':
            _notificationsEnabled = value;
            break;
          case 'notify_low_stock':
            _lowStock = value;
            break;
          case 'notify_sales':
            _sales = value;
            break;
          case 'notify_ai_alerts':
            _aiAlerts = value;
            break;
          case 'notify_security':
            _security = value;
            break;
        }
      });
    } catch (_) {
      _showMessage(
        'Unable to save your notification preference.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _updateFrequency(String value) async {
    setState(() {
      _saving = true;
      _frequency = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notification_frequency', value);
    } catch (_) {
      _showMessage('Unable to save notification frequency.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? (theme.trexvenColors.error!)
            : (theme.trexvenColors.success!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted!;

    if (_loading) {
      return Scaffold(
        body: Center(
          child: Text('Please wait…'),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Notifications',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          elevation: 0,
          foregroundColor: theme.colorScheme.onSurface,
        ),
        body: Center(
          child: Padding(
            padding: TrexvenSpacing.pagePadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: theme.trexvenColors.error,
                ),
                SizedBox(height: TrexvenSpacing.fieldGap),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
                SizedBox(height: TrexvenSpacing.fieldGap),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _loadSettings();
                  },
                  child: Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: TrexvenFontSize.section,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          if (_saving)
            Padding(
              padding: EdgeInsets.only(right: 20),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: Icon(Icons.more_horiz_rounded, size: 16),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ListTile(
            leading: Icon(Icons.inbox_outlined),
            title: Text('Open business notifications'),
            subtitle: Text(
              'Current authorized alerts, employee changes and reconciliation reviews with personal read status.',
            ),
            onTap: _openInbox,
          ),
          Padding(
            padding: TrexvenSpacing.cardPadding,
            child: Text(
              'The preferences below are stored on this device. Push notification delivery has not been configured.',
            ),
          ),
          _section(theme, 'General', [
            _item(
              theme,
              icon: Icons.notifications_active_outlined,
              title: 'Notifications',
              subtitle: 'Enable TREXVEN notifications on this device',
              value: _notificationsEnabled,
              onChanged: (value) {
                _updateBool('notifications_enabled', value);
              },
            ),
          ]),

          SizedBox(height: TrexvenSpacing.sectionGap),

          Opacity(
            opacity: _notificationsEnabled ? 1 : 0.5,
            child: IgnorePointer(
              ignoring: !_notificationsEnabled,
              child: Column(
                children: [
                  _section(theme, 'Inventory & Sales', [
                    _item(
                      theme,
                      icon: Icons.inventory_2_outlined,
                      title: 'Low Stock Alerts',
                      subtitle:
                          'Notify me when products fall below their stock threshold',
                      value: _lowStock,
                      onChanged: (value) {
                        _updateBool('notify_low_stock', value);
                      },
                    ),
                    _divider(theme),
                    _item(
                      theme,
                      icon: Icons.receipt_long_outlined,
                      title: 'Sales Summary',
                      subtitle: 'Receive notifications about business sales',
                      value: _sales,
                      onChanged: (value) {
                        _updateBool('notify_sales', value);
                      },
                    ),
                  ]),

                  SizedBox(height: TrexvenSpacing.sectionGap),

                  _section(theme, 'Vision & Security', [
                    _item(
                      theme,
                      icon: Icons.visibility_outlined,
                      title: 'Vision AI Alerts',
                      subtitle:
                          'Alert me about important TREXVEN Vision detection events',
                      value: _aiAlerts,
                      onChanged: (value) {
                        _updateBool('notify_ai_alerts', value);
                      },
                    ),
                    _divider(theme),
                    _item(
                      theme,
                      icon: Icons.shield_outlined,
                      title: 'Security Alerts',
                      subtitle:
                          'Sign-ins, password changes and important security activity',
                      value: _security,
                      onChanged: (value) {
                        _updateBool('notify_security', value);
                      },
                    ),
                  ]),

                  SizedBox(height: TrexvenSpacing.sectionGap),

                  _frequencySection(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _frequencySection(ThemeData theme) {
    final muted = theme.trexvenColors.muted!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notification Frequency',
          style: TextStyle(
            fontSize: TrexvenFontSize.input,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Updates appear immediately while TREXVEN is connected.',
          style: TextStyle(fontSize: TrexvenFontSize.body, color: muted),
        ),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.trexvenColors.cardBackground,
            borderRadius: BorderRadius.circular(TrexvenRadii.card),
          ),
          child: Column(
            children: [_frequencyItem(theme, 'Instant'), _divider(theme)],
          ),
        ),
      ],
    );
  }

  Widget _frequencyItem(ThemeData theme, String value) {
    return RadioListTile<String>(
      value: value,
      groupValue: _frequency,
      activeColor: theme.colorScheme.primary,
      onChanged: _saving
          ? null
          : (selected) {
              if (selected != null) {
                _updateFrequency(selected);
              }
            },
      title: Text(
        value,
        style: TextStyle(
          fontSize: TrexvenFontSize.input,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: TrexvenFontSize.input,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.trexvenColors.cardBackground,
            borderRadius: BorderRadius.circular(TrexvenRadii.card),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _divider(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(left: 72),
      child: Divider(
        height: 1,
        color:
            theme.trexvenColors.border?.withValues(alpha: 0.5) ??
            Colors.white12,
      ),
    );
  }

  Widget _item(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted!;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: brandBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
            ),
            child: Icon(icon, color: brandBlue, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: TrexvenFontSize.input,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: TrexvenFontSize.caption,
                    color: muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Switch(
            value: value,
            activeColor: brandBlue,
            onChanged: _saving ? null : onChanged,
          ),
        ],
      ),
    );
  }
}

