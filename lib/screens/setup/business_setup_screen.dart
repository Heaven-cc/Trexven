import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          .timeout(Duration(seconds: 20));

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

      _showError(
        CustomerPresentation.error(
          error,
          fallback: 'We could not save your business. Please try again.',
        ),
      );
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
    final muted = theme.trexvenColors.muted!;
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
            fontSize: TrexvenFontSize.input,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 35),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set up your business',
                  style: TextStyle(
                    fontSize: TrexvenFontSize.display,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                SizedBox(height: 7),

                Text(
                  'Create your business workspace. You can add employees and additional users later.',
                  style: TextStyle(
                    fontSize: TrexvenFontSize.body,
                    height: 1.45,
                    color: muted,
                  ),
                ),

                SizedBox(height: TrexvenSpacing.sectionGap),

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

                _field(
                  controller: _addressController,
                  hint: 'Business Address',
                  icon: Icons.location_on_outlined,
                  theme: theme,
                ),
                _field(
                  controller: _phoneController,
                  hint: 'Business Phone Number',
                  icon: Icons.phone_outlined,
                  theme: theme,
                  keyboardType: TextInputType.phone,
                ),
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

                SizedBox(height: TrexvenSpacing.sectionGap),

                Container(
                  padding: TrexvenSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: brandBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(TrexvenRadii.card),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: brandBlue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You will become the owner of this business workspace. Employees, managers and other team members can be added later.',
                          style: TextStyle(
                            fontSize: TrexvenFontSize.caption,
                            height: 1.5,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandBlue,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: _loading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 19,
                                height: 19,
                                child: Text('Please wait…'),
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
                        : Text(
                            'Create Business',
                            style: TextStyle(
                              fontSize: TrexvenFontSize.input,
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
    final muted = theme.trexvenColors.muted!;

    return TrexvenTextFormField(
      enabled: !_loading,
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: TrexvenInputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: muted),
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
    final muted = theme.trexvenColors.muted!;

    return TrexvenDropdown<String>(
      label: hint,
      initialValue: value,
      decoration: TrexvenInputDecoration(prefixIcon: Icon(icon, color: muted)),
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
