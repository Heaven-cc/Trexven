import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
const HelpSupportScreen({super.key});

Future<void> _emailSupport(BuildContext context) async {
final uri = Uri(
scheme: 'mailto',
path: 'support@trexven.com',
queryParameters: {
'subject': 'TREXVEN Support Request',
},
);

final launched = await launchUrl(uri);

if (!launched && context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
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
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            _contactCard(context, theme),

            const SizedBox(height: 32),

            Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 12),

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

            const SizedBox(height: 32),

            Text(
              'Still need help?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Contact TREXVEN Support and we will help you with your issue.',
              style: TextStyle(
                fontSize: 13,
                color: muted,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 16),

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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark 
            ? theme.colorScheme.surface 
            : theme.trexvenColors.brandDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.support_agent_rounded,
              color: theme.colorScheme.primaryContainer.withOpacity(0.9),
              size: 40,
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Need specialized help?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Our support team can help you with TREXVEN, your business setup, inventory, POS, and Vision system.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _emailSupport(context),
              icon: const Icon(Icons.email_outlined, size: 18),
              label: const Text(
                'Email Support',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.trexvenColors.brandDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faqCard(
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
      padding: const EdgeInsets.only(left: 20),
      child: Divider(
        height: 1,
        thickness: 1,
        color: theme.trexvenColors.border?.withOpacity(0.5) ?? Colors.white12,
      ),
    );
  }

  Widget _faqItem(ThemeData theme, String question, String answer) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Theme(
      data: theme.copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 4,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20,
        ),
        iconColor: theme.colorScheme.primary,
        collapsedIconColor: muted.withOpacity(0.5),
        title: Text(
          question,
          style: TextStyle(
            fontSize: 14,
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
                fontSize: 13,
                color: muted,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
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
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Material(
      color: theme.trexvenColors.cardBackground,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
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
              Icon(
                Icons.chevron_right_rounded,
                color: muted.withOpacity(0.5),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}