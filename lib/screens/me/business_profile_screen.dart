
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';

import '../../core/user_provider.dart';
import '../../models/business.dart';
import '../../services/database_service.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() =>
      _BusinessProfileScreenState();
}

class _BusinessProfileScreenState
    extends State<BusinessProfileScreen> {
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

  Color get _background => Theme.of(context).scaffoldBackgroundColor;
  Color get _white => Theme.of(context).colorScheme.surface;
  Color get _navy => Theme.of(context).colorScheme.onSurface;
  Color get _blue => Theme.of(context).colorScheme.primary;
  Color get _muted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _softBlue => _blue.withValues(alpha: .10);
  Color get _border => Theme.of(context).colorScheme.outlineVariant;

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
        _error = null;
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
    if (_isSaving || _business == null) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

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

      context.read<UserProvider>().refreshBusiness();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Business profile updated successfully!',
          ),
          behavior: SnackBarBehavior.floating,
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
              'Unable to update business profile. Please try again.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
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
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Business Profile',
          style: TextStyle(
            color: _navy,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: TrexvenLoading())
          : _error != null || _business == null
          ? _errorState()
          : _content(),
    );
  }

  Widget _content() {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior:
        ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          16, 16, 16, 32,
        ),
        child: Center(
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
                  Text(
                    'Business Information',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage your business details in TREXVEN.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 18),

                  _sectionCard(
                    children: [
                      _field(
                        label: 'Business Name',
                        controller: _nameCtrl,
                        icon: Icons.storefront_outlined,
                        hint: 'Enter business name',
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Business name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      _field(
                        label: 'Business Category',
                        controller: _typeCtrl,
                        icon: Icons.category_outlined,
                        hint: 'e.g. Auto Spare Parts',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Location & Contact',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _sectionCard(
                    children: [
                      _field(
                        label: 'Address',
                        controller: _addressCtrl,
                        icon: Icons.location_on_outlined,
                        hint: 'Enter business address',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 15),
                      _field(
                        label: 'Phone Number',
                        controller: _phoneCtrl,
                        icon: Icons.phone_outlined,
                        hint: 'Enter phone number',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 15),
                      _field(
                        label: 'Email Address',
                        controller: _emailCtrl,
                        icon: Icons.email_outlined,
                        hint: 'Enter business email',
                        keyboardType:
                        TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return null;
                          }

                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(value.trim())) {
                            return 'Enter a valid email address';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      _field(
                        label: 'Website',
                        controller: _webCtrl,
                        icon: Icons.language_outlined,
                        hint: 'e.g. www.yourbusiness.com',
                        keyboardType: TextInputType.url,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 49,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: _white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(13),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                        CircularProgressIndicator(
                          color: _white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _navy,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          enabled: !_isSaving,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          textCapitalization:
          keyboardType == TextInputType.emailAddress ||
              keyboardType == TextInputType.url
              ? TextCapitalization.none
              : TextCapitalization.words,
          style: TextStyle(
            color: _navy,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: _muted,
              fontSize: 12,
            ),
            prefixIcon: Icon(
              icon,
              color: _blue,
              size: 19,
            ),
            filled: true,
            fillColor: _background,
            isDense: true,
            contentPadding:
            const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(11),
              borderSide:
              BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(11),
              borderSide:
              BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(11),
              borderSide: const BorderSide(
                color: _blue,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: _muted,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadBusiness();
              },
              icon: Icon(Icons.refresh_rounded),
              label: Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
