import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';

import '../../core/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String initialName;

  const ProfileScreen({
    super.key,
    required this.initialName,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;

  bool _saving = false;

  Color get _background => Theme.of(context).scaffoldBackgroundColor;
  Color get _white => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white;
  Color get _navy => Theme.of(context).colorScheme.onSurface;
  Color get _blue => Theme.of(context).colorScheme.primary;
  Color get _muted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _softBlue => Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
  Color get _border => Theme.of(context).colorScheme.outlineVariant;

  @override
  void initState() {
    super.initState();

    final user = Supabase.instance.client.auth.currentUser;

    _name = TextEditingController(
      text: user?.userMetadata?['full_name'] as String? ??
          widget.initialName,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
    });

    try {
      await context.read<UserProvider>().updateMetadata({
        'full_name': _name.text.trim(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your profile has been updated.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CustomerPresentation.error(
              error,
              fallback:
              'We could not save your profile. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'My Profile',
          style: TextStyle(
            color: _navy,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            16, 18, 16, 32,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 560,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(),

                    const SizedBox(height: 20),

                    _buildProfileCard(
                      user?.email ?? 'Email unavailable',
                    ),

                    const SizedBox(height: 18),

                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _buildProfileHeader() {
    return Row(
      children: [
        Container(
          width: 49,
          height: 49,
          decoration: BoxDecoration(
            color: _softBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.person_outline_rounded,
            color: _blue,
            size: 25,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Your profile',
                style: TextStyle(
                  color: _navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Manage your personal account details',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE FORM CARD
  // ============================================================

  Widget _buildProfileCard(String email) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal information',
            style: TextStyle(
              color: _navy,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 17),

          Text(
            'Full name',
            style: TextStyle(
              color: _navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          TextFormField(
            controller: _name,
            enabled: !_saving,
            maxLength: 100,
            textCapitalization:
            TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [
              AutofillHints.name,
            ],
            onFieldSubmitted: (_) => _save(),
            validator: (value) {
              if ((value?.trim().length ?? 0) < 2) {
                return 'Enter your full name.';
              }
              return null;
            },
            style: TextStyle(
              color: _navy,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              hintStyle: TextStyle(
                color: _muted,
                fontSize: 13,
              ),
              counterText: '',
              prefixIcon: Icon(
                Icons.person_outline_rounded,
                color: _blue,
                size: 20,
              ),
              filled: true,
              fillColor: _background,
              contentPadding:
              const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _blue,
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 13),

          Divider(
            color: _border,
            height: 1,
          ),

          const SizedBox(height: 17),

          Text(
            'Email address',
            style: TextStyle(
              color: _navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: _background,
              borderRadius:
              BorderRadius.circular(12),
              border: Border.all(
                color: _border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.mail_outline_rounded,
                  color: _muted,
                  size: 20,
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: SelectableText(
                    email,
                    style: TextStyle(
                      color: _navy,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Icon(
                  Icons.lock_outline_rounded,
                  color: _muted,
                  size: 16,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Your sign-in email cannot be changed here.',
            style: TextStyle(
              color: _muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 49,
      child: FilledButton(
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _softBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: _saving
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_rounded,
              size: 19,
            ),

            SizedBox(width: 8),

            Text(
              'Save Changes',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
