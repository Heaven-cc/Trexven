import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import '../auth/auth_provider.dart';
import '../auth/branch_context.dart';
import '../auth/permission_service.dart';
import '../inventory/product_detail_screen.dart';
import '../inventory/product_search_screen.dart';
import '../inventory/quick_add_screen.dart';
import '../inventory/scanner_screen.dart';
import 'cart_provider.dart';
import 'checkout_screen.dart';
import 'recent_sales_screen.dart';
import 'operations_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const Color _primaryBlue = Color(0xFF2F66B0);
  static const Color _background = Color(0xFFF2F2F7);
  static const Color _secondaryText = Color(0xFF8E8E93);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final cart = ref.watch(cartProvider);

    final business = authState.activeBusiness;
    final employee = authState.employee;
    final access = ref.watch(permissionServiceProvider);

    final cartTotal = ref.watch(cartProvider.notifier).total;

    final cartItemCount = cart.fold<num>(
      0,
          (total, item) => total + item.quantity,
    );

    return Scaffold(
      appBar: business?.branchesEnabled == true ? AppBar(
        title: Text(ref.watch(branchContextProvider)?.name ?? 'Select branch'),
        actions: [TextButton(onPressed: () {
          try {
            ref.read(branchContextProvider.notifier).clear(hasCart: cart.isNotEmpty);
            ref.invalidate(authorizedBranchesProvider);
          } on StateError catch (error) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
          }
        }, child: const Text('Change branch'))],
      ) : null,
      backgroundColor: _background,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        _DashboardHeader(
                          businessName:
                          business?.name ?? 'Trexven POS',
                          employeeName:
                          employee?.name ?? 'Employee',
                          employeeRole:
                          employee?.role.name ?? 'Employee',
                          onLogout: () {
                            _showLogoutDialog(context, ref);
                          },
                        ),

                        const SizedBox(height: 24),

                        OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PosOperationsScreen())),icon:const Icon(Icons.tune),label:const Text('Operational workflows')),
                        const _SectionHeader(
                          title: 'Quick Actions',
                          subtitle: 'Start a sale or manage products',
                        ),

                        const SizedBox(height: 14),

                        _PrimaryAction(
                          title: 'Scan Product',
                          subtitle:
                          'Scan a barcode to find a product instantly',
                          onTap: () async {
                            final product =
                            await Navigator.push<Product>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                const ScannerScreen(),
                              ),
                            );

                            if (product != null && context.mounted) {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProductDetailScreen(
                                        product: product,
                                      ),
                                ),
                              );
                            }
                          },
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.search_rounded,
                                title: 'Search',
                                subtitle: 'Find product',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                      const ProductSearchScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.history_rounded,
                                title: 'Sales',
                                subtitle: 'Sale history',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                      const RecentSalesScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        if (access.canQuickAddProduct) _QuickAddAction(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                const QuickAddScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (cart.isNotEmpty && access.canCompleteSales)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _CheckoutBar(
                  itemCount: cartItemCount,
                  total: cartTotal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CheckoutScreen(),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(
      BuildContext context,
      WidgetRef ref,
      ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Sign Out',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Are you sure you want to sign out of Trexven POS?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: _secondaryText,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                await ref
                    .read(authStateProvider.notifier)
                    .logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String businessName;
  final String employeeName;
  final String employeeRole;
  final VoidCallback onLogout;

  const _DashboardHeader({
    required this.businessName,
    required this.employeeName,
    required this.employeeRole,
    required this.onLogout,
  });

  static const Color _primaryText = Color(0xFF1C1C1E);
  static const Color _secondaryText = Color(0xFF6B6B70);
  static const Color _tertiaryText = Color(0xFF8E8E93);
  static const Color _separator = Color(0xFFE5E5EA);

  String _formatRole(String value) {
    if (value.isEmpty) return 'Employee';

    return value
        .split('_')
        .map(
          (word) =>
      '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
    )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _secondaryText,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Hello, $employeeName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${_formatRole(employeeRole)} • Trexven POS',
                style: const TextStyle(
                  fontSize: 13,
                  color: _tertiaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onLogout,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _separator,
                ),
              ),
              child: const Icon(
                Icons.power_settings_new_rounded,
                color: _primaryText,
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  static const Color _primaryText = Color(0xFF1C1C1E);
  static const Color _secondaryText = Color(0xFF8E8E93);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: _primaryText,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: _secondaryText,
          ),
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PrimaryAction({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const Color _primaryBlue = Color(0xFF2F66B0);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _primaryBlue,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const Color _primaryBlue = Color(0xFF2F66B0);
  static const Color _primaryText = Color(0xFF1C1C1E);
  static const Color _secondaryText = Color(0xFF8E8E93);
  static const Color _separator = Color(0xFFE5E5EA);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _separator,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: _primaryBlue,
                  size: 23,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: _primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAddAction extends StatelessWidget {
  final VoidCallback onTap;

  const _QuickAddAction({
    required this.onTap,
  });

  static const Color _primaryBlue = Color(0xFF2F66B0);
  static const Color _primaryText = Color(0xFF1C1C1E);
  static const Color _secondaryText = Color(0xFF8E8E93);
  static const Color _separator = Color(0xFFE5E5EA);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _separator,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FB),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.add_box_outlined,
                  color: _primaryBlue,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Add Product',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Add a product to your inventory',
                      style: TextStyle(
                        color: _secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  final num itemCount;
  final double total;
  final VoidCallback onTap;

  const _CheckoutBar({
    required this.itemCount,
    required this.total,
    required this.onTap,
  });

  static const Color _primaryBlue = Color(0xFF2F66B0);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      shadowColor: Colors.black.withOpacity(0.18),
      borderRadius: BorderRadius.circular(22),
      color: _primaryBlue,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 15,
          ),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$itemCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'View Cart',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '₦${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
