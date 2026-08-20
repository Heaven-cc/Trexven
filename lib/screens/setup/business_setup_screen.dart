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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_businessType == null ||
        _country == null ||
        _currency == null) {
      _showError(
        'Please complete all business setup selections.',
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      _showError(
        'Your session has expired. Please sign in again.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final businessName =
      _businessNameController.text.trim();

      final address =
      _addressController.text.trim();

      final phone =
      _phoneController.text.trim();

      /*
       * ---------------------------------------------------------
       * 1. CHECK IF THIS USER ALREADY HAS A BUSINESS
       * ---------------------------------------------------------
       */

      final existingMembership = await supabase
          .from('business_members')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('role', 'owner')
          .maybeSingle();

      String businessId;

      /*
       * ---------------------------------------------------------
       * 2. CREATE OR UPDATE BUSINESS
       * ---------------------------------------------------------
       */

      if (existingMembership != null) {
        businessId =
        existingMembership['business_id'] as String;

        await supabase
            .from('businesses')
            .update({
          'business_name': businessName,
          'business_type': _businessType,
          'address':
          address.isEmpty ? null : address,
          'phone':
          phone.isEmpty ? null : phone,
          'country': _country,
          'currency': _currency,
          'updated_at':
          DateTime.now().toIso8601String(),
        })
            .eq('id', businessId);
      } else {
        /*
         * -------------------------------------------------------
         * CREATE NEW BUSINESS
         * -------------------------------------------------------
         */

        final business =
        await supabase
            .from('businesses')
            .insert({
          'business_name': businessName,
          'business_type': _businessType,
          'address':
          address.isEmpty ? null : address,
          'phone':
          phone.isEmpty ? null : phone,
          'country': _country,
          'currency': _currency,
          'owner_id': user.id,
          'created_by': user.id,
        })
            .select('id')
            .single();

        businessId = business['id'] as String;

        /*
         * -------------------------------------------------------
         * CREATE OWNER MEMBERSHIP
         * -------------------------------------------------------
         */

        await supabase
            .from('business_members')
            .insert({
          'business_id': businessId,
          'user_id': user.id,
          'role': 'owner',
          'status': 'active',
        });
      }

      /*
       * ---------------------------------------------------------
       * SUCCESS
       * ---------------------------------------------------------
       */

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
        'Could not save your business: ${error.message}',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showError(
        'Something went wrong. Please try again.',
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,

        title: const Text(
          'TREXVEN',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Color(0xFF0F172A),
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            24,
            10,
            24,
            35,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Set up your business',
                  style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'Create your business workspace. You can add employees and additional users later.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 28),

                _field(
                  controller:
                  _businessNameController,
                  hint: 'Business / Store Name',
                  icon:
                  Icons.storefront_outlined,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please enter your business name.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                _dropdown(
                  value: _businessType,
                  hint: 'Select business type',
                  icon:
                  Icons.business_outlined,
                  items: _businessTypes,
                  onChanged: (value) {
                    setState(() {
                      _businessType = value;
                    });
                  },
                ),

                const SizedBox(height: 16),

                _field(
                  controller:
                  _addressController,
                  hint: 'Business Address',
                  icon:
                  Icons.location_on_outlined,
                ),

                const SizedBox(height: 16),

                _field(
                  controller:
                  _phoneController,
                  hint: 'Business Phone Number',
                  icon:
                  Icons.phone_outlined,
                  keyboardType:
                  TextInputType.phone,
                ),

                const SizedBox(height: 16),

                _dropdown(
                  value: _country,
                  hint: 'Select country',
                  icon:
                  Icons.public_outlined,
                  items: _countries,
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
                  icon:
                  Icons.payments_outlined,
                  items: _currencies,
                  onChanged: (value) {
                    setState(() {
                      _currency = value;
                    });
                  },
                ),

                const SizedBox(height: 28),

                Container(
                  padding:
                  const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius:
                    BorderRadius.circular(16),
                    border: Border.all(
                      color:
                      const Color(0xFFDBEAFE),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color:
                        Color(0xFF2563EB),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You will become the owner of this business workspace. Employees, managers and other team members can be added later.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color:
                            Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                    _loading
                        ? null
                        : _continue,
                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      const Color(
                          0xFF2563EB),
                      foregroundColor:
                      Colors.white,
                      elevation: 0,
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          15,
                        ),
                      ),
                    ),
                    child: _loading
                        ? const Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                      children: [
                        SizedBox(
                          width: 19,
                          height: 19,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                            Colors.white,
                          ),
                        ),
                        SizedBox(
                          width: 12,
                        ),
                        Text(
                          'Creating workspace...',
                          style:
                          TextStyle(
                            fontWeight:
                            FontWeight
                                .w700,
                          ),
                        ),
                      ],
                    )
                        : const Text(
                      'Create Business',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                        FontWeight.w700,
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
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,

      decoration: InputDecoration(
        hintText: hint,

        prefixIcon: Icon(
          icon,
          color: const Color(0xFF64748B),
        ),

        filled: true,
        fillColor: Colors.white,

        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),

        enabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),

        focusedBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF2563EB),
            width: 1.5,
          ),
        ),

        errorBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),

        contentPadding:
        const EdgeInsets.symmetric(
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
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,

      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF64748B),
        ),

        filled: true,
        fillColor: Colors.white,

        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),

        enabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),

        focusedBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF2563EB),
            width: 1.5,
          ),
        ),
      ),

      hint: Text(hint),

      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            overflow:
            TextOverflow.ellipsis,
          ),
        );
      }).toList(),

      onChanged: onChanged,
    );
  }
}