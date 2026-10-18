import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/app_theme.dart';
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
      const SnackBar(
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
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About TREXVEN',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
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
            return Center(
              child: CircularProgressIndicator(color: brandBlue),
            );
          }

          final packageInfo = snapshot.data;

          final version = packageInfo?.version ?? 'Unknown';
          final buildNumber = packageInfo?.buildNumber ?? 'Unknown';

          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                const SizedBox(height: 16),

                // TREXVEN branding
                Center(
                  child: Column(
                    children: [
                      const TrexvenLogo(size: 92),
                      const SizedBox(height: 20),
                      Text(
                        'TREXVEN',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Smart business management',
                        style: TextStyle(
                          fontSize: 14,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // App Information
                Text(
                  'App Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 12),

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

                const SizedBox(height: 28),

                // Updates
                Text(
                  'Updates',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 12),

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

                const SizedBox(height: 28),

                // Legal
                Text(
                  'Legal & Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 12),

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
                          MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
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
                          MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
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
                          applicationVersion:
                          '$version ($buildNumber)',
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                Center(
                  child: Column(
                    children: [
                      Text(
                        'TREXVEN',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '© ${DateTime.now().year} TREXVEN. All rights reserved.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.trexvenColors.muted?.withOpacity(0.5) ?? const Color(0xFF94A3B8),
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

  Widget _settingsCard(
    ThemeData theme, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 72),
      child: Divider(
        height: 1,
        thickness: 1,
        color: theme.trexvenColors.border?.withOpacity(0.5) ?? Colors.white12,
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
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: brandBlue,
            size: 25,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: muted,
            ),
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
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: brandBlue,
              size: 25,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: muted.withOpacity(0.4),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
