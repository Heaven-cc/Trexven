import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/product.dart';
import '../auth/auth_provider.dart';
import '../auth/permission_service.dart';
import 'product_provider.dart';

class QuickAddScreen extends ConsumerStatefulWidget {
  final String? initialBarcode;

  const QuickAddScreen({
    super.key,
    this.initialBarcode,
  });

  @override
  ConsumerState<QuickAddScreen> createState() =>
      _QuickAddScreenState();
}

class _QuickAddScreenState
    extends ConsumerState<QuickAddScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _partNumberController;
  late final TextEditingController _brandController;

  final _nameFocusNode = FocusNode();
  final _barcodeFocusNode = FocusNode();
  final _partNumberFocusNode = FocusNode();
  final _brandFocusNode = FocusNode();

  bool _isSubmitting = false;
  final String _productRequestId = const Uuid().v4();

  static const _primaryBlue =
  Color(0xFF2F66B0);

  static const _lightBlue =
  Color(0xFFEAF1FB);

  static const _background =
  Color(0xFFF2F2F7);

  static const _cardBackground =
      Colors.white;

  static const _primaryText =
  Color(0xFF1C1C1E);

  static const _secondaryText =
  Color(0xFF6B6B70);

  static const _tertiaryText =
  Color(0xFF8E8E93);

  static const _separator =
  Color(0xFFE5E5EA);

  bool get _hasScannedBarcode {
    return widget.initialBarcode != null &&
        widget.initialBarcode!.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController();

    _barcodeController =
        TextEditingController(
          text: widget.initialBarcode ?? '',
        );

    _partNumberController =
        TextEditingController();

    _brandController =
        TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _partNumberController.dispose();
    _brandController.dispose();

    _nameFocusNode.dispose();
    _barcodeFocusNode.dispose();
    _partNumberFocusNode.dispose();
    _brandFocusNode.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    if (!ref.read(permissionServiceProvider).canQuickAddProduct) {
      _showError('You do not have permission to add products.');
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final businessId =
        ref.read(authStateProvider).activeBusiness?.id;

    if (businessId == null ||
        businessId.isEmpty ||
        ref.read(authStateProvider).employee?.businessId != businessId) {
      _showError(
        'No active business is selected.',
      );
      return;
    }

    final barcode =
    _barcodeController.text.trim();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository =
      ref.read(productRepositoryProvider);

      // Check for an existing product one more time
      // before inserting.
      if (barcode.isNotEmpty) {
        final existingProduct =
        await repository.findProductByBarcode(
          barcode,
          businessId,
        );

        if (existingProduct != null) {
          if (!mounted) {
            return;
          }

          setState(() {
            _isSubmitting = false;
          });

          await _showExistingProductDialog(
            existingProduct,
          );

          return;
        }
      }

      final product = Product(
        id: _productRequestId,
        name: _nameController.text.trim(),
        barcode: barcode.isEmpty
            ? null
            : barcode,
        partNumber:
        _partNumberController.text
            .trim()
            .isEmpty
            ? null
            : _partNumberController.text.trim(),
        brand:
        _brandController.text
            .trim()
            .isEmpty
            ? null
            : _brandController.text.trim(),
        status: ProductStatus.pending,
        businessId: businessId,
      );

      final savedProduct = await repository.quickAddProduct(
        product,
      );

      if (!mounted) {
        return;
      }

      // Return the actual newly-created
      // Product to the ScannerScreen.
      Navigator.pop(
        context,
        savedProduct,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      _showError(
        'Unable to add the product. Please try again.',
      );
    }
  }

  Future<void> _showExistingProductDialog(
      Product product,
      ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor:
      Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              24,
              12,
              24,
              24,
            ),
            decoration: const BoxDecoration(
              color: _background,
              borderRadius:
              BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _separator,
                    borderRadius:
                    BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 24),

                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _lightBlue,
                    borderRadius:
                    BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: _primaryBlue,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Product Already Exists',
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  product.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _secondaryText,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(
                        context,
                        product,
                      );
                    },
                    style:
                    ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor:
                      _primaryBlue,
                      foregroundColor:
                      Colors.white,
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          15,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Use Existing Product',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: _secondaryText,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        behavior:
        SnackBarBehavior.floating,
        backgroundColor:
        Colors.red.shade700,
        shape:
        RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(14),
        ),
        content: Text(message),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: _tertiaryText,
      ),
      filled: true,
      fillColor: _background,
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      labelStyle: const TextStyle(
        color: _secondaryText,
      ),
      hintStyle: const TextStyle(
        color: _tertiaryText,
      ),
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide:
        const BorderSide(
          color: _separator,
        ),
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide:
        const BorderSide(
          color: _separator,
        ),
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide:
        const BorderSide(
          color: _primaryBlue,
          width: 1.5,
        ),
      ),
      errorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide:
        BorderSide(
          color: Colors.red.shade400,
        ),
      ),
      focusedErrorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide:
        BorderSide(
          color: Colors.red.shade600,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration:
          BoxDecoration(
            color: _lightBlue,
            borderRadius:
            BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: _primaryBlue,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.w700,
                  letterSpacing: -0.2,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style:
                const TextStyle(
                  fontSize: 13,
                  color:
                  _secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding:
      const EdgeInsets.all(16),
      decoration:
      BoxDecoration(
        color: _lightBlue,
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.pending_actions_outlined,
            color: _primaryBlue,
          ),

          SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending approval',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    _primaryText,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Products added from the POS remain pending until they are reviewed.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color:
                    _secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    if (!ref.watch(permissionServiceProvider).canQuickAddProduct) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quick Add Product')),
        body: const Center(child: Text('You do not have permission to add products.')),
      );
    }
    return Scaffold(
      backgroundColor:
      _background,

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
        _background,
        surfaceTintColor:
        Colors.transparent,
        centerTitle: false,
        titleSpacing: 0,
        iconTheme:
        const IconThemeData(
          color: _primaryText,
        ),
        title: const Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Add Product',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.w700,
                letterSpacing: -0.3,
                color: _primaryText,
              ),
            ),

            SizedBox(height: 2),

            Text(
              'Add a product to your inventory',
              style: TextStyle(
                fontSize: 12,
                color: _secondaryText,
              ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              32,
            ),
            children: [
              _buildInfoCard(),

              const SizedBox(height: 28),

              _sectionTitle(
                icon:
                Icons.inventory_2_outlined,
                title:
                'Product Information',
                subtitle:
                'Enter the basic details for this product',
              ),

              const SizedBox(height: 16),

              Container(
                padding:
                const EdgeInsets.all(16),
                decoration:
                BoxDecoration(
                  color:
                  _cardBackground,
                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                  border:
                  Border.all(
                    color:
                    _separator,
                  ),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller:
                      _nameController,
                      focusNode:
                      _nameFocusNode,
                      textCapitalization:
                      TextCapitalization
                          .words,
                      textInputAction:
                      TextInputAction
                          .next,
                      onFieldSubmitted:
                          (_) {
                        FocusScope.of(
                          context,
                        ).requestFocus(
                          _barcodeFocusNode,
                        );
                      },
                      decoration:
                      _inputDecoration(
                        label:
                        'Product Name',
                        hint:
                        'e.g. Toyota Brake Pad',
                        icon:
                        Icons.inventory_2_outlined,
                      ),
                      validator:
                          (value) {
                        if (value ==
                            null ||
                            value
                                .trim()
                                .isEmpty) {
                          return 'Product name is required';
                        }

                        if (value
                            .trim()
                            .length <
                            2) {
                          return 'Enter a valid product name';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    TextFormField(
                      controller:
                      _barcodeController,
                      focusNode:
                      _barcodeFocusNode,
                      keyboardType:
                      TextInputType
                          .text,
                      textInputAction:
                      TextInputAction
                          .next,
                      inputFormatters: [
                        FilteringTextInputFormatter
                            .deny(
                          RegExp(r'\s'),
                        ),
                      ],
                      onChanged:
                          (_) {
                        setState(() {});
                      },
                      onFieldSubmitted:
                          (_) {
                        FocusScope.of(
                          context,
                        ).requestFocus(
                          _partNumberFocusNode,
                        );
                      },
                      decoration:
                      _inputDecoration(
                        label:
                        _hasScannedBarcode
                            ? 'Scanned Barcode'
                            : 'Barcode',
                        hint:
                        'Enter or scan barcode',
                        icon:
                        Icons.qr_code_scanner_outlined,
                      ).copyWith(
                        suffixIcon:
                        _barcodeController
                            .text
                            .isNotEmpty
                            ? IconButton(
                          icon:
                          const Icon(
                            Icons
                                .clear_rounded,
                            size: 20,
                            color:
                            _tertiaryText,
                          ),
                          onPressed:
                              () {
                            setState(
                                  () {
                                _barcodeController
                                    .clear();
                              },
                            );
                          },
                        )
                            : null,
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    TextFormField(
                      controller:
                      _partNumberController,
                      focusNode:
                      _partNumberFocusNode,
                      textCapitalization:
                      TextCapitalization
                          .characters,
                      textInputAction:
                      TextInputAction
                          .next,
                      onFieldSubmitted:
                          (_) {
                        FocusScope.of(
                          context,
                        ).requestFocus(
                          _brandFocusNode,
                        );
                      },
                      decoration:
                      _inputDecoration(
                        label:
                        'Part Number',
                        hint:
                        'e.g. BP-TOY-2026',
                        icon:
                        Icons.tag_outlined,
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    TextFormField(
                      controller:
                      _brandController,
                      focusNode:
                      _brandFocusNode,
                      textCapitalization:
                      TextCapitalization
                          .words,
                      textInputAction:
                      TextInputAction
                          .done,
                      onFieldSubmitted:
                          (_) =>
                          _submit(),
                      decoration:
                      _inputDecoration(
                        label:
                        'Brand',
                        hint:
                        'e.g. Bosch',
                        icon:
                        Icons
                            .workspace_premium_outlined,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 54,
                child:
                ElevatedButton(
                  onPressed:
                  _isSubmitting
                      ? null
                      : _submit,
                  style:
                  ElevatedButton
                      .styleFrom(
                    elevation: 0,
                    backgroundColor:
                    _primaryBlue,
                    foregroundColor:
                    Colors.white,
                    disabledBackgroundColor:
                    const Color(
                      0xFFB8C7DD,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        15,
                      ),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color:
                      Colors.white,
                    ),
                  )
                      : const Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                    children: [
                      Icon(
                        Icons
                            .add_circle_outline,
                      ),
                      SizedBox(
                        width: 9,
                      ),
                      Text(
                        'Add Product',
                        style:
                        TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight
                              .w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              const Center(
                child: Text(
                  'The product will be added as pending approval.',
                  textAlign:
                  TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                    _tertiaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
