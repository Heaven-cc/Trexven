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
  void dispose() { _password.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _password.text));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AccountGate()), (_) => false);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update password. Request a new reset link and try again.')));
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset your password')),
    body: Padding(padding: const EdgeInsets.all(24), child: Form(key: _form, child: Column(children: [
      TextFormField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'New password'),
        validator: (v) => v == null || v.length < 8 ? 'Use at least 8 characters.' : null),
      const SizedBox(height: 16),
      TextFormField(obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password'),
        validator: (v) => v != _password.text ? 'Passwords do not match.' : null),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'Save password')),
    ]))),
  );
}
