import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_gate.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AccountGate()),
        (_) => false,
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update password. Request a new reset link and try again.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Reset your password')),
    body: Padding(
      padding: TrexvenSpacing.pagePadding,
      child: Form(
        key: _form,
        child: ListView(
          children: [
            TrexvenTextFormField(
              controller: _password,
              obscureText: true,
              decoration: TrexvenInputDecoration(labelText: 'New password'),
              validator: (v) => v == null || v.length < 8
                  ? 'Use at least 8 characters.'
                  : null,
            ),
            TrexvenTextFormField(
              obscureText: true,
              decoration: TrexvenInputDecoration(labelText: 'Confirm password'),
              validator: (v) =>
                  v != _password.text ? 'Passwords do not match.' : null,
            ),
            SizedBox(height: TrexvenSpacing.sectionGap),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving...' : 'Save password'),
            ),
          ],
        ),
      ),
    ),
  );
}
