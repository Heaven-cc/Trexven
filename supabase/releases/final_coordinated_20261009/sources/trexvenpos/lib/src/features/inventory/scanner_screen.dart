import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../auth/auth_provider.dart';
import 'product_provider.dart';
import 'product_repository.dart';
import 'quick_add_screen.dart';
import '../auth/permission_service.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController =
  MobileScannerController();

  late final AnimationController _scanAnimationController;
  late final Animation<double> _scanAnimation;

  bool _isProcessing = false;
  bool _torchEnabled = false;

  static const Color _blue = Color(0xFF2F66B0);

  @override
  void initState() {
    super.initState();

    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanAnimation = CurvedAnimation(
      parent: _scanAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _scanAnimationController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) {
      return;
    }

    if (capture.barcodes.isEmpty) {
      return;
    }

    final barcode = capture.barcodes.first;

    final code = barcode.rawValue?.trim();

    if (code == null || code.isEmpty) {
      return;
    }

    final businessId =
        ref.read(authStateProvider).activeBusiness?.id;

    if (businessId == null || businessId.isEmpty) {
      _showError(
        'No active business is selected.',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    await _scannerController.stop();

    try {
      final repository =
      ref.read(productRepositoryProvider);

      final product =
      await repository.findProductByBarcode(
        code,
        businessId,
      );

      if (!mounted) {
        return;
      }

      if (product != null) {
        Navigator.pop(
          context,
          product,
        );
        return;
      }

      await _showProductNotFoundSheet(
        code,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessing = false;
      });

      _showError(
        e is DuplicateBarcode ? e.message.toString() : 'Unable to check the inventory. Please try again.',
      );

      await _scannerController.start();
    }
  }

  Future<void> _showProductNotFoundSheet(
      String barcode,
      ) async {
    final canAdd = ref.read(permissionServiceProvider).canQuickAddProduct;
    final shouldAdd =
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(
        alpha: 0.55,
      ),
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
              color: Color(0xFFF2F2F7),
              borderRadius: BorderRadius.vertical(
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
                    color: const Color(0xFFD1D1D6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 26),

                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 32,
                    color: _blue,
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Product Not Found',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF1C1C1E),
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'This barcode is not currently in your inventory.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF6B6B70),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE5E5EA),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.qr_code_2_outlined,
                        color: Color(0xFF8E8E93),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          barcode,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1C1C1E),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (canAdd) SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        true,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                        ),
                        SizedBox(width: 9),
                        Text(
                          'Add Product',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        false,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor:
                      const Color(0xFF6B6B70),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Scan Another Product',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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

    if (!mounted) {
      return;
    }

    if (shouldAdd == true && ref.read(permissionServiceProvider).canQuickAddProduct) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuickAddScreen(
            initialBarcode: barcode,
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      if (result != null) {
        Navigator.pop(
          context,
          result,
        );
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessing = false;
    });

    await _scannerController.start();
  }

  void _toggleTorch() {
    setState(() {
      _torchEnabled = !_torchEnabled;
    });

    _scannerController.toggleTorch();
  }

  void _switchCamera() {
    _scannerController.switchCamera();
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFB42318),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          _ScannerOverlay(
            animation: _scanAnimation,
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    12,
                    18,
                    0,
                  ),
                  child: Row(
                    children: [
                      _GlassButton(
                        icon: Icons.close_rounded,
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),

                      const Spacer(),

                      const Text(
                        'Scan Product',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),

                      const Spacer(),

                      const SizedBox(
                        width: 46,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                const Padding(
                  padding:
                  EdgeInsets.symmetric(horizontal: 35),
                  child: Text(
                    'Place the barcode inside the frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                const Padding(
                  padding:
                  EdgeInsets.symmetric(horizontal: 45),
                  child: Text(
                    'TREXVEN will automatically identify the product.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD1D1D6),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 35),

                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    _GlassButton(
                      icon: _torchEnabled
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      onPressed: _toggleTorch,
                    ),
                    const SizedBox(width: 14),
                    _GlassButton(
                      icon:
                      Icons.flip_camera_ios_rounded,
                      onPressed: _switchCamera,
                    ),
                  ],
                ),

                const SizedBox(height: 34),

                if (_isProcessing)
                  Container(
                    margin:
                    const EdgeInsets.only(bottom: 30),
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                        alpha: 0.65,
                      ),
                      borderRadius:
                      BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Checking inventory…',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(
        alpha: 0.45,
      ),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  final Animation<double> animation;

  const _ScannerOverlay({
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _ScannerPainter(
              progress: animation.value,
            ),
          );
        },
      ),
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double progress;

  _ScannerPainter({
    required this.progress,
  });

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final frameWidth = size.width * 0.78;
    const frameHeight = 190.0;

    final left =
        (size.width - frameWidth) / 2;

    final top =
        (size.height - frameHeight) / 2 - 20;

    final frameRect =
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        left,
        top,
        frameWidth,
        frameHeight,
      ),
      const Radius.circular(24),
    );

    final overlayPaint = Paint()
      ..color = Colors.black.withValues(
        alpha: 0.48,
      );

    final fullPath =
    Path()..addRect(
      Offset.zero & size,
    );

    final framePath =
    Path()..addRRect(frameRect);

    final combinedPath = Path.combine(
      PathOperation.difference,
      fullPath,
      framePath,
    );

    canvas.drawPath(
      combinedPath,
      overlayPaint,
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      frameRect,
      borderPaint,
    );

    final scanY =
        top + (frameHeight * progress);

    final scanPaint = Paint()
      ..color = const Color(0xFF2F66B0)
      ..strokeWidth = 3;

    canvas.drawLine(
      Offset(
        left + 16,
        scanY,
      ),
      Offset(
        left + frameWidth - 16,
        scanY,
      ),
      scanPaint,
    );

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;

    // Top-left
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(
        left + frameWidth - cornerLength,
        top,
      ),
      Offset(
        left + frameWidth,
        top,
      ),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(
        left + frameWidth,
        top,
      ),
      Offset(
        left + frameWidth,
        top + cornerLength,
      ),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(
        left,
        top + frameHeight - cornerLength,
      ),
      Offset(
        left,
        top + frameHeight,
      ),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(
        left,
        top + frameHeight,
      ),
      Offset(
        left + cornerLength,
        top + frameHeight,
      ),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(
        left + frameWidth - cornerLength,
        top + frameHeight,
      ),
      Offset(
        left + frameWidth,
        top + frameHeight,
      ),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(
        left + frameWidth,
        top + frameHeight - cornerLength,
      ),
      Offset(
        left + frameWidth,
        top + frameHeight,
      ),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(
      covariant _ScannerPainter oldDelegate,
      ) {
    return oldDelegate.progress != progress;
  }
}
