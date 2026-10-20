import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trexven_design_system/trexven_design_system.dart';

import '../../core/theme_provider.dart';

/// Owner appearance settings: three device modes plus a separate signature preset.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<ThemeProvider>().appearance;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text('Theme Mode', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Choose how the app looks on this device.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          const SizedBox(height: 16),
          _group(context, [
            _choice(context, selected,
                option: OwnerAppearance.system,
                icon: Icons.brightness_auto_rounded,
                title: 'System Default',
                subtitle: 'Match your device settings'),
            _choice(context, selected,
                option: OwnerAppearance.light,
                icon: Icons.light_mode_outlined,
                title: 'Light Mode',
                subtitle: 'Always use the light theme'),
            _choice(context, selected,
                option: OwnerAppearance.dark,
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                subtitle: 'Pure black appearance'),
          ]),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(child: Text('Signature Theme',
                  style: theme.textTheme.titleMedium)),
              Text('Default',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          _group(context, [
            _choice(context, selected,
                option: OwnerAppearance.trexven,
                logo: true,
                title: null,
                subtitle: 'Deep navy blue with signature accents'),
          ]),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, List<Widget> items) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Divider(height: 1, indent: 76,
                color: theme.colorScheme.outlineVariant),
          items[i],
        ],
      ]),
    );
  }

  Widget _choice(
    BuildContext context,
    OwnerAppearance selected, {
    required OwnerAppearance option,
    required String subtitle,
    String? title,
    IconData? icon,
    bool logo = false,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final active = selected == option;
    return InkWell(
      onTap: () => context.read<ThemeProvider>().setAppearance(option),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: logo
                  ? Image.asset('assets/images/trexven_logo.png',
                      width: 34, height: 34, fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) =>
                          Icon(Icons.auto_awesome, color: colors.primary))
                  : Icon(icon, color: colors.primary, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700)),
                  if (title != null) const SizedBox(height: 3),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(active ? Icons.radio_button_checked : Icons.radio_button_off,
                color: active ? colors.primary : colors.onSurfaceVariant,
                size: 22),
          ],
        ),
      ),
    );
  }
}
