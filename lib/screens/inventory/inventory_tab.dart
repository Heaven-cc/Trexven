import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/product.dart';
import 'add_product_screen.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final DatabaseService _db = DatabaseService();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    const Color dark = Color(0xFF0F172A);
    const Color muted = Color(0xFF64748B);
    const Color border = Color(0xFFE2E8F0);
    const Color blue = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          );
        },
        backgroundColor: blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _db.getProductsStream(),
        builder: (context, snapshot) {
          final allProducts = snapshot.data ?? [];
          final products = allProducts.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
          final lowStockCount = allProducts.where((p) => p.stock <= 5 && p.stock > 0).length;
          final outOfStockCount = allProducts.where((p) => p.stock == 0).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inventory',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: dark),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Manage products, quantities and stock.',
                      style: TextStyle(color: muted, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: const Icon(Icons.search, color: muted),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _miniStat('Products', '${allProducts.length}')),
                        const SizedBox(width: 10),
                        Expanded(child: _miniStat('Low Stock', '$lowStockCount')),
                        const SizedBox(width: 10),
                        Expanded(child: _miniStat('Out', '$outOfStockCount')),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : products.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 5, 20, 80),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];
                              final bool isLowStock = product.stock <= 5;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: dark)),
                                  subtitle: Row(
                                    children: [
                                      Text(
                                        'Stock: ${product.stock}',
                                        style: TextStyle(fontWeight: FontWeight.w600, color: isLowStock ? Colors.red : muted),
                                      ),
                                      if (isLowStock) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                                          child: const Text('LOW', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: Text('₦${product.price}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: blue)),
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _miniStat(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 3),
          Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty ? Icons.inventory_2_outlined : Icons.search_off_rounded,
            size: 64,
            color: const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No products yet' : 'No matches found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isEmpty ? 'Start by adding your first product.' : 'Try searching for something else.',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
