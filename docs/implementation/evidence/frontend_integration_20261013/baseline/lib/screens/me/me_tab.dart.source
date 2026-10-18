import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/user_provider.dart';
import '../../services/auth_service.dart';
import '../intelligence/vision_server_screen.dart';
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
      MaterialPageRoute(builder: (_) => VisionServerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted!;
    final userProvider = context.watch<UserProvider>();

    return SingleChildScrollView(
      padding: TrexvenSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Me',
            style: TextStyle(
              fontSize: TrexvenSpacing.pageTitle,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: TrexvenSpacing.fieldGap),
          TrexvenTapCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ProfileScreen(initialName: userProvider.ownerName),
              ),
            ),
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.08,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: theme.colorScheme.primary,
                    size: 29,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userProvider.ownerName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: TrexvenFontSize.section,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        userProvider.businessName,
                        style: TextStyle(
                          color: muted,
                          fontSize: TrexvenFontSize.body,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.trexvenColors.muted?.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          SizedBox(height: TrexvenSpacing.sectionGap),
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
                  MaterialPageRoute(builder: (_) => BusinessProfileScreen()),
                ),
              ),
              TrexvenSettingsTile(
                icon: Icons.people_outline,
                title: 'Employees',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EmploymentScreen()),
                ),
              ),
              TrexvenSettingsTile(
                icon: Icons.security_outlined,
                title: 'Permissions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PermissionsScreen()),
                ),
              ),
            ],
          ),
          SizedBox(height: TrexvenSpacing.fieldGap),
          _meSection(
            context,
            title: 'Subscription',
            children: [
              _SubscriptionSettings(businessId: userProvider.business?.id),
            ],
          ),
          SizedBox(height: TrexvenSpacing.fieldGap),
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
                    builder: (_) => NotificationsSettingsScreen(),
                  ),
                ),
              ),
              TrexvenSettingsTile(
                icon: Icons.lock_outline,
                title: 'Security',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SecurityScreen()),
                ),
              ),
              TrexvenSettingsTile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AppearanceScreen()),
                ),
              ),
              TrexvenSettingsTile(
                icon: Icons.cloud_outlined,
                title: 'Data & Backup',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DataBackupScreen()),
                ),
              ),
            ],
          ),
          SizedBox(height: TrexvenSpacing.fieldGap),
          _meSection(
            context,
            title: 'Support',
            children: [
              TrexvenSettingsTile(
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HelpSupportScreen()),
                ),
              ),
              TrexvenSettingsTile(
                icon: Icons.info_outline,
                title: 'About TREXVEN',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AboutScreen()),
                ),
              ),
            ],
          ),
          SizedBox(height: TrexvenSpacing.fieldGap),
          TrexvenTapCard(
            onTap: () async {
              await _auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            padding: EdgeInsets.zero,
            backgroundColor: theme.trexvenColors.error?.withValues(alpha: 0.05),
            child: ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: theme.trexvenColors.error!,
              ),
              title: Text(
                'Sign Out',
                style: TextStyle(
                  color: theme.trexvenColors.error!,
                  fontWeight: FontWeight.w600,
                  fontSize: TrexvenFontSize.body,
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
            fontSize: TrexvenFontSize.body,
            fontWeight: FontWeight.w700,
            color: theme.trexvenColors.muted,
          ),
        ),
        SizedBox(height: 9),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.trexvenColors.cardBackground,
            borderRadius: BorderRadius.circular(TrexvenRadii.card),
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
      trailing: snapshot.hasData && snapshot.data!.configured
          ? Text(
              CustomerPresentation.label(snapshot.data!.plan),
              style: Theme.of(context).textTheme.labelLarge,
            )
          : null,
      subtitle: widget.businessId == null
          ? 'Select your business'
          : snapshot.hasError
          ? 'Subscription status unavailable'
          : !snapshot.hasData
          ? 'Loading subscription'
          : snapshot.data!.configured
          ? CustomerPresentation.label(snapshot.data!.status)
          : 'No active subscription',
      onTap: widget.businessId == null
          ? null
          : () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BillingScreen()),
              );
              if (mounted) setState(load);
            },
    ),
  );
}
