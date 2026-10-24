/// Central Google Play Billing activation guard.
///
/// Never switch this on until Play Console products, verified backend purchase
/// processing, RTDN, refunds, acknowledgements and internal testing are ready.
/// Compile-time gate prevents accidental live checkout during development.
class TrexvenPlayBilling {
  const TrexvenPlayBilling._();

  static const bool activated = bool.fromEnvironment(
    'TREXVEN_PLAY_BILLING_ACTIVE',
    defaultValue: false,
  );
  static const String coreProductId = 'trexven_core';
  static const String proProductId = 'trexven_pro';

  static const Map<String, String> basePlans = {
    'core_monthly': 'monthly',
    'core_yearly': 'yearly',
    'pro_monthly': 'monthly',
    'pro_yearly': 'yearly',
    'pro_intro_7d': 'intro-7d',
  };

  static bool canPurchase({
    required String tier,
    required bool pricingAvailable,
    required bool backendActivated,
  }) =>
      activated &&
      backendActivated &&
      pricingAvailable &&
      (tier == 'core' || tier == 'pro');
}
