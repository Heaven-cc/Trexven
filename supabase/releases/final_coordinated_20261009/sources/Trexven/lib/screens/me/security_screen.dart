import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../../services/database_service.dart';
import '../../core/app_theme.dart';
import '../../widgets/trexven_widgets.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isSigningOut = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  User? get _user => Supabase.instance.client.auth.currentUser;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passCtrl.text),
      );

      if (!mounted) return;

      _passCtrl.clear();
      _confirmCtrl.clear();

      _showMsg('Password updated successfully.');
    } on AuthException catch (e) {
      _showMsg(e.message, isError: true);
    } catch (_) {
      _showMsg(
        'Unable to update your password. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Request account deletion?',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.red),
        ),
        content: const Text(
          'This starts an owner-verified review. Business data, financial history, authentication and pending transactions are retained. No records are deleted by this request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue to request'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSigningOut = true);
    try {
      final business = await DatabaseService().getCurrentBusinessId();
      if (business == null)
        throw StateError('Verified owner business required.');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AccountOperationsScreen(
            api: OperationsClient(Supabase.instance.client, business),
          ),
        ),
      );
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      _showMsg('Deletion request unavailable: $message', isError: true);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  void _showMsg(String message, {bool isError = false}) {
    if (!mounted) return;
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? (theme.trexvenColors.error ?? const Color(0xFFDC2626))
            : (theme.trexvenColors.success ?? const Color(0xFF16A34A)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final errorColor = theme.trexvenColors.error ?? Colors.red;
    final successColor = theme.trexvenColors.success ?? Colors.green;

    final email = _user?.email ?? 'TREXVEN account';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Security',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
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
            _sectionTitle(theme, 'Change Password'),
            const SizedBox(height: 8),
            Text(
              'Choose a strong password to keep your TREXVEN account secure.',
              style: TextStyle(fontSize: 13, color: muted, height: 1.5),
            ),
            const SizedBox(height: 16),

            _card(
              theme,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          labelStyle: TextStyle(color: muted),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a new password';
                          }

                          if (value.trim().length < 6) {
                            return 'Password must be at least 6 characters';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: !_showConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_isLoading) {
                            _changePassword();
                          }
                        },
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          labelStyle: TextStyle(color: muted),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _showConfirmPassword = !_showConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _showConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Confirm your new password';
                          }

                          if (value != _passCtrl.text) {
                            return 'Passwords do not match';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      TrexvenButton(
                        text: 'Update Password',
                        onPressed: _changePassword,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            _sectionTitle(theme, 'Account Security'),
            const SizedBox(height: 12),

            _card(
              theme,
              child: Column(
                children: [
                  _infoRow(
                    theme,
                    icon: Icons.verified_user_outlined,
                    title: 'Signed-in Account',
                    subtitle: email,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 76),
                    child: Divider(
                      height: 1,
                      color:
                          theme.trexvenColors.border?.withOpacity(0.5) ??
                          Colors.white12,
                    ),
                  ),
                  _infoRow(
                    theme,
                    icon: Icons.lock_outline_rounded,
                    title: 'Account Protection',
                    subtitle:
                        'Your TREXVEN account is secured through authentication.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            _sectionTitle(theme, 'Session Management'),
            const SizedBox(height: 12),

            _card(
              theme,
              child: _infoRow(
                theme,
                icon: Icons.devices_rounded,
                title: 'Current Device',
                subtitle: 'You are currently signed in on this device.',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Current',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: successColor,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            _sectionTitle(theme, 'Danger Zone'),
            const SizedBox(height: 12),

            TrexvenTapCard(
              onTap: _isSigningOut ? null : _deleteAccount,
              padding: const EdgeInsets.all(18),
              backgroundColor: errorColor.withOpacity(0.05),
              hasBorder: true,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: errorColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request account deletion',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: errorColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Start a reviewed request and retain financial history.',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                  if (_isSigningOut)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: errorColor,
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: muted.withOpacity(0.5),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
      ),
      child: child,
    );
  }

  Widget _infoRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final brandBlue = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: brandBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: brandBlue, size: 23),
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
