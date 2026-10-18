import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';

import '../../core/trexven_motion.dart';
import '../../services/auth_service.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../widgets/trexven_auth_design.dart';
import '../me/privacy_policy_screen.dart';
import '../me/terms_of_service_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  Country _country = Country.parse('NG');
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;
  bool _loading = false;

  double get passwordStrength {
    final password = _passwordController.text;

    if (password.isEmpty) return 0;

    double strength = 0;

    if (password.length >= 8) strength += 0.25;

    if (RegExp(r'[A-Z]').hasMatch(password)) {
      strength += 0.25;
    }

    if (RegExp(r'[0-9]').hasMatch(password)) {
      strength += 0.25;
    }

    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      strength += 0.25;
    }

    return strength;
  }

  String get strengthText {
    if (passwordStrength <= 0.25) return 'Weak';
    if (passwordStrength <= 0.5) return 'Fair';
    if (passwordStrength <= 0.75) return 'Good';
    return 'Strong';
  }

  Color get strengthColor {
    if (passwordStrength <= 0.25) return const Color(0xFFD64545);
    if (passwordStrength <= 0.5) return const Color(0xFFE69138);
    if (passwordStrength <= 0.75) return const Color(0xFF388E3C);
    return const Color(0xFF2E7D32);
  }

  Future<void> _createAccount() async {
    if (_loading) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please agree to the Terms of Service and Privacy Policy.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final formattedPhone = '+${_country.phoneCode}${_phoneController.text.trim()}';

      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: AuthService.redirectUrl,
        data: {
          'full_name': _nameController.text.trim(),
          'phone': formattedPhone,
        },
      );

      if (!mounted) return;

      final user = response.user;

      if (user == null) {
        setState(() => _loading = false);
        _showError('Account could not be created. Please try again.');
        return;
      }

      if (response.session == null) {
        setState(() => _loading = false);
        await _showEmailVerificationMessage(email);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          TrexvenPageRoute(page: const LoginScreen()),
        );
        return;
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(CustomerPresentation.error(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Something went wrong. Please try again.');
    }
  }

  Future<void> _showEmailVerificationMessage(String email) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Verify your email'),
          content: Text(
            'We have sent a verification link to:\n$email\n\n'
            'Please verify your email address before signing in.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openTerms() {
    if (_loading) return;

    Navigator.push(
      context,
      TrexvenPageRoute(page: const TermsOfServiceScreen()),
    );
  }

  void _openPrivacy() {
    if (_loading) return;

    Navigator.push(
      context,
      TrexvenPageRoute(page: const PrivacyPolicyScreen()),
    );
  }

  void _openLogin() {
    if (_loading) return;

    Navigator.pushReplacement(
      context,
      TrexvenPageRoute(page: const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Widget _buildPasswordStrength() {
    if (_passwordController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: passwordStrength,
                    minHeight: 5,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                strengthText,
                style: TextStyle(
                  color: strengthColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Checkbox(
            value: _acceptedTerms,
            activeColor: TrexvenAuthColors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            onChanged: _loading
                ? null
                : (value) {
                    setState(() {
                      _acceptedTerms = value ?? false;
                    });
                  },
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 3,
              children: [
                Text(
                  'I agree to the ',
                  style: TextStyle(
                    color: TrexvenAuthColors.muted(context),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                InkWell(
                  onTap: _openTerms,
                  child: const Text(
                    'Terms of Service',
                    style: TextStyle(
                      color: TrexvenAuthColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  ' and ',
                  style: TextStyle(
                    color: TrexvenAuthColors.muted(context),
                    fontSize: 12,
                  ),
                ),
                InkWell(
                  onTap: _openPrivacy,
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      color: TrexvenAuthColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '.',
                  style: TextStyle(
                    color: TrexvenAuthColors.muted(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationForm(BuildContext context) {
    return TrexvenAuthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TrexvenAuthField(
            label: 'Full name',
            hint: 'Enter your full name',
            controller: _nameController,
            enabled: !_loading,
            prefixIcon: Icon(
              Icons.person_outline_rounded,
              color: TrexvenAuthColors.muted(context),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name.';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          TrexvenAuthField(
            label: 'Email address',
            hint: 'Enter your email address',
            controller: _emailController,
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icon(
              Icons.mail_outline_rounded,
              color: TrexvenAuthColors.muted(context),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) {
                return 'Please enter your email address.';
              }
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return 'Please enter a valid email address.';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          TrexvenAuthPhoneField(
            label: 'Phone number',
            hint: 'Enter your phone number',
            controller: _phoneController,
            enabled: !_loading,
            onCountryChanged: (Country c) {
              _country = c;
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your phone number.';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          TrexvenAuthField(
            label: 'Password',
            hint: 'Create a password',
            controller: _passwordController,
            enabled: !_loading,
            obscureText: _obscurePassword,
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: TrexvenAuthColors.muted(context),
            ),
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: TrexvenAuthColors.muted(context),
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            onChanged: (_) => setState(() {}),
            validator: (value) {
              if (value == null || value.length < 8) {
                return 'Password must contain at least 8 characters.';
              }
              return null;
            },
          ),
          _buildPasswordStrength(),
          const SizedBox(height: 18),
          TrexvenAuthField(
            label: 'Confirm password',
            hint: 'Confirm your password',
            controller: _confirmController,
            enabled: !_loading,
            obscureText: _obscureConfirm,
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: TrexvenAuthColors.muted(context),
            ),
            suffixIcon: IconButton(
              tooltip: _obscureConfirm ? 'Show confirmation' : 'Hide confirmation',
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: TrexvenAuthColors.muted(context),
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match.';
              }
              return null;
            },
          ),
          const SizedBox(height: 22),
          _buildTermsCheckbox(context),
          const SizedBox(height: 22),
          TrexvenAuthPrimaryButton(
            label: 'Create Account',
            loading: _loading,
            showArrow: true,
            onPressed: _createAccount,
          ),
          const SizedBox(height: 24),
          const TrexvenAuthOrDivider(),
          const SizedBox(height: 22),
          GoogleSignInButton(
            enabled: !_loading,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TrexvenAuthShell(
      child: Column(
        children: [
          const TrexvenAuthBackButton(),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: TrexvenAuthBrand(size: 76)),
                        const SizedBox(height: 16),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Create your ',
                                style: TextStyle(
                                  color: TrexvenAuthColors.navy(context),
                                ),
                              ),
                              const TextSpan(
                                text: 'account',
                                style: TextStyle(
                                  color: TrexvenAuthColors.blue,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Start by creating your secure owner account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: TrexvenAuthColors.muted(context),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildRegistrationForm(context),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: TrexvenAuthColors.muted(context),
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: _loading ? null : _openLogin,
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  color: TrexvenAuthColors.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
