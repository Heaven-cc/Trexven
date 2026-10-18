import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../auth/auth_provider.dart';
import 'offline_cash_screen.dart';
import 'pending_sale_provider.dart';

final posThemeProvider = StateNotifierProvider<PosTheme, ThemeMode>(
  (ref) => PosTheme(),
);

class PosTheme extends StateNotifier<ThemeMode> {
  PosTheme() : super(ThemeMode.system) {
    load();
  }
  int _generation = 0;
  Future<void> load() async {
    final generation = _generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted && generation == _generation)
        state = ThemeMode.values.firstWhere(
          (mode) => mode.name == prefs.getString('pos_theme'),
          orElse: () => ThemeMode.system,
        );
    } catch (_) {
      // The system appearance remains usable if local preferences are unavailable.
    }
  }

  Future<void> select(ThemeMode mode) async {
    final generation = ++_generation;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('pos_theme', mode.name))
      throw StateError('Appearance was not saved.');
    if (mounted && generation == _generation) state = mode;
  }
}

class EmployeeSettingsScreen extends ConsumerWidget {
  const EmployeeSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider), employee = auth.employee;
    return Scaffold(
      appBar: AppBar(title: const Text('My settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('My Profile'),
            subtitle: Text(employee?.name ?? 'Signed out'),
          ),
          ListTile(
            title: const Text('Employee ID'),
            subtitle: Text(employee?.employeeCode ?? 'Unavailable'),
          ),
          ListTile(
            title: const Text('Business'),
            subtitle: Text(auth.activeBusiness?.name ?? 'Unavailable'),
          ),
          ListTile(
            title: const Text('Role'),
            subtitle: Text(employee?.role.name ?? 'Unavailable'),
          ),
          ListTile(
            title: const Text('Contact'),
            subtitle: Text(
              employee?.email ??
                  employee?.phone ??
                  'Contact the owner to update your employee details.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change password'),
            onTap: auth.offlineCashOnly || employee == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _ChangePassword()),
                  ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Appearance'),
            trailing: DropdownButton<ThemeMode>(
              value: ref.watch(posThemeProvider),
              items: [
                for (final mode in ThemeMode.values)
                  DropdownMenuItem(value: mode, child: Text(mode.name)),
              ],
              onChanged: (mode) async {
                if (mode == null) return;
                try {
                  await ref.read(posThemeProvider.notifier).select(mode);
                } catch (_) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Appearance could not be saved.'),
                      ),
                    );
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications & recovery'),
            subtitle: const Text(
              'Device sales requiring synchronization or confirmation',
            ),
            onTap: employee == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _DeviceAlerts()),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChangePassword extends ConsumerStatefulWidget {
  const _ChangePassword();
  @override
  ConsumerState<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends ConsumerState<_ChangePassword> {
  final current = TextEditingController(),
      next = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false;
  String? message;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    if (next.text.length < 8 ||
        next.text != confirmation.text ||
        current.text.isEmpty) {
      setState(
        () => message =
            'Enter your current password and matching new passwords of at least eight characters.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final client = ref.read(supabaseProvider),
          auth = ref.read(authStateProvider);
      final actor = auth.employee?.userId;
      if (auth.offlineCashOnly || actor == null)
        throw StateError('Online verification is required.');
      final verified = await client.auth.getUser();
      final email = verified.user?.email;
      if (verified.user?.id != actor || email == null)
        throw StateError('Original employee identity required.');
      final signedIn = await client.auth.signInWithPassword(
        email: email,
        password: current.text,
      );
      if (signedIn.user?.id != actor ||
          ref.read(authStateProvider).employee?.userId != actor)
        throw StateError('Account changed during verification.');
      await client.auth.updateUser(UserAttributes(password: next.text));
      current.clear();
      next.clear();
      confirmation.clear();
      if (mounted)
        setState(
          () => message =
              'Password changed. Pending sales and encrypted queues have been retained.',
        );
    } catch (_) {
      if (mounted)
        setState(
          () => message =
              'Password change was not confirmed. Verify your current password and connection before retrying.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change password')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final field in [
          (current, 'Current password'),
          (next, 'New password'),
          (confirmation, 'Confirm new password'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: field.$1,
              enabled: !busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: field.$2),
            ),
          ),
        if (message != null) Text(message!),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Verifying…' : 'Change password'),
        ),
      ],
    ),
  );
}

