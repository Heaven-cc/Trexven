import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import 'setup_complete_screen.dart';

class BusinessSetupScreen extends StatefulWidget {
  final String ownerName;
  final String email;

  const BusinessSetupScreen({
    super.key,
    required this.ownerName,
    required this.email,
  });

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _businessNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _businessType;
  String? _country;
  String? _currency;

  bool _loading = false;

  final List<String> _businessTypes = [
    'Motor Spare Parts',
    'Electronics',
    'Fashion',
    'Pharmacy',
    'Supermarket',
    'Hardware',
    'Restaurant',
    'Beauty',
    'General Retail',
    'Other',
  ];

  final List<String> _countries = [
    'Nigeria',
    'Ghana',
    'Kenya',
    'South Africa',
    'United States',
    'United Kingdom',
    'Other',
  ];

  final List<String> _currencies = [
    'Nigerian Naira (₦)',
    'Ghanaian Cedi (₵)',
    'Kenyan Shilling (KSh)',
    'South African Rand (R)',
    'US Dollar (\$)',
    'British Pound (£)',
  ];

  Future<void> _continue() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_businessType == null || _country == null || _currency == null) {
      _showError('Please complete all business setup selections.');
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      _showError('Your session has expired. Please sign in again.');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final businessName = _businessNameController.text.trim();

      final address = _addressController.text.trim();

      final phone = _phoneController.text.trim();

      await supabase
          .rpc(
            'complete_trexven_onboarding',
            params: {
              'p_business_name': businessName,
              'p_business_type': _businessType,
              'p_country': _country,
              'p_currency': _currency,
              'p_address': address.isEmpty ? null : address,
              'p_phone': phone.isEmpty ? null : phone,
            },
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SetupCompleteScreen(
            businessName: businessName,
            businessType: _businessType!,
            ownerName: widget.ownerName,
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showError('Could not save your business: ${error.message}');
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showError('Something went wrong. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final brandBlue = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),

        title: Text(
          'TREXVEN',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 35),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set up your business',
                  style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  'Create your business workspace. You can add employees and additional users later.',
                  style: TextStyle(fontSize: 14, height: 1.45, color: muted),
                ),

                const SizedBox(height: 28),

                _field(
                  controller: _businessNameController,
                  hint: 'Business / Store Name',
                  icon: Icons.storefront_outlined,
                  theme: theme,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your business name.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                _dropdown(
                  value: _businessType,
                  hint: 'Select business type',
                  icon: Icons.business_outlined,
                  items: _businessTypes,
                  theme: theme,
                  onChanged: (value) {
                    setState(() {
                      _businessType = value;
                    });
                  },
                ),

                const SizedBox(height: 16),

                _field(
                  controller: _addressController,
                  hint: 'Business Address',
                  icon: Icons.location_on_outlined,
                  theme: theme,
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _phoneController,
                  hint: 'Business Phone Number',
                  icon: Icons.phone_outlined,
                  theme: theme,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _dropdown(
                  value: _country,
                  hint: 'Select country',
                  icon: Icons.public_outlined,
                  items: _countries,
                  theme: theme,
                  onChanged: (value) {
                    setState(() {
                      _country = value;
                    });
                  },
                ),

                const SizedBox(height: 16),

                _dropdown(
                  value: _currency,
                  hint: 'Select currency',
                  icon: Icons.payments_outlined,
                  items: _currencies,
                  theme: theme,
                  onChanged: (value) {
                    setState(() {
                      _currency = value;
                    });
                  },
                ),

                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: brandBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: brandBlue.withOpacity(0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: brandBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You will become the owner of this business workspace. Employees, managers and other team members can be added later.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
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
                              Flexible(
                                child: Text(
                                  'Creating workspace...',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Create Business',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ThemeData theme,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final brandBlue = theme.colorScheme.primary;

    return TextFormField(
      enabled: !_loading,
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: muted),
        filled: true,
        fillColor: theme.trexvenColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brandBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.trexvenColors.error ?? Colors.redAccent,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ThemeData theme,
    required void Function(String?) onChanged,
  }) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final brandBlue = theme.colorScheme.primary;

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      isDense: false,
      itemHeight: null,
      style: TextStyle(color: theme.colorScheme.onSurface),
      dropdownColor: theme.trexvenColors.cardBackground,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: muted),
        filled: true,
        fillColor: theme.trexvenColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brandBlue, width: 1.5),
        ),
      ),
      hint: Text(hint, style: TextStyle(color: muted)),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: _loading ? null : onChanged,
    );
  }
}
