import '../../services/initial_load_timeout.dart';
import '../../core/app_sizing.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/database_service.dart';
import '../../models/product.dart';
import '../../widgets/trexven_widgets.dart';
import 'catalog_editor_screen.dart';
import 'catalog_import_screen.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key, this.database});
  final DatabaseService? database;

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  late final DatabaseService _db;
  late Stream<List<Product>> _products;
  String _searchQuery = "";
  bool _showArchived = false;
  String? _category;

  @override
  void initState() {
    super.initState();
    _db = widget.database ?? DatabaseService();
    _products = withInitialLoadTimeout(_db.getProductsStream());
  }

  Future<void> _filters(List<Product> products) async {
    final categories = products.map((p) => p.category).whereType<String>().toSet().toList()..sort();
    await showDialog<void>(context:context,builder:(ctx) => StatefulBuilder(builder:(ctx,refresh) => AlertDialog(
      title:const Text('Inventory filters'),content:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButton<String>(value:categories.contains(_category) ? _category : null,hint:const Text('All categories'),isExpanded:true,
          items:[const DropdownMenuItem(value:null,child:Text('All categories')),for(final c in categories) DropdownMenuItem(value:c,child:Text(c))],
          onChanged:(v) { setState(() => _category = v);refresh(() {}); }),
        CheckboxListTile(contentPadding:EdgeInsets.zero,title:const Text('Include archived products'),value:_showArchived,
          onChanged:(v) { setState(() => _showArchived = v ?? false);refresh(() {}); }),
      ]),actions:[TextButton(onPressed:() => Navigator.pop(ctx),child:const Text('Done'))])));
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.trexvenColors.brandBlue ?? Colors.blue;
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CatalogEditorScreen(database:_db)),
          );
        },
        backgroundColor: brandBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _products,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to load inventory. Please retry.'),
                  TextButton(
                    onPressed: () => setState(
                      () => _products = withInitialLoadTimeout(
                        _db.getProductsStream(),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final allProducts = snapshot.data ?? [];
          final products = allProducts
              .where((p) => (_showArchived || p.active || p.isPricePending) &&
                (_category == null || p.category == _category) &&
                [p.name,p.barcode ?? '',p.sku ?? '',p.category ?? ''].any((v) => v.toLowerCase().contains(_searchQuery)))
              .toList();
          final lowStockCount = allProducts
              .where((p) => p.isLowStock)
              .length;
          final outOfStockCount = allProducts.where((p) => p.active && !p.isPricePending && p.stock == 0).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory',
                      style: TextStyle(
                        fontSize: AppSizing.pageTitle,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage products, quantities and stock.',
                      style: TextStyle(color: muted, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value.toLowerCase()),
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(suffixIcon:Row(mainAxisSize:MainAxisSize.min,children:[
                        IconButton(tooltip:'Inventory filters',icon:const Icon(Icons.filter_list),onPressed:() => _filters(allProducts)),
                        IconButton(tooltip:'Import products',icon:const Icon(Icons.upload_file),onPressed:() => Navigator.push(context,MaterialPageRoute(builder:(_) => CatalogImportScreen(database:_db)))),
                      ]),
                        hintText: 'Search products...',
                        hintStyle: TextStyle(color: muted.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.search, color: muted),
                        filled: true,
                        fillColor: theme.trexvenColors.cardBackground,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color:
                                theme.trexvenColors.border ??
                                const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color:
                                theme.trexvenColors.border ??
                                const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _miniStat('Products', '${allProducts.length}'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _miniStat('Low Stock', '$lowStockCount'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _miniStat('Out', '$outOfStockCount')),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? Center(child: CircularProgressIndicator(color: brandBlue))
                    : products.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 5, 16, 80),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final bool isLowStock = product.isLowStock;
                          final errorColor =
                              theme.trexvenColors.error ?? Colors.red;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TrexvenTapCard(
                              onTap: () {
                                Navigator.push(context,MaterialPageRoute(builder:(_) => CatalogEditorScreen(database:_db,product:product)));
                              },
                              borderRadius: 16,
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Text(
                                  product.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Text(
                                      'Stock: ${product.stock}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isLowStock ? errorColor : muted,
                                      ),
                                    ),
                                    if (isLowStock) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: errorColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'LOW',
                                          style: TextStyle(
                                            color: errorColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Text(
                                  '₦${product.price}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: brandBlue,
                                  ),
                                ),
                              ),
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
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: theme.trexvenColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchQuery.isEmpty
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded,
              size: 64,
              color: theme.trexvenColors.muted?.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No products yet' : 'No matches found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isEmpty
                  ? 'Start by adding your first product.'
                  : 'Try searching for something else.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.trexvenColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
