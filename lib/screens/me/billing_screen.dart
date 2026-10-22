
import 'dart:ui';
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
  int _billingMonths = 1;
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0D172B) : const Color(0xFFF2F9FF),
        body: Stack(children: [
          _billingBackdrop(),
          SafeArea(
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
                _managementSection(),
                 const SizedBox(height: 14),
                 if (_subscription['intro_offer_eligible'] == true && _subscription['plan'] != 'pro') ...[
                   _introOffer(),
                   const SizedBox(height: 14),
                 ],
                 Text('Explore other plans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                 const SizedBox(height: 10),
                 _cycleSelector(),
                 const SizedBox(height: 14),
                 for (final tier in ['start', 'core', 'pro'])
                   if (tier != _subscription['plan']) ...[
                     _cycleCard(tier, _label(tier), tier == 'start' ? 'Your business essentials' : tier == 'core' ? 'Smart business growth' : 'Complete business intelligence', popular: tier == 'core'),
                     const SizedBox(height: 12),
                   ],
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
        ]),
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
      options: [_option(selectedOption: true, title: tier == 'start' ? 'Free' : _countryPricingAvailable ? (_planFor(tier, _billingMonths)?.priceDisplay ?? 'Price unavailable') : 'Price unavailable', subtitle: tier == 'start' ? 'No charge' : _billingMonths == 1 ? 'Billed monthly' : 'Billed yearly')],
      features: _approvedFeatures(tier),
      buttonLabel: tier == 'start' ? 'Start plan · Coming soon' : 'Choose $name · Coming soon',
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
  }) => _glass(Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Expanded(child: Text(name, style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface))),
        if (popular) _pill('MOST POPULAR'),
      ]),
      const SizedBox(height: 5),
      Text(description, style: TextStyle(fontSize: 12, color: muted)),
      const SizedBox(height: 10),
      ...options,
      if (footer != null) footer,
      const SizedBox(height: 8),
      Divider(color: border.withValues(alpha: .30)),
      const SizedBox(height: 3),
      for (final feature in features)
        Padding(padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.check_rounded, size: 17, color: Color(0xFF21966B)),
            const SizedBox(width: 8),
            Expanded(child: Text(feature, style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12, height: 1.4))),
          ])),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton(
        onPressed: null,
        child: Text(buttonLabel))),
      const SizedBox(height: 6),
      Center(child: Text('Google Play checkout is not connected yet.',
        style: TextStyle(fontSize: 10, color: muted))),
    ],
  ), highlight: popular);

  Widget _option({
    required bool selectedOption,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: TextStyle(fontSize: 18,
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w800)),
    const SizedBox(height: 3),
    Text(subtitle, style: TextStyle(color: muted, fontSize: 11)),
  ]);

  Widget _managementSection() {
    final tier = _subscription['plan']?.toString().toLowerCase();
    final status = _subscription['status']?.toString().toLowerCase() ?? '';
    final canCancel = _configured && status != 'expired' && status != 'canceled';
    return _glass(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('CURRENT SUBSCRIPTION', style: TextStyle(color: muted, fontSize: 11, letterSpacing: .7, fontWeight: FontWeight.w800))), if (_configured) _pill(_label(status))]),
      const SizedBox(height: 12),
      Text(tier == null ? 'Plan unavailable' : _label(tier), style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
      const SizedBox(height: 5),
      Text(tier == 'start' ? 'Your everyday business essentials' : tier == 'core' ? 'Smart business growth' : tier == 'pro' ? 'Complete multi-shop intelligence' : 'Subscription details unavailable', style: TextStyle(fontSize: 12, color: muted)),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 6, children: [for (final item in tier == 'start' ? ['1 shop', 'POS', 'Employees', 'Alerts'] : tier == 'core' ? ['2 shops', '4 cameras', 'Vision'] : tier == 'pro' ? ['Multiple shops', '10 cameras', 'AI Live'] : <String>[]) _pill(item)]),
      const Divider(),
      Text(tier == 'start' ? 'Free' : _label(status), style: const TextStyle(fontWeight: FontWeight.w700)),
      if (_subscription['renews_at'] != null) Text('Renews: '+_date(_subscription['renews_at']), style: TextStyle(color: muted, fontSize: 12)),
      if (_subscription['expires_at'] != null) Text('Expires: '+_date(_subscription['expires_at']), style: TextStyle(color: muted, fontSize: 12)),
      if (canCancel) TextButton(onPressed: _busy ? null : _cancel, child: Text(_busy ? 'Sending request…' : 'Request cancellation')),
      if (_api != null) TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountOperationsScreen(api: _api!))), child: const Text('Account requests and recovery')),
    ]));
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

  Widget _pill(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: blue.withValues(alpha: .10), border: Border.all(color: blue.withValues(alpha: .2)), borderRadius: BorderRadius.circular(30)), child: Text(text, style: TextStyle(color: blue, fontSize: 10, fontWeight: FontWeight.w700)));

  Widget _billingBackdrop() {
    Widget orb(Color color, double n) => ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: Container(width: n, height: n, decoration: BoxDecoration(shape: BoxShape.circle, color: color)));
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(child: IgnorePointer(child: ClipRect(child: Stack(children: [
      Positioned(left: -95, top: -95, child: orb(dark ? const Color(0xA82B5795) : const Color(0xB096CEFF), 280)),
      Positioned(right: -120, top: 260, child: orb(dark ? const Color(0x85385993) : const Color(0x99A3C3FF), 310)),
      Positioned(left: -90, bottom: 0, child: orb(dark ? const Color(0x70377091) : const Color(0x808DE1F0), 280)),
    ]))));
  }

  Widget _glass(Widget child, {bool highlight = false}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(borderRadius: BorderRadius.circular(20), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: dark ? const Color(0xC4263854) : const Color(0xB8FFFFFF), borderRadius: BorderRadius.circular(20), border: Border.all(color: highlight ? blue.withValues(alpha: .5) : Colors.white.withValues(alpha: dark ? .12 : .84)), boxShadow: [BoxShadow(color: blue.withValues(alpha: .07), blurRadius: 23, offset: const Offset(0, 7))]), child: child)));
  }

  Widget _cycleSelector() => Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: blue.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)), child: Row(children: [for (final months in [1, 12]) Expanded(child: InkWell(onTap: () => setState(() => _billingMonths = months), borderRadius: BorderRadius.circular(11), child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(vertical: 11), decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), color: _billingMonths == months ? blue : Colors.transparent), alignment: Alignment.center, child: Text(months == 1 ? 'Monthly' : 'Yearly', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _billingMonths == months ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface)))))]));
  
  Widget _introOffer() => _glass(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _pill('✦ SPECIAL OFFER'), const SizedBox(height: 10),
    Text('7-Day Pro Access', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
    const SizedBox(height: 5), Text('One introductory payment for seven days of Pro features.', style: TextStyle(fontSize: 12, color: muted)),
    const SizedBox(height: 12), Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Google Play price', style: TextStyle(fontWeight: FontWeight.w700)),
        Text('No automatic renewal', style: TextStyle(color: muted, fontSize: 11)),
      ])), const OutlinedButton(onPressed: null, child: Text('Coming soon')),
    ]),
  ]), highlight: true);

  List<String> _approvedFeatures(String tier) => switch (tier) {
    'start' => ['1 shop · POS and employees', 'Inventory, sales, expenses, credit and returns', 'Operational alerts and basic reports'],
    'core' => ['Everything in Start', '2 shops · 4 cameras, expandable', 'TREXVEN Intelligence and Vision', 'Advanced reports and price levels'],
    _ => ['Everything in Core', 'Multiple shops · 10 cameras, expandable', 'Detailed activity and AI Live', 'Early access to updates'],
  };

  Widget _darkSection({required String title, required List<Widget> children}) => _glass(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)), const SizedBox(height: 12), ...children]));

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
