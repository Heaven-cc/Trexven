import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _ownerLogin = false;

  @override
  void dispose() {
    _employeeIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo and Branding
              Column(
                children: [
                  Image.asset('assets/trexvenpos_logo.png', height: 100),
                  const SizedBox(height: 24),
                  const Text(
                    'Trexven POS',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Operational terminal for businesses'),
                ],
              ),
              const SizedBox(height: 48),

              // Login Form Card
              Card(
                elevation: 4,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SwitchListTile(
                        title: const Text('Business owner sign-in'),
                        value: _ownerLogin,
                        onChanged: authState.isLoading
                            ? null
                            : (value) => setState(() => _ownerLogin = value),
                      ),
                      for (final context in authState.contexts)
                        if (authState.employee == null)
                          ListTile(
                            title: Text(
                              (context['business'] as Map)['business_name']
                                  as String,
                            ),
                            onTap: () => ref
                                .read(authStateProvider.notifier)
                                .restoreSession(
                                  businessId:
                                      (context['business'] as Map)['id']
                                          as String,
                                ),
                          ),
                      TextField(
                        controller: _employeeIdController,
                        enabled: !authState.isLoading,
                        keyboardType: _ownerLogin
                            ? TextInputType.emailAddress
                            : TextInputType.text,
                        autocorrect: false,
                        autofillHints: [
                          _ownerLogin
                              ? AutofillHints.email
                              : AutofillHints.username,
                        ],
                        decoration: InputDecoration(
                          labelText: _ownerLogin
                              ? 'Owner email'
                              : 'Employee ID',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        enabled: !authState.isLoading,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText: 'Password / PIN',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (authState.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            authState.error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ElevatedButton(
                        onPressed: authState.isLoading
                            ? null
                            : () {
                                final auth = ref.read(
                                  authStateProvider.notifier,
                                );
                                if (_ownerLogin) {
                                  auth.loginOwner(
                                    _employeeIdController.text,
                                    _passwordController.text,
                                  );
                                } else {
                                  auth.login(
                                    _employeeIdController.text,
                                    _passwordController.text,
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                        child: authState.isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Login'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              const Text('© 2026 ODT Web Ecosystem'),
            ],
          ),
        ),
      ),
    );
  }
}
