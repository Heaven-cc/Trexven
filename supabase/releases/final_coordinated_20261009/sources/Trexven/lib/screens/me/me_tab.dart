import '../../core/app_sizing.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/user_provider.dart';
import '../../services/auth_service.dart';
import '../intelligence/vision_server_screen.dart';
import '../../widgets/trexven_widgets.dart';
import '../welcome_screen.dart';
import 'employment_screen.dart';
import 'profile_screen.dart';
import 'business_profile_screen.dart';
import 'permissions_screen.dart';
import 'notifications_settings_screen.dart';
import 'security_screen.dart';
import 'appearance_screen.dart';
import 'data_backup_screen.dart';
import 'help_support_screen.dart';
import 'about_screen.dart';
import 'billing_screen.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MeTab extends StatelessWidget {
  final String ownerName;
  final String businessName;

  MeTab({super.key, required this.ownerName, required this.businessName});

  final AuthService _auth = AuthService();
  void _showVisionSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VisionServerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final userProvider = context.watch<UserProvider>();

    return SingleChildScrollView(
      padding: AppSizing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Me',
            style: TextStyle(
              fontSize: AppSizing.pageTitle,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 18),
          TrexvenTapCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ProfileScreen(initialName: userProvider.ownerName),
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                  child: Icon(
                    Icons.person_outline,
                    color: theme.colorScheme.primary,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userProvider.ownerName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        userProvider.businessName,
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.trexvenColors.muted?.withOpacity(0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _meSection(
            context,
            title: 'Business & AI',
            children: [
              TrexvenSettingsTile(
                icon: Icons.memory_outlined,
                title: 'Vision Server Settings',
                subtitle: 'Configure Local/Cloud Vision AI Server',
                onTap: () => _showVisionSettings(context),
              ),
              TrexvenSettingsTile(
                icon: Icons.storefront_outlined,
                title: 'Business Profile',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BusinessProfileScreen(),
                  ),
                ),
              ),
              TrexvenSettingsTile(
                icon: Icons.people_outline,
                title: 'Employees',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EmploymentScreen()),
                ),
              ),
              TrexvenSettingsTile(
                icon: Icons.security_outlined,
                title: 'Permissions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PermissionsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _meSection(
            context,
            title: 'Subscription',
            children: [
              _SubscriptionSettings(businessId: userProvider.business?.id),
            ],
          ),
          const SizedBox(height: 20),
          _meSection(
            context,
            title: 'Settings',
            children: [
              TrexvenSettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsSettingsScreen(),
                  ),
                ),
              ),
              TrexvenSettingsTile(
                icon: Icons.lock_outline,
                title: 'Security',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SecurityScreen()),
                ),
              ),
              TrexvenSettingsTile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppearanceScreen()),
                ),
              ),
              TrexvenSettingsTile(
                icon: Icons.cloud_outlined,
                title: 'Data & Backup',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DataBackupScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _meSection(
            context,
            title: 'Support',
            children: [
              TrexvenSettingsTile(
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                ),
              ),
              TrexvenSettingsTile(
                icon: Icons.info_outline,
                title: 'About TREXVEN',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TrexvenTapCard(
            onTap: () async {
              await _auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            padding: EdgeInsets.zero,
            backgroundColor: theme.trexvenColors.error?.withOpacity(0.05),
            child: ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: theme.trexvenColors.error ?? Colors.red,
              ),
              title: Text(
                'Sign Out',
                style: TextStyle(
                  color: theme.trexvenColors.error ?? Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: theme.trexvenColors.muted,
          ),
        ),
        const SizedBox(height: 9),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.trexvenColors.cardBackground,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SubscriptionSettings extends StatefulWidget {
  final String? businessId;
  const _SubscriptionSettings({required this.businessId});
  @override
  State<_SubscriptionSettings> createState() => _SubscriptionSettingsState();
}

class _SubscriptionSettingsState extends State<_SubscriptionSettings> {
  Future<BusinessEntitlements>? subscription;
  void load() {
    final id = widget.businessId;
    subscription = id == null
        ? null
        : BusinessEntitlements.load(
            OperationsClient(Supabase.instance.client, id),
          );
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant _SubscriptionSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<BusinessEntitlements>(
    future: subscription,
    builder: (context, snapshot) => TrexvenSettingsTile(
      icon: Icons.credit_card_outlined,
      title: 'Manage Subscription',
      subtitle: widget.businessId == null
          ? 'Select your business'
          : snapshot.hasError
          ? 'Subscription status unavailable'
          : !snapshot.hasData
          ? 'Loading subscription'
          : snapshot.data!.configured
          ? '${snapshot.data!.plan?.toUpperCase() ?? ''} · ${snapshot.data!.status}'
          : 'No subscription assigned',
      onTap: widget.businessId == null
          ? null
          : () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillingScreen()),
              );
              if (mounted) setState(load);
            },
    ),
  );
}