class _DeviceAlerts extends ConsumerStatefulWidget {
  const _DeviceAlerts();
  @override
  ConsumerState<_DeviceAlerts> createState() => _DeviceAlertsState();
}

class _DeviceAlertsState extends ConsumerState<_DeviceAlerts> {
  late Future<List<({String id, String label})>> alerts;
  final Set<String> read = {};
  late final String? originalScope;
  String? scope(AuthState auth) {
    final employee = auth.employee, business = auth.activeBusiness;
    return employee == null || business == null
        ? null
        : '${employee.userId}:${business.id}:${employee.membershipId}';
  }

  @override
  void initState() {
    super.initState();
    originalScope = scope(ref.read(authStateProvider));
    alerts = load();
  }

  Future<List<({String id, String label})>> load() async {
    final auth = ref.read(authStateProvider),
        employee = auth.employee,
        business = auth.activeBusiness;
    if (employee == null || business == null)
      throw StateError('Sign in with the original employee.');
    final actorScope = scope(auth);
    if (actorScope == null || actorScope != originalScope) {
      throw StateError('Original account and business required.');
    }
    final prefs = await SharedPreferences.getInstance();
    final readIds = prefs.getStringList('pos_alert_read:$actorScope') ?? [];
    final entries = await (await ref.read(
      offlineCashQueueProvider.future,
    )).entries();
    final pending = await (await ref.read(
      pendingSaleStoreProvider.future,
    )).read();
    if (!mounted || scope(ref.read(authStateProvider)) != originalScope) {
      throw StateError('Account changed during device alert refresh.');
    }
    read
      ..clear()
      ..addAll(readIds);
    return [
      if (pending != null &&
          pending.belongsTo(
            employee.userId,
            business.id,
            employee.membershipId,
          ))
        (
          id: pending.sale.id,
          label:
              'Sale awaiting confirmation. Recover the original request before collecting another payment.',
        ),
      for (final entry in entries)
        if (entry.belongsTo(
              employee.userId,
              business.id,
              employee.membershipId,
            ) &&
            entry.receipt == null)
          (
            id: entry.requestId,
            label:
                'Cash sale pending synchronization. Keep this device and its encrypted queue.',
          ),
    ];
  }

  Future<void> markRead(String id) async {
    final auth = ref.read(authStateProvider),
        e = auth.employee,
        b = auth.activeBusiness;
    if (e == null || b == null || scope(auth) != originalScope) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || scope(ref.read(authStateProvider)) != originalScope) return;
    final next = {...read, id};
    if (await prefs.setStringList(
      'pos_alert_read:${e.userId}:${b.id}:${e.membershipId}',
      next.toList(),
    )) {
      if (mounted && scope(ref.read(authStateProvider)) == originalScope)
        setState(() {
          read.clear();
          read.addAll(next);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (scope(ref.watch(authStateProvider)) != originalScope) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Reopen notifications with the original account and business.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications & recovery'),
        actions: [
          IconButton(
            tooltip: 'Refresh device alerts',
            onPressed: () => setState(() => alerts = load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<({String id, String label})>>(
        future: alerts,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(
              child: Text(
                'Device alerts could not be loaded. Pending transactions remain retained.',
              ),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'These alerts come from this device’s retained transactions. Push notifications have not been configured. Marking an alert read does not clear a sale or payment.',
                ),
              ),
              if (snapshot.data!.isEmpty)
                const ListTile(
                  title: Text(
                    'No pending sales for this employee and business on this device.',
                  ),
                ),
              for (final alert in snapshot.data!)
                ListTile(
                  title: Text(alert.label),
                  subtitle: Text(read.contains(alert.id) ? 'Read' : 'Unread'),
                  onTap: () => markRead(alert.id),
                  trailing: const Icon(Icons.mark_email_read_outlined),
                ),
              ListTile(
                title: const Text('Open recovery & synchronization'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OfflineCashScreen()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
