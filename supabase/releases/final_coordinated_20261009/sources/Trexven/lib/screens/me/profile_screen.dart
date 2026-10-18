import '../../core/app_sizing.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_theme.dart';
import '../../core/user_provider.dart';
import '../../widgets/trexven_widgets.dart';
import 'billing_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String initialName;

  const ProfileScreen({super.key, required this.initialName});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final user = Supabase.instance.client.auth.currentUser;

    _nameCtrl = TextEditingController(
      text: user?.userMetadata?['full_name'] ?? widget.initialName,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<UserProvider>().updateMetadata({
        'full_name': _nameCtrl.text.trim(),
      });

      if (!mounted) return;
      final theme = Theme.of(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              theme.trexvenColors.success ?? const Color(0xFF16A34A),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final theme = Theme.of(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update profile: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.trexvenColors.error ?? const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final brandBlue = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: AppSizing.pagePadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage the name associated with your TREXVEN account.',
                  style: TextStyle(fontSize: 13, color: muted, height: 1.5),
                ),
                const SizedBox(height: 24),

                TrexvenTapCard(
                  padding: const EdgeInsets.all(18),
                  child: _field(
                    theme,
                    label: 'Full Name',
                    controller: _nameCtrl,
                    icon: Icons.person_outline_rounded,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Full name is required';
                      }

                      if (value.trim().length < 2) {
                        return 'Enter a valid name';
                      }

                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Subscription & Billing',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a plan that fits your business needs.',
                  style: TextStyle(fontSize: 13, color: muted, height: 1.5),
                ),
                const SizedBox(height: 16),

                TrexvenTapCard(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BillingScreen()),
                    );
                  },
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: brandBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: brandBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upgrade Plan',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Manage subscription & unlock features',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: muted.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                TrexvenButton(
                  text: 'Save Changes',
                  onPressed: _save,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    ThemeData theme, {
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: muted,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Enter your full name',
            prefixIcon: Icon(icon, size: 21, color: brandBlue),
            filled: true,
            fillColor: theme.trexvenColors.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: brandBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
