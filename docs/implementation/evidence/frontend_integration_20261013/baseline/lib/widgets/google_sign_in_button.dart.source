import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class GoogleSignInButton extends StatefulWidget {
  final bool enabled;
  const GoogleSignInButton({super.key, this.enabled = true});
  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _busy = false;
  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await AuthService().signInWithGoogle();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in could not start. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: widget.enabled && !_busy ? _signIn : null,
    child: Text(_busy ? 'Opening Google...' : 'Continue with Google'),
  );
}
