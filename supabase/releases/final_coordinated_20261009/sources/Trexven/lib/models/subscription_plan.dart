enum SubscriptionTier { start, core, pro }

class SubscriptionPlan {
  final SubscriptionTier tier;
  final String name;
  final double? price;
  final String? currency;
  final int? intervalMonths;
  final String description;
  final List<String> features;
  final bool isMostPopular;
  const SubscriptionPlan({
    required this.tier,
    required this.name,
    this.price,
    this.currency,
    this.intervalMonths,
    required this.description,
    required this.features,
    this.isMostPopular = false,
  });
  String get priceDisplay => price == null || currency == null
      ? 'Pricing not configured'
      : '$currency ${price!.toStringAsFixed(2)} / ${intervalMonths ?? "?"} month(s)';
  factory SubscriptionPlan.fromJson(Map<String, dynamic> row) =>
      SubscriptionPlan(
        tier: SubscriptionTier.values.byName(row['id'] as String),
        name: row['name'] as String,
        price: row['price'] == null
            ? null
            : num.parse('${row['price']}').toDouble(),
        currency: row['currency'] as String?,
        intervalMonths: row['interval_months'] as int?,
        description: switch (row['id']) {
          'start' => 'POS, inventory and basic reports.',
          'core' => 'Advanced inventory, permissions and analytics.',
          _ => 'Advanced controls, analytics and Vision.',
        },
        features: [
          for (final e in (row['features'] as Map).entries)
            if (e.value == true) e.key.toString().replaceAll('_', ' '),
        ],
      );
}
