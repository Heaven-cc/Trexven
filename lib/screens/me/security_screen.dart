import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../../services/account_deletion_service.dart';
import '../auth/account_gate.dart';

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
    if (_isSigningOut) return;
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
      _showMsg(CustomerPresentation.error(e), isError: true);
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
    if (_isSigningOut || _isLoading) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(
          'Delete your account?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        content: Text(
          'This permanently removes your login and personal account access. Business and financial history are retained. Recover pending transactions, close cash shifts and complete any required business handover first. You may need to sign in again to confirm your identity.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text('Delete account'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSigningOut = true);
    try {
      await AccountDeletionService().deleteConfirmed();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AccountGate()),
        (_) => false,
      );
    } catch (e) {
      _showMsg(
        e is AccountDeletionError
            ? e.message
            : CustomerPresentation.error(
                e,
                fallback:
                    'Account deletion was not confirmed. Recover the original request before starting another.',
              ),
        isError: true,
      );
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
            ? (theme.trexvenColors.error!)
            : (theme.trexvenColors.success!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted!;
    final errorColor = theme.trexvenColors.error!;
    final successColor = theme.trexvenColors.success!;

    final email = _user?.email ?? 'TREXVEN account';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Security',
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
            _sectionTitle(theme, 'Change Password'),
            SizedBox(height: 8),
            Text(
              'Choose a strong password to keep your TREXVEN account secure.',
              style: TextStyle(
                fontSize: TrexvenFontSize.body,
                color: muted,
                height: 1.5,
              ),
            ),
            SizedBox(height: TrexvenSpacing.fieldGap),

            _card(
              theme,
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TrexvenTextFormField(
                        controller: _passCtrl,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.next,
                        decoration: TrexvenInputDecoration(
                          labelText: 'New Password',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
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
                      TrexvenTextFormField(
                        controller: _confirmCtrl,
                        obscureText: !_showConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_isLoading) {
                            _changePassword();
                          }
                        },
                        decoration: TrexvenInputDecoration(
                          labelText: 'Confirm New Password',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
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
                      SizedBox(height: TrexvenSpacing.sectionGap),
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

            SizedBox(height: TrexvenSpacing.sectionGap),

            _sectionTitle(theme, 'Account Security'),
            SizedBox(height: 12),

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
                    padding: EdgeInsets.only(left: 76),
                    child: Divider(
                      height: 1,
                      color:
                          theme.trexvenColors.border?.withValues(alpha: 0.5) ??
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

            SizedBox(height: TrexvenSpacing.sectionGap),

            _sectionTitle(theme, 'Session Management'),
            SizedBox(height: 12),

            _card(
              theme,
              child: _infoRow(
                theme,
                icon: Icons.devices_rounded,
                title: 'Current Device',
                subtitle: 'You are currently signed in on this device.',
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(TrexvenRadii.card),
                  ),
                  child: Text(
                    'Current',
                    style: TextStyle(
                      fontSize: TrexvenFontSize.caption,
                      fontWeight: FontWeight.w700,
                      color: successColor,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: TrexvenSpacing.sectionGap),

            _sectionTitle(theme, 'Danger Zone'),
            SizedBox(height: 12),

            TrexvenTapCard(
              onTap: _isSigningOut || _isLoading ? null : _deleteAccount,
              padding: EdgeInsets.all(18),
              backgroundColor: errorColor.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(TrexvenRadii.card),
                    ),
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: errorColor,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete account',
                          style: TextStyle(
                            fontSize: TrexvenFontSize.input,
                            fontWeight: FontWeight.w800,
                            color: errorColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Remove your login; business and financial history are retained.',
                          style: TextStyle(
                            fontSize: TrexvenFontSize.caption,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isSigningOut)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Icon(Icons.more_horiz_rounded, size: 16),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: muted.withValues(alpha: 0.5),
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
        fontSize: TrexvenFontSize.input,
        fontWeight: FontWeight.w800,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
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
    final muted = theme.trexvenColors.muted!;
    final brandBlue = theme.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: brandBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
            ),
            child: Icon(icon, color: brandBlue, size: 23),
          ),
          SizedBox(width: 14),
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
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: TrexvenFontSize.caption,
                    color: muted,
                    height: 1.4,
                  ),
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
