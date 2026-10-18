import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/theme_provider.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Appearance',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Text(
            'Theme Mode',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how TREXVEN looks on this device.',
            style: TextStyle(
              fontSize: 13,
              color: muted,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: theme.trexvenColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                _radioItem(
                  context,
                  theme,
                  icon: Icons.brightness_auto_rounded,
                  title: 'System Default',
                  subtitle: 'Match your device settings',
                  mode: ThemeMode.system,
                  provider: themeProvider,
                ),
                _divider(context, theme),
                _radioItem(
                  context,
                  theme,
                  icon: Icons.light_mode_outlined,
                  title: 'Light Mode',
                  subtitle: 'Always use the light theme',
                  mode: ThemeMode.light,
                  provider: themeProvider,
                ),
                _divider(context, theme),
                _radioItem(
                  context,
                  theme,
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark Mode',
                  subtitle: 'Always use the dark theme',
                  mode: ThemeMode.dark,
                  provider: themeProvider,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Preview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          _previewCard(context, theme),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 76),
      child: Divider(
        height: 1,
        color: theme.trexvenColors.border?.withOpacity(0.5) ?? Colors.white12,
      ),
    );
  }

  Widget _radioItem(
      BuildContext context,
      ThemeData theme, {
        required IconData icon,
        required String title,
        required String subtitle,
        required ThemeMode mode,
        required ThemeProvider provider,
      }) {
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return InkWell(
      onTap: () => provider.setThemeMode(mode),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: brandBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: brandBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            Radio<ThemeMode>(
              value: mode,
              groupValue: provider.themeMode,
              activeColor: brandBlue,
              onChanged: (value) {
                if (value != null) {
                  provider.setThemeMode(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewCard(BuildContext context, ThemeData theme) {
    final brandBlue = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: brandBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'TREXVEN',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            color: brandBlue,
          ),
        ],
      ),
    );
  }
}
