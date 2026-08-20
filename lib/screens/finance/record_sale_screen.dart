import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/product.dart';
import '../../models/sale.dart';

class RecordSaleScreen extends StatefulWidget {
  const RecordSaleScreen({super.key});

  @override
  State<RecordSaleScreen> createState() => _RecordSaleScreenState();
}

class _RecordSaleScreenState extends State<RecordSaleScreen> {
  final _db = DatabaseService();
  Product? _selectedProduct;
  final _quantityController = TextEditingController();
  bool _isLoading = false;

  Future<void> _recordSale() async {
    if (_selectedProduct == null || _quantityController.text.isEmpty) return;
    
    final qty = int.parse(_quantityController.text);
    if (qty > _selectedProduct!.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough stock')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final sale = Sale(
        productId: _selectedProduct!.id!,
        productName: _selectedProduct!.name,
        quantity: qty,
        unitPrice: _selectedProduct!.price,
        totalPrice: _selectedProduct!.price * qty,
      );
      await _db.recordSale(sale);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale recorded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Sale')),
      body: StreamBuilder<List<Product>>(
        stream: _db.getProductsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final products = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                DropdownButtonFormField<Product>(
                  initialValue: _selectedProduct,
                  hint: const Text('Select Product'),
                  items: products.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text('${p.name} (Stock: ${p.stock})'),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedProduct = val),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 30),
                if (_selectedProduct != null && _quantityController.text.isNotEmpty)
                  Text(
                    'Total: ₦${_selectedProduct!.price * (int.tryParse(_quantityController.text) ?? 0)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _recordSale,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                    child: const Text('Record Sale'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
