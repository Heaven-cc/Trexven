import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../../services/database_service.dart';
import '../../core/app_theme.dart';
import '../../models/subscription_plan.dart';
import '../../widgets/trexven_widgets.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  SubscriptionTier? _currentTier;
  OperationsClient? _api;
  List<SubscriptionPlan> _plans = [];
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic> _subscription = {};
  bool _loading = true, _busy = false;
  String? _error, _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final business = await DatabaseService().getCurrentBusinessId();
      if (business == null)
        throw StateError('Verified owner business required.');
      final api = OperationsClient(Supabase.instance.client, business);
      final plans = await Supabase.instance.client
          .from('subscription_plans')
          .select()
          .eq('active', true)
          .order('rank');
      final subscription = Map<String, dynamic>.from(
        await api.call('get_trexven_entitlements', {'p_business_id': business})
            as Map,
      );
      final history = await api.list('billing_payments');
      if (mounted)
        setState(() {
          _api = api;
          _plans = plans.map((p) => SubscriptionPlan.fromJson(p)).toList();
          _subscription = subscription;
          _history = history;
          _currentTier = subscription['plan'] == null
              ? null
              : SubscriptionTier.values.byName(subscription['plan'] as String);
          _loading = false;
          _error = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error =
              'Billing data unavailable. No plan or price has been assumed.';
        });
    }
  }

  Future<void> _request(String action, {String? plan}) async {
    if (_busy || _api == null) return;
    setState(() => _busy = true);
    try {
      await _api!.call('request_trexven_subscription_change', {
        'p_business_id': _api!.businessId,
        'p_request_id': _api!.requestId(),
        'p_action': action,
        'p_plan_id': plan,
      });
      if (mounted)
        setState(
          () => _message =
              'Request recorded for trusted billing processing. Your plan has not changed and no payment was collected.',
        );
    } catch (e) {
      if (mounted) setState(() => _message = 'Request not confirmed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null)
      return Scaffold(
        appBar: AppBar(title: const Text('Billing & Plans')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Billing & Plans',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Plan Summary
            Text(
              'Current Plan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.surface
                    : theme.trexvenColors.brandDark,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      theme.brightness == Brightness.dark ? 0.3 : 0.2,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentTier == null
                              ? 'Subscription not configured'
                              : _currentTier!.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_subscription['status']} · renewal ${_subscription['renews_at'] ?? "not configured"}\nExpires ${_subscription['expires_at'] ?? "not configured"}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            Text(
              'Upgrade your business',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a plan that scales with your growth.',
              style: TextStyle(fontSize: 14, color: muted),
            ),
            const SizedBox(height: 24),

            // Plan Cards
            if (_message != null) Text(_message!),
            ..._plans.map(
              (plan) => _buildPlanCard(theme, plan, plan.tier == _currentTier),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _request('cancel'),
              child: const Text('Request subscription cancellation'),
            ),
            Text(
              'Employee limit ${_subscription['employee_limit'] ?? "not configured"} · camera limit ${_subscription['camera_limit'] ?? "not configured"}',
            ),
            OutlinedButton(
              onPressed: _api == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountOperationsScreen(api: _api!),
                      ),
                    ),
              child: const Text('Account, recovery and operational status'),
            ),
            const SizedBox(height: 16),
            Text('Billing history', style: theme.textTheme.titleMedium),
            if (_history.isEmpty)
              const Text('No verified billing transactions.'),
            for (final payment in _history)
              ListTile(
                title: Text(
                  '${payment['currency']} ${payment['amount']} · ${payment['status']}',
                ),
                subtitle: Text(
                  '${payment['verified_at'] ?? "Verification pending"}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    ThemeData theme,
    SubscriptionPlan plan,
    bool isCurrent,
  ) {
    final bool isHigher = plan.tier.index > (_currentTier?.index ?? -1);
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final cardBg = theme.trexvenColors.cardBackground;
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: plan.isMostPopular
              ? brandBlue
              : (theme.trexvenColors.border ?? const Color(0xFFE2E8F0)),
          width: plan.isMostPopular ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.isMostPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: brandBlue,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
              ),
              child: const Text(
                'MOST POPULAR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: onSurface,
                      ),
                    ),
                    Text(
                      plan.priceDisplay,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: brandBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  plan.description,
                  style: TextStyle(fontSize: 13, color: muted),
                ),
                const SizedBox(height: 24),
                Divider(
                  height: 1,
                  color:
                      theme.trexvenColors.border?.withOpacity(0.5) ??
                      Colors.white12,
                ),
                const SizedBox(height: 20),
                ...plan.features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: theme.trexvenColors.success ?? Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TrexvenButton(
                  text: isCurrent
                      ? 'Current Plan'
                      : (isHigher ? 'Upgrade' : 'Downgrade'),
                  onPressed: isCurrent || _busy
                      ? null
                      : () => _request('change_plan', plan: plan.tier.name),
                  backgroundColor: isCurrent
                      ? theme.colorScheme.onSurface.withOpacity(0.05)
                      : (plan.isMostPopular
                            ? brandBlue
                            : (theme.brightness == Brightness.dark
                                  ? theme.colorScheme.surface
                                  : theme.trexvenColors.brandDark)),
                  foregroundColor: isCurrent
                      ? theme.trexvenColors.muted
                      : Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
