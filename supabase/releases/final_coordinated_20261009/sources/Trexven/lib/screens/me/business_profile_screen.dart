import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/user_provider.dart';
import '../../models/business.dart';
import '../../services/database_service.dart';
import '../../widgets/trexven_widgets.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() =>
      _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  Business? _business;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  final _nameCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _webCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _webCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    try {
      final biz = await _db.getBusinessProfile();

      if (!mounted) return;

      if (biz == null) {
        setState(() {
          _isLoading = false;
          _error = 'Business profile could not be found.';
        });
        return;
      }

      setState(() {
        _business = biz;

        _nameCtrl.text = biz.businessName;
        _typeCtrl.text = biz.businessType ?? '';
        _addressCtrl.text = biz.address ?? '';
        _phoneCtrl.text = biz.phone ?? '';
        _emailCtrl.text = biz.email ?? '';
        _webCtrl.text = biz.website ?? '';

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = 'Unable to load your business profile.';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_business == null) return;

    setState(() => _isSaving = true);

    try {
      final updated = Business(
        id: _business!.id,
        businessName: _nameCtrl.text.trim(),
        businessType: _typeCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        website: _webCtrl.text.trim(),
        ownerId: _business!.ownerId,
        country: _business!.country,
        currency: _business!.currency,
        logoUrl: _business!.logoUrl,
        businessHours: _business!.businessHours,
      );

      await _db.updateBusinessProfile(updated);

      if (!mounted) return;
      final theme = Theme.of(context);
      
      // Refresh global state
      context.read<UserProvider>().refreshBusiness();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Business profile updated successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.trexvenColors.success ?? const Color(0xFF16A34A),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final theme = Theme.of(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update business profile: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.trexvenColors.error ?? const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Business Profile',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: theme.colorScheme.primary,
        ),
      )
          : _error != null
          ? _errorState(theme)
          : _business == null
          ? _errorState(theme)
          : _content(theme),
    );
  }

  Widget _content(ThemeData theme) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Business Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep your business details up to date for your TREXVEN workspace.',
                style: TextStyle(
                  fontSize: 13,
                  color: muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              _card(
                children: [
                  _field(
                    theme,
                    label: 'Business Name',
                    controller: _nameCtrl,
                    icon: Icons.storefront_outlined,
                    hint: 'Enter business name',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Business name is required';
                      }
                      return null;
                    },
                  ),
                  _divider(theme),
                  _field(
                    theme,
                    label: 'Business Category',
                    controller: _typeCtrl,
                    icon: Icons.category_outlined,
                    hint: 'e.g. Auto Spare Parts',
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                'Location & Contact',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              _card(
                children: [
                  _field(
                    theme,
                    label: 'Address',
                    controller: _addressCtrl,
                    icon: Icons.location_on_outlined,
                    hint: 'Enter business address',
                    maxLines: 2,
                  ),
                  _divider(theme),
                  _field(
                    theme,
                    label: 'Phone Number',
                    controller: _phoneCtrl,
                    icon: Icons.phone_outlined,
                    hint: 'Enter phone number',
                    keyboardType: TextInputType.phone,
                  ),
                  _divider(theme),
                  _field(
                    theme,
                    label: 'Email Address',
                    controller: _emailCtrl,
                    icon: Icons.email_outlined,
                    hint: 'Enter business email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }

                      final email = value.trim();

                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(email)) {
                        return 'Enter a valid email address';
                      }

                      return null;
                    },
                  ),
                  _divider(theme),
                  _field(
                    theme,
                    label: 'Website',
                    controller: _webCtrl,
                    icon: Icons.language_outlined,
                    hint: 'e.g. www.yourbusiness.com',
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              TrexvenButton(
                text: 'Save Changes',
                onPressed: _save,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({
    required List<Widget> children,
  }) {
    return TrexvenTapCard(
      padding: const EdgeInsets.all(18),
      child: Column(children: children),
    );
  }

  Widget _divider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Divider(
        height: 1,
        color: theme.trexvenColors.border?.withOpacity(0.5) ?? Colors.white12,
      ),
    );
  }

  Widget _field(
    ThemeData theme, {
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
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
          keyboardType: keyboardType,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(
              icon,
              size: 21,
              color: brandBlue,
            ),
            filled: true,
            fillColor: theme.trexvenColors.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: brandBlue,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorState(ThemeData theme) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: muted,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadBusiness();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}