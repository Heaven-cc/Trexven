import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/vision_service.dart';
import '../welcome_screen.dart';

class MeTab extends StatelessWidget {
  final String ownerName;
  final String businessName;

  MeTab({
    super.key,
    required this.ownerName,
    required this.businessName,
  });

  final AuthService _auth = AuthService();
  final VisionService _vision = VisionService();

  void _showVisionSettings(BuildContext context) async {
    await _vision.init();
    final urlCtrl = TextEditingController(text: _vision.baseUrl);
    final keyCtrl = TextEditingController(text: _vision.apiKey);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Vision Server Configuration',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Set the URL and API key of your AI Vision server (local or cloud).',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vision Server URL',
                    hintText: 'http://192.168.1.50:8000 or https://ai.yourdomain.com',
                    prefixIcon: Icon(Icons.cloud_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: keyCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Vision API Key',
                    hintText: 'Secret API Key',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _vision.setServerUrl(urlCtrl.text.trim());
                await _vision.setApiKey(keyCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vision server configuration saved!'),
                      backgroundColor: Color(0xFF16A34A),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color blue = Color(0xFF2563EB);
    const Color muted = Color(0xFF64748B);
    const Color border = Color(0xFFE2E8F0);
    const Color dark = Color(0xFF0F172A);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Me',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: dark,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 27,
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.person_outline, color: blue, size: 29),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ownerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 3),
                      Text(businessName, style: const TextStyle(color: muted, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _meSection(
            title: 'Business & AI',
            children: [
              _meItem(
                Icons.memory_outlined,
                'Vision Server Settings',
                subtitle: 'Configure Local/Cloud Vision AI Server',
                onTap: () => _showVisionSettings(context),
              ),
              _meItem(Icons.storefront_outlined, 'Business Profile'),
              _meItem(Icons.people_outline, 'Employees'),
              _meItem(Icons.security_outlined, 'Permissions'),
            ],
          ),
          const SizedBox(height: 20),
          _meSection(
            title: 'Settings',
            children: [
              _meItem(Icons.notifications_outlined, 'Notifications'),
              _meItem(Icons.lock_outline, 'Security'),
              _meItem(Icons.palette_outlined, 'Appearance'),
              _meItem(Icons.cloud_outlined, 'Data & Backup'),
            ],
          ),
          const SizedBox(height: 20),
          _meSection(
            title: 'Support',
            children: [
              _meItem(Icons.help_outline, 'Help & Support'),
              _meItem(Icons.info_outline, 'About TREXVEN'),
            ],
          ),
          const SizedBox(height: 30),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: border),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              onTap: () async {
                await _auth.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _meSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _meItem(
    IconData icon,
    String title, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2563EB)),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))
          : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }
}
