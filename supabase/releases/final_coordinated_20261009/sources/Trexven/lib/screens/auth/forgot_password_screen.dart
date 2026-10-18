import '../../services/auth_service.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../widgets/trexven_logo.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _success = false;

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService().resetPassword(_emailController.text);
      if (mounted) {
        setState(() => _success = true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to send a reset link. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _success ? _successView(theme) : _formView(theme),
        ),
      ),
    );
  }

  Widget _formView(ThemeData theme) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 25),
            const Center(child: TrexvenLogo(size: 62)),
            const SizedBox(height: 28),
            Text(
              'Reset your password',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Enter the email associated with your account and we'll send you a secure reset link.",
              style: TextStyle(color: muted, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 30),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email Address',
                prefixIcon: Icon(Icons.mail_outline, color: muted),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'Please enter your email address.';
                if (!RegExp(
                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                ).hasMatch(value.trim()))
                  return 'Please enter a valid email address.';
                return null;
              },
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _loading ? null : _sendResetLink,
              child: _loading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Sending reset link...'),
                      ],
                    )
                  : const Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _successView(ThemeData theme) {
    final successColor = theme.trexvenColors.success ?? Colors.green;
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: successColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mark_email_read_outlined,
            color: successColor,
            size: 42,
          ),
        ),
        const SizedBox(height: 25),
        Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Password reset instructions have been sent to your email address.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to Sign In'),
        ),
      ],
    );
  }
}
