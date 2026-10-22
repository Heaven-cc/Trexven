
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';

import '../../services/database_service.dart';
import '../../models/subscription_plan.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  Color get bg => Theme.of(context).scaffoldBackgroundColor;
  Color get card => Theme.of(context).colorScheme.surface;
  Color get border => Theme.of(context).colorScheme.outlineVariant;
  Color get blue => Theme.of(context).colorScheme.primary;
  Color get selected => blue.withValues(alpha: .14);
  Color get muted => Theme.of(context).colorScheme.onSurfaceVariant;

  OperationsClient? _api;
  List<SubscriptionPlan> _plans = [];
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic> _subscription = {};

  bool _loading = false;
  bool _busy = false;
  final Map<String, int> _cycles = {'start': 1, 'core': 1, 'pro': 12};
  String? _billingCountry;
  bool _countryPricingAvailable = false;

  String? _error;
  String? _message;


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final businessId =
      await DatabaseService().requireBusinessId();

      final api = OperationsClient(
        Supabase.instance.client,
        businessId,
      );

      final rows = await Supabase.instance.client
          .from('subscription_plans')
          .select(
        'id,name,price,currency,interval_months,features',
      )
          .eq('active', true)
          .order('rank');

      // An older backend can still supply features/history, but global plan
      // prices must never masquerade as country-specific commercial settings.
      Map<String, dynamic>? catalog;
      try {
        final result = await Supabase.instance.client.rpc(
          'get_trexven_country_billing_catalog',
          params: {'p_business_id': businessId},
        );
        catalog = Map<String, dynamic>.from(result as Map);
      } on PostgrestException catch (error) {
        if (error.code != 'PGRST202') rethrow;
      }

      final entitlement = await api.call(
        'get_trexven_entitlements',
        {'p_business_id': businessId},
      );

      final payments = await api.list('billing_payments');

      if (!mounted) return;

      setState(() {
        _api = api;
        _plans = ((catalog?['plans'] ?? rows) as List)
            .map(
              (r) => SubscriptionPlan.fromJson(
            {...Map<String, dynamic>.from(r as Map),
              if (catalog == null) 'price': null},
          ),
        )
            .toList();

        _subscription =
        Map<String, dynamic>.from(entitlement as Map);
        _history = payments;

        _billingCountry = catalog?['country_name'] as String?;
        _countryPricingAvailable = catalog?['country_code'] != null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
          'Unable to load billing information. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _label(dynamic value) {
    final text = '${value ?? ''}'.replaceAll('_', ' ').trim();
    if (text.isEmpty) return '—';
    return text[0].toUpperCase() + text.substring(1);
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return '—';
    final d = parsed.toLocal();
    return '${d.day}/${d.month}/${d.year}';
  }

  String _money(dynamic amount, String? currency) {
    final value = num.tryParse('$amount');
    if (value == null) return '—';
    final symbol = switch ((currency ?? '').toUpperCase()) {
      'NGN' => '₦',
      'USD' => '\$',
      'GBP' => '£',
      'EUR' => '€',
      _ => '${currency ?? ''} ',
    };
    return '$symbol${value.toStringAsFixed(2)}';
  }

  SubscriptionPlan? _planFor(String tier, int months) {
    for (final plan in _plans) {
      if (plan.tier.name.toLowerCase() == tier &&
          plan.intervalMonths == months) {
        return plan;
      }
    }
    return null;
  }

  List<String> _features(String tier) {
    for (final plan in _plans) {
      if (plan.tier.name.toLowerCase() == tier) {
        return plan.features;
      }
    }
    return [];
  }

  bool get _configured =>
      _subscription['configured'] == true;

  Future<void> _cancel() async {
    if (_busy || _api == null || !_configured) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Request cancellation?'),
        content: Text(
          'Your cancellation request will be recorded '
              'for review. Your plan stays unchanged until processed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep plan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Request cancellation'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    try {
      await _api!.call(
        'request_trexven_subscription_change',
        {
          'p_business_id': _api!.businessId,
          'p_request_id': _api!.requestId(),
          'p_action': 'cancel',
          'p_plan_id': null,
        },
      );

      if (mounted) {
        setState(() {
          _message =
          'Cancellation request received for review.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message =
          'Cancellation was not confirmed. Check your '
              'subscription before trying again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Billing & Plans')),
        backgroundColor: bg,
        body: SafeArea(
          child: _loading
              ? const Center(child: TrexvenLoading())
              : _error != null
              ? _errorView()
              : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                20, 18, 20, 36,
              ),
              children: [
                const SizedBox(height: 10),
                Text(
                  'Get more TREXVEN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Choose the plan right for your business',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _countryPricingAvailable
                      ? 'Prices for $_billingCountry. Checkout is not available yet.'
                      : 'Country pricing is not available yet. Checkout is unavailable.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _managementSection(),
                const SizedBox(height: 28),
                _startCard(),
                const SizedBox(height: 22),
                _coreCard(),
                const SizedBox(height: 22),
                _proCard(),
                const SizedBox(height: 24),
                _historySection(),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const TermsOfServiceScreen(),
                      )),
                      child: const Text('Terms of Service'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      )),
                      child: const Text('Privacy Policy'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _startCard() => _cycleCard(
    'start', 'Start', 'Everything you need to get started',
  );

  Widget _coreCard() => _cycleCard(
    'core', 'Core', 'More control. Better business insights.', popular: true,
  );

  Widget _proCard() => _cycleCard(
    'pro', 'Pro', 'The complete TREXVEN experience',
  );

  Widget _cycleCard(String tier, String name, String description, {
    bool popular = false,
  }) {
    return _planCard(
      name: name,
      description: description,
      popular: popular,
      options: [
        for (final months in [1, 12])
          _option(
            selectedOption: _cycles[tier] == months,
            title: _planFor(tier, months)?.priceDisplay ?? 'Price unavailable',
            subtitle: months == 1 ? 'Billed monthly' : 'Billed annually',
            onTap: () => setState(() => _cycles[tier] = months),
          ),
      ],
      features: _features(tier),
      buttonLabel: 'Get $name plan',
    );
  }

  Widget _planCard({
    required String name,
    required String description,
    required List<Widget> options,
    required List<String> features,
    required String buttonLabel,
    bool popular = false,
    Widget? footer,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (popular)
                      Text(
                        'POPULAR',
                        style: TextStyle(
                          color: blue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < options.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: options[i]),
                    ],
                  ],
                ),
                if (footer != null) ...[
                  const SizedBox(height: 12),
                  footer,
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.onSurface,
                      disabledBackgroundColor:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: .75),
                      disabledForegroundColor:
                      Colors.black87,
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(buttonLabel),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Checkout is not available yet.',
                  style: TextStyle(
                    fontSize: 10,
                    color: muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: border,
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Included with $name:',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 15),
                if (features.isEmpty)
                  Text(
                    'Features unavailable',
                    style: TextStyle(color: muted),
                  ),
                for (final feature in features)
                  Padding(
                    padding:
                    const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 19,
                          color: muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
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
    );
  }

  Widget _option({
    required bool selectedOption,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 145,
        ),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selectedOption ? selected : card,
          border: Border.all(
            color: selectedOption ? blue : border,
          ),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Icon(
              selectedOption
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selectedOption ? blue : muted,
              size: 25,
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: muted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _managementSection() {
    final status =
    '${_subscription['status'] ?? ''}'.toLowerCase();

    final canCancel = _configured &&
        status != 'expired' &&
        status != 'canceled';

    return _darkSection(
      title: 'Manage Subscription',
      children: [
        if (_configured) ...[
          Text(
            'Current plan',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _label(_subscription['plan']),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _label(_subscription['status']),
            style: TextStyle(
              color: muted,
              fontSize: 12,
            ),
          ),
        ] else ...[
          Text(
            'No active subscription',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
            ),
          ),
        ],
        if (_subscription['renews_at'] != null)
          Text(
            'Renews: ${_date(_subscription['renews_at'])}',
            style: TextStyle(color: muted),
          ),
        if (_subscription['expires_at'] != null)
          Text(
            'Expires: ${_date(_subscription['expires_at'])}',
            style: TextStyle(color: muted),
          ),
        if (canCancel) ...[
          const SizedBox(height: 14),
          TextButton(
            onPressed: _busy ? null : _cancel,
            child: Text(
              _busy
                  ? 'Sending request…'
                  : 'Request cancellation',
            ),
          ),
        ],
        if (_api != null)
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AccountOperationsScreen(api: _api!),
                ),
              );
            },
            child: Text(
              'Account requests and recovery',
            ),
          ),
      ],
    );
  }

  Widget _historySection() {
    return _darkSection(
      title: 'Billing History',
      children: [
        if (_history.isEmpty)
          Text(
            'No billing payments yet.',
            style: TextStyle(color: muted),
          ),
        for (final payment in _history)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _money(
                payment['amount'],
                payment['currency'] as String?,
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              _date(payment['verified_at']),
              style: TextStyle(
                color: muted,
                fontSize: 11,
              ),
            ),
            trailing: Text(
              _label(payment['status']),
              style: TextStyle(
                color: muted,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  Widget _darkSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _load,
            child: Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class BillingPlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool current;

  const BillingPlanCard({
    super.key,
    required this.plan,
    this.current = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF1E293B) : Colors.white;
    final selected = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEBF2FF);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: current ? selected : card,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (current)
                Text(
                  'Current plan',
                  style: TextStyle(
                    color: Color(0xFF5A9BFA),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.description,
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final feature in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.check_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(feature, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
