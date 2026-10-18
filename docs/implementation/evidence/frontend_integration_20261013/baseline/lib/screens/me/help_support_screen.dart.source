import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _emailSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@trexven.com',
      queryParameters: {'subject': 'TREXVEN Support Request'},
    );

    final launched = await launchUrl(uri);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open your email app. Please try again later.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help & Support',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: TrexvenFontSize.section,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _contactCard(context, theme),

            SizedBox(height: TrexvenSpacing.sectionGap),

            Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: TrexvenFontSize.input,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),

            SizedBox(height: 12),

            _faqCard(
              theme,
              children: [
                _faqItem(
                  theme,
                  'How do I add a new camera?',
                  'Go to the appropriate TREXVEN camera or Vision section and add your camera using the supported connection details, such as its RTSP URL or network information.',
                ),
                _divider(theme),
                _faqItem(
                  theme,
                  'What are Vision Server Settings?',
                  'Vision Server Settings connects your TREXVEN app to the TREXVEN Vision AI server. The Vision server processes camera feeds and sends relevant AI detection events back to TREXVEN.',
                ),
                _divider(theme),
                _faqItem(
                  theme,
                  'What is TREXVEN Angel?',
                  'TREXVEN Angel is your AI business assistant. You can ask for help understanding your business, inventory, sales, trends, and other information available to Angel.',
                ),
                _divider(theme),
                _faqItem(
                  theme,
                  'How do I add a product?',
                  'Go to Inventory and use the add product option. You can enter product details manually or use barcode scanning where available.',
                ),
                _divider(theme),
                _faqItem(
                  theme,
                  'How do I manage employees?',
                  'Go to Settings, select Employees, and manage your TREXVEN team from there. Depending on your access level, you can add employees and manage their information.',
                ),
                _divider(theme),
                _faqItem(
                  theme,
                  'How do employee permissions work?',
                  'Employee access is controlled through TREXVEN roles and permissions. The verified owner can review explicit grants and denials under Permissions. Changes take effect on the server.',
                ),
                _divider(theme),
                _faqItem(
                  theme,
                  'How does TREXVEN POS connect to my inventory?',
                  'TREXVEN POS uses the same business and product data as your TREXVEN system. Products available in your inventory can be accessed through the POS according to your business configuration.',
                ),
                _divider(theme),
                _faqItem(
                  theme,
                  'Why is my Vision Server not connecting?',
                  'Check that the Vision Server is running, your server address is correct, and the device running TREXVEN can reach the server. You can also use Vision Server Settings to check the connection status.',
                ),
                _divider(theme),
                _faqItem(
                  theme,
                  'Can I use TREXVEN offline?',
                  'Some locally available features may continue to work temporarily, but syncing business data, cloud services, AI features, and Vision communication may require an internet or network connection.',
                ),
              ],
            ),

            SizedBox(height: TrexvenSpacing.sectionGap),

            Text(
              'Still need help?',
              style: TextStyle(
                fontSize: TrexvenFontSize.input,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),

            SizedBox(height: 8),

            Text(
              'Contact TREXVEN Support and we will help you with your issue.',
              style: TextStyle(
                fontSize: TrexvenFontSize.body,
                color: muted,
                height: 1.5,
              ),
            ),

            SizedBox(height: TrexvenSpacing.fieldGap),

            _supportAction(
              context: context,
              theme: theme,
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: 'Send a message to the TREXVEN support team',
              onTap: () => _emailSupport(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: TrexvenSpacing.pagePadding,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : theme.trexvenColors.brandDark,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
            ),
            child: Icon(
              Icons.support_agent_rounded,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
              size: 40,
            ),
          ),

          SizedBox(height: TrexvenSpacing.fieldGap),

          Text(
            'Need specialized help?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: TrexvenFontSize.section,
              fontWeight: FontWeight.w800,
            ),
          ),

          SizedBox(height: 8),

          Text(
            'Our support team can help you with TREXVEN, your business setup, inventory, POS, and Vision system.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: TrexvenFontSize.body,
              height: 1.5,
            ),
          ),

          SizedBox(height: TrexvenSpacing.sectionGap),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _emailSupport(context),
              icon: Icon(Icons.email_outlined, size: 18),
              label: Text(
                'Email Support',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.trexvenColors.brandDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faqCard(ThemeData theme, {required List<Widget> children}) {
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
      padding: EdgeInsets.only(left: 20),
      child: Divider(
        height: 1,
        thickness: 1,
        color:
            theme.trexvenColors.border?.withValues(alpha: 0.5) ??
            Colors.white12,
      ),
    );
  }

  Widget _faqItem(ThemeData theme, String question, String answer) {
    final muted = theme.trexvenColors.muted!;

    return ExpansionTile(
      tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 20),
      iconColor: theme.colorScheme.primary,
      collapsedIconColor: muted.withValues(alpha: 0.5),
      title: Text(
        question,
        style: TextStyle(
          fontSize: TrexvenFontSize.body,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            answer,
            style: TextStyle(
              fontSize: TrexvenFontSize.body,
              color: muted,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }

  Widget _supportAction({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final muted = theme.trexvenColors.muted!;

    return Material(
      color: theme.trexvenColors.cardBackground,
      borderRadius: BorderRadius.circular(TrexvenRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        child: Container(
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TrexvenRadii.card),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(TrexvenRadii.card),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: TrexvenFontSize.input,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: TrexvenFontSize.caption,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: muted.withValues(alpha: 0.5),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
