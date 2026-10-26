import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../widgets/trexven_logo.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  Future<void> _checkForUpdates() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Update checking will be available when the TREXVEN update service is configured.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'About TREXVEN',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: TrexvenFontSize.section,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: FutureBuilder<PackageInfo>(
        future: _packageInfoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Text('Loading…'));
          }

          final packageInfo = snapshot.data;

          final version = packageInfo?.version ?? 'Unknown';
          final buildNumber = packageInfo?.buildNumber ?? 'Unknown';

          return SafeArea(
            top: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                SizedBox(height: TrexvenSpacing.fieldGap),

                // TREXVEN branding
                Center(
                  child: Column(
                    children: [
                      TrexvenLogo(size: 92),
                      SizedBox(height: TrexvenSpacing.fieldGap),
                      Text(
                        'TREXVEN',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.title,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Smart business management',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.body,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 40),

                // App Information
                Text(
                  'App Information',
                  style: TextStyle(
                    fontSize: TrexvenFontSize.input,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                SizedBox(height: 12),

                _settingsCard(
                  theme,
                  children: [
                    _infoRow(
                      theme,
                      icon: Icons.info_outline_rounded,
                      title: 'Version',
                      value: version,
                    ),
                    _divider(theme),
                    _infoRow(
                      theme,
                      icon: Icons.build_outlined,
                      title: 'Build',
                      value: buildNumber,
                    ),
                  ],
                ),

                SizedBox(height: TrexvenSpacing.sectionGap),

                // Updates
                Text(
                  'Updates',
                  style: TextStyle(
                    fontSize: TrexvenFontSize.input,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                SizedBox(height: 12),

                _settingsCard(
                  theme,
                  children: [
                    _actionRow(
                      theme,
                      icon: Icons.system_update_alt_rounded,
                      title: 'Check for Updates',
                      subtitle: 'Check if a newer version is available',
                      onTap: _checkForUpdates,
                    ),
                  ],
                ),

                SizedBox(height: TrexvenSpacing.sectionGap),

                // Legal
                Text(
                  'Legal & Information',
                  style: TextStyle(
                    fontSize: TrexvenFontSize.input,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                SizedBox(height: 12),

                _settingsCard(
                  theme,
                  children: [
                    _actionRow(
                      theme,
                      icon: Icons.description_outlined,
                      title: 'Terms of Service',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TermsOfServiceScreen(),
                          ),
                        );
                      },
                    ),
                    _divider(theme),
                    _actionRow(
                      theme,
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PrivacyPolicyScreen(),
                          ),
                        );
                      },
                    ),
                    _divider(theme),
                    _actionRow(
                      theme,
                      icon: Icons.code_rounded,
                      title: 'Open Source Licenses',
                      onTap: () {
                        showLicensePage(
                          context: context,
                          applicationName: 'TREXVEN',
                          applicationVersion: '$version ($buildNumber)',
                        );
                      },
                    ),
                  ],
                ),

                SizedBox(height: 48),

                Center(
                  child: Column(
                    children: [
                      Text(
                        'TREXVEN',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.body,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: muted,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '© ${DateTime.now().year} TREXVEN. All rights reserved.',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.caption,
                          color:
                              theme.trexvenColors.muted?.withValues(
                                alpha: 0.5,
                              ) ??
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _settingsCard(ThemeData theme, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(left: 72),
      child: Divider(
        height: 1,
        thickness: 1,
        color:
            theme.trexvenColors.border?.withValues(alpha: 0.5) ??
            Colors.white12,
      ),
    );
  }

  Widget _infoRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted!;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Icon(icon, color: brandBlue, size: 25),
          SizedBox(width: 18),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: TrexvenFontSize.input,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: TrexvenFontSize.body, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TrexvenRadii.card),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: brandBlue, size: 25),
            SizedBox(width: 18),
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
                  if (subtitle != null) ...[
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: TrexvenFontSize.body,
                        color: muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: muted.withValues(alpha: 0.4),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
