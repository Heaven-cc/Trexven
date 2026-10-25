
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:trexven_design_system/trexven_design_system.dart';

import '../../services/initial_load_timeout.dart';
import '../../services/database_service.dart';
import '../../models/product.dart';

import 'catalog_editor_screen.dart';
import 'catalog_import_screen.dart';
import 'add_product_screen.dart';
import 'scanner_screen.dart';
import 'angel_scan_review_screen.dart';
import 'angel_auto_camera_screen.dart';
import '../../services/angel_scan_client.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({
    super.key,
    this.database,
  });

  final DatabaseService? database;

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  late final DatabaseService _db;
  late Stream<List<Product>> _products;
  String _currency = 'NGN';

  final TextEditingController _searchController =
  TextEditingController();

  final FocusNode _searchFocus = FocusNode();

  String _searchQuery = '';
  String? _category;

  bool _showArchived = false;
  bool _lowStockOnly = false;

  String _sort = 'name';
  static const int _batchSize = 20;
  int _visibleCount = _batchSize;

  Color get _background => Theme.of(context).scaffoldBackgroundColor;
  Color get _card => Theme.of(context).trexvenColors.cardBackground ??
      Theme.of(context).colorScheme.surfaceContainerLow;
  Color get _navy => Theme.of(context).colorScheme.onSurface;
  Color get _blue => Theme.of(context).trexvenColors.brandBlue ??
      Theme.of(context).colorScheme.primary;
  Color get _muted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _softBlue => _blue.withValues(alpha: .12);

  @override
  void initState() {
    super.initState();

    _db = widget.database ?? DatabaseService();

    _products = withInitialLoadTimeout(
      _db.getProductsStream(),
    );
    _loadCurrency();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCurrency() async {
    try {
      final id = await _db.requireBusinessId();
      final row = await Supabase.instance.client.from('businesses')
          .select('currency').eq('id',id).single();
      final code = row['currency']?.toString().trim().toUpperCase();
      if (mounted && code != null && RegExp(r'^[A-Z]{3}
    setState(() {
      _visibleCount = _batchSize;
      _products = withInitialLoadTimeout(
        _db.getProductsStream(),
      );
    });
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
    if (mounted) _retry();
  }

  void _restock() {
    _openScreen(
      AddProductScreen(
        database: _db,
        startInRestock: true,
      ),
    );
  }

  Future<void> _openOperations() async {
    try {
      final businessId = await _db.requireBusinessId();
      if (!mounted) return;
      await _openScreen(InventoryOperationsScreen(
        api: OperationsClient(Supabase.instance.client, businessId),
        scanBarcode: (context) => Navigator.push<String>(
          context, MaterialPageRoute(builder: (_) => const ScannerScreen())),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(CustomerPresentation.error(error,
          fallback: 'Unable to open stock operations. Check business access.')),
      ));
    }
  }

  Future<void> _scan() async {
    try {
      final business = await _db.requireBusinessId();
      final client = Supabase.instance.client;
      final owner = client.auth.currentUser?.id;
      final row = await client.from('businesses')
          .select('owner_id,branches_enabled').eq('id',business).single();
      if (owner == null || row['owner_id'] != owner) throw StateError('Owner required');
      String? branch;
      if (row['branches_enabled'] == true) {
        final branches = await client.from('branches').select('id,name')
            .eq('business_id',business).eq('is_active',true).order('name');
        if (!mounted) return;
        branch = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
          title: const Text('Select inventory branch'),
          children: [
            for(final item in branches)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx,item['id'].toString()),
                child: Text(item['name'].toString()),
              ),
          ],
        ));
        if (branch == null) return;
      }
      if (!mounted) return;
      final api = AngelScanClient(client, businessId:business, branchId:branch, inventoryMode:true);
      await _openScreen(AngelAutoCameraScreen(
        api:api,
        contextIsCurrent: () => client.auth.currentUser?.id == owner,
        onRecognized:(items,sourceHash) async {
          if (!mounted) return;
          await Navigator.push<void>(context, MaterialPageRoute(builder: (_) =>
            AngelScanReviewScreen(
              api:api,
              owner:true,
              initialItems:items,
              automaticSourceHash:sourceHash,
            ),
          ));
        },
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Unable to open Angel Scan. Verify camera and owner access.'),
      ));
    }
  }

  Future<void> _showCategoryFilters(
      List<Product> products,
      ) async {
    final categories = products
        .map((p) => p.category)
        .whereType<String>()
        .where((c) => c.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Inherit the unified TREXVEN bottom sheet appearance.
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, refresh) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20, 22, 20, 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory filters',
                      style: TextStyle(
                        color: _navy,
                        fontSize: TrexvenFontSize.section,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 18),

                    Text(
                      'Category',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _categoryChoice(
                          'All categories',
                          _category == null,
                              () {
                            setState(() {
                              _visibleCount = _batchSize;
                              _category = null;
                            });
                            refresh(() {});
                          },
                        ),

                        for (final category in categories)
                          _categoryChoice(
                            category,
                            _category == category,
                                () {
                              setState(() {
                                _visibleCount = _batchSize;
                              _category = category;
                              });
                              refresh(() {});
                            },
                          ),
                      ],
                    ),

                    SizedBox(height: 16),

                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Include archived products',
                      ),
                      value: _showArchived,
                      activeTrackColor: _blue,
                      onChanged: (value) {
                        setState(() {
                          _visibleCount = _batchSize;
                          _showArchived = value;
                        });
                        refresh(() {});
                      },
                    ),

                    SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(13),
                          ),
                        ),
                        child: Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _categoryChoice(
      String label,
      bool selected,
      VoidCallback onTap,
      ) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _softBlue,
      backgroundColor: _background,
      side: BorderSide.none,
      labelStyle: TextStyle(
        color: selected ? _blue : _muted,
        fontWeight:
        selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Future<void> _showSortOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      // Inherit the unified TREXVEN bottom sheet appearance.
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20, 22, 20, 22,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Sort products',
                  style: TextStyle(
                    color: _navy,
                    fontSize: TrexvenFontSize.section,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 12),

                RadioListTile<String>(
                  title: Text('Name'),
                  value: 'name',
                  groupValue: _sort,
                  activeColor: _blue,
                  onChanged: (value) {
                    setState(() {
                      _visibleCount = _batchSize;
                        _sort = value ?? 'name';
                    });
                    Navigator.pop(sheetContext);
                  },
                ),

                RadioListTile<String>(
                  title: Text('Stock quantity'),
                  value: 'stock',
                  groupValue: _sort,
                  activeColor: _blue,
                  onChanged: (value) {
                    setState(() {
                      _visibleCount = _batchSize;
                        _sort = value ?? 'stock';
                    });
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: _buildBottomActions(),
        ),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _products,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TrexvenErrorState(
                message:
                'Unable to load inventory. Please retry.',
                onRetry: _retry,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const TrexvenSkeleton(kind: TrexvenSkeletonKind.inventory);
          }

          final allProducts = snapshot.data!;

          final products = allProducts.where((p) {
            final visible =
                _showArchived ||
                    p.active ||
                    p.isPricePending;

            final categoryMatches =
                _category == null ||
                    p.category == _category;

            final stockMatches =
                !_lowStockOnly || p.isLowStock;

            final query = _searchQuery.trim().toLowerCase();

            final searchMatches =
                query.isEmpty ||
                    [
                      p.name,
                      p.barcode ?? '',
                      p.sku ?? '',
                      p.category ?? '',
                    ].any(
                          (value) => value
                          .toLowerCase()
                          .contains(query),
                    );

            return visible &&
                categoryMatches &&
                stockMatches &&
                searchMatches;
          }).toList();

          products.sort((a, b) {
            if (_sort == 'stock') {
              return a.stock.compareTo(b.stock);
            }

            return a.name
                .toLowerCase()
                .compareTo(b.name.toLowerCase());
          });

          final visibleProducts = products.take(_visibleCount).toList();

          final activeProducts = allProducts
              .where(
                (p) => p.active || p.isPricePending,
          )
              .toList();

          final lowStockCount = activeProducts
              .where((p) => p.isLowStock)
              .length;

          final outOfStockCount = allProducts
              .where(
                (p) =>
            p.active &&
                !p.isPricePending &&
                p.stock == 0,
          )
              .length;

          return CustomScrollView(
              physics:
              AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16, 20, 16, 0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),

                        SizedBox(height: 17),

                        _buildSearch(),

                        SizedBox(height: 14),

                        _buildStatistics(
                          activeProducts.length,
                          lowStockCount,
                          outOfStockCount,
                        ),

                        SizedBox(height: 18),

                        _secondaryAction(
                          icon: Icons.fact_check_outlined,
                          title: 'Stocktaking & stock management',
                          onTap: _openOperations,
                        ),
                        SizedBox(height: 16),
                        _buildProductsHeading(),

                        SizedBox(height: 16),

                        _buildFilterBar(allProducts),

                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                if (products.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding:
                    EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    sliver: SliverList.builder(
                      itemCount: visibleProducts.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding:
                          EdgeInsets.only(
                            bottom: 10,
                          ),
                          child: _buildProductCard(
                            visibleProducts[index],
                          ),
                        );
                      },
                    ),
                  ),
                if (products.length > visibleProducts.length)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _visibleCount += _batchSize;
                        }),
                        child: Text(
                          'Show more products (${visibleProducts.length} of ${products.length})',
                        ),
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),
              ],
            );
        },
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Inventory', style: TextStyle(color: _navy,
        fontSize: 24, fontWeight: FontWeight.w700)),
      SizedBox(height: 5),
      Text('Products and stock management',
        style: TextStyle(color: _muted, fontSize: 13)),
    ])),
  ]);

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          setState(() {
            _visibleCount = _batchSize;
            _searchQuery = value.toLowerCase();
          });
        },
        style: TextStyle(
          color: _navy,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText:
          'Search name, barcode, category or SKU',
          hintStyle: TextStyle(
            color: _muted,
            fontSize: 12,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _muted,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
            ),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
          EdgeInsets.symmetric(
            vertical: 17,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // THREE COMPACT STATISTICS CARDS
  // ============================================================

  Widget _buildStatistics(int products, int lowStock, int outOfStock) {
    final values = [('$products', 'Products'), ('$lowStock', 'Low stock'),
      ('$outOfStock', 'Out of stock')];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card,
        borderRadius: BorderRadius.circular(TrexvenRadii.card)),
      child: LayoutBuilder(builder: (context, constraints) {
        final metrics = [
          for (final item in values)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.$1, style: TextStyle(color: _navy,
                fontSize: 25, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(item.$2, style: TextStyle(color: _muted, fontSize: 12)),
            ]),
        ];
        if (constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Wrap(spacing: 24, runSpacing: 16, children: metrics);
        }
        return Row(children: [for (final metric in metrics) Expanded(child: metric)]);
      }),
    );
  }

  // ============================================================
  // ALL PRODUCTS HEADER
  // ============================================================

  Widget _buildProductsHeading() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'All products',
            style: TextStyle(
              color: _navy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FILTER BAR
  // ============================================================

  Widget _buildFilterBar(
      List<Product> products,
      ) {
    return Row(
      children: [
        Expanded(
          flex: 11,
          child: _filterButton(
            text: _lowStockOnly
                ? 'Low stock'
                : 'All  |  Low stock',
            selected: true,
            onTap: () {
              setState(() {
                _visibleCount = _batchSize;
                  _lowStockOnly = !_lowStockOnly;
              });
            },
          ),
        ),

        SizedBox(width: 8),

        Expanded(
          flex: 10,
          child: _filterButton(
            text: _category ?? 'Category',
            selected: _category != null,
            onTap: () {
              _showCategoryFilters(products);
            },
          ),
        ),

        SizedBox(width: 8),

        Expanded(
          flex: 10,
          child: _filterButton(
            text: _sort == 'name'
                ? 'Sort by'
                : 'Stock ↑',
            selected: _sort == 'stock',
            onTap: _showSortOptions,
          ),
        ),
      ],
    );
  }

  Widget _filterButton({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? _softBlue : _card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: 8, vertical: 10,
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? _blue : _muted,
              fontSize: 11,
              fontWeight: selected
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCT CARD
  // ============================================================

  Widget _buildProductCard(
      Product product,
      ) {
    final currency = NumberFormat.currency(
      symbol: '$_currency ',
      decimalDigits: 2,
    );

    final price = product.isPricePending
        ? 'Price pending'
        : currency.format(product.price);

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          _openScreen(
            CatalogEditorScreen(
              database: _db,
              product: product,
            ),
          );
        },
        child: Container(
          constraints:
          BoxConstraints(minHeight: 88),
          padding: EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 13,
          ),
          child: Row(
            children: [
              Container(
                width: 53,
                height: 53,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _softBlue,
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: product.imageUrl?.trim().isNotEmpty == true
                    ? Image.network(product.imageUrl!, width: 53, height: 53,
                        fit: BoxFit.cover, cacheWidth: 160,
                        errorBuilder: (_, _, _) => Icon(Icons.inventory_2_outlined,
                          color: _blue, size: 25))
                    : Icon(Icons.inventory_2_outlined, color: _blue, size: 25),
              ),

              SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    SizedBox(height: 7),

                    Text(
                      'Catalog stock: ${product.stock} ${product.unit}',
                      style: TextStyle(
                        color: product.isLowStock
                            ? Color(0xFFDC633F)
                            : _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8),

              Flexible(
                child: Text(
                  price,
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _blue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM ACTIONS
  // ============================================================

  Widget _buildBottomActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _bottomAction(
                'Scan',
                _scan,
              ),
            ),

            SizedBox(width: 10),

            Expanded(
              child: _bottomAction(
                'Restock',
                _restock,
              ),
            ),
          ],
        ),

        SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _secondaryAction(
                icon: Icons.upload_file_outlined,
                title: 'Import products',
                onTap: () {
                  _openScreen(
                    CatalogImportScreen(
                      database: _db,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bottomAction(
      String title,
      VoidCallback onTap,
      ) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: _navy,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _secondaryAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: _blue,
        size: 18,
      ),
      label: Text(
        title,
        style: TextStyle(
          color: _blue,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final isSearching =
        _searchQuery.isNotEmpty ||
            _category != null ||
            _lowStockOnly;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 36,
      ),
      child: Column(
        children: [
          Icon(
            isSearching
                ? Icons.search_off_rounded
                : Icons.inventory_2_outlined,
            size: 48,
            color: _muted.withValues(alpha: 0.5),
          ),

          SizedBox(height: 12),

          Text(
            isSearching
                ? 'No matches found'
                : 'No products yet',
            style: TextStyle(
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          SizedBox(height: 5),

          Text(
            isSearching
                ? 'Try adjusting your search or filters.'
                : 'Start by adding your first product.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

).hasMatch(code)) {
        setState(() => _currency = code);
      }
    } catch (_) { /* Keep NGN display fallback until business metadata is available. */ }
  }

  void _retry() {
    setState(() {
      _visibleCount = _batchSize;
      _products = withInitialLoadTimeout(
        _db.getProductsStream(),
      );
    });
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
    if (mounted) _retry();
  }

  void _restock() {
    _openScreen(
      AddProductScreen(
        database: _db,
        startInRestock: true,
      ),
    );
  }

  Future<void> _openOperations() async {
    try {
      final businessId = await _db.requireBusinessId();
      if (!mounted) return;
      await _openScreen(InventoryOperationsScreen(
        api: OperationsClient(Supabase.instance.client, businessId),
        scanBarcode: (context) => Navigator.push<String>(
          context, MaterialPageRoute(builder: (_) => const ScannerScreen())),
      ));
      if (mounted) _retry();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(CustomerPresentation.error(error,
          fallback: 'Unable to open stock operations. Check business access.')),
      ));
    }
  }

  Future<void> _scan() async {
    try {
      final business = await _db.requireBusinessId();
      final client = Supabase.instance.client;
      final owner = client.auth.currentUser?.id;
      final row = await client.from('businesses')
          .select('owner_id,branches_enabled').eq('id',business).single();
      if (owner == null || row['owner_id'] != owner) throw StateError('Owner required');
      String? branch;
      if (row['branches_enabled'] == true) {
        final branches = await client.from('branches').select('id,name')
            .eq('business_id',business).eq('is_active',true).order('name');
        if (!mounted) return;
        branch = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
          title: const Text('Select inventory branch'),
          children: [
            for(final item in branches)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx,item['id'].toString()),
                child: Text(item['name'].toString()),
              ),
          ],
        ));
        if (branch == null) return;
      }
      if (!mounted) return;
      final api = AngelScanClient(client, businessId:business, branchId:branch, inventoryMode:true);
      await _openScreen(AngelAutoCameraScreen(
        api:api,
        contextIsCurrent: () => client.auth.currentUser?.id == owner,
        onRecognized:(items,sourceHash) async {
          if (!mounted) return;
          await Navigator.push<void>(context, MaterialPageRoute(builder: (_) =>
            AngelScanReviewScreen(
              api:api,
              owner:true,
              initialItems:items,
              automaticSourceHash:sourceHash,
            ),
          ));
          if (mounted) _retry();
        },
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Unable to open Angel Scan. Verify camera and owner access.'),
      ));
    }
  }

  Future<void> _showCategoryFilters(
      List<Product> products,
      ) async {
    final categories = products
        .map((p) => p.category)
        .whereType<String>()
        .where((c) => c.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Inherit the unified TREXVEN bottom sheet appearance.
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, refresh) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20, 22, 20, 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory filters',
                      style: TextStyle(
                        color: _navy,
                        fontSize: TrexvenFontSize.section,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 18),

                    Text(
                      'Category',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _categoryChoice(
                          'All categories',
                          _category == null,
                              () {
                            setState(() {
                              _visibleCount = _batchSize;
                              _category = null;
                            });
                            refresh(() {});
                          },
                        ),

                        for (final category in categories)
                          _categoryChoice(
                            category,
                            _category == category,
                                () {
                              setState(() {
                                _visibleCount = _batchSize;
                              _category = category;
                              });
                              refresh(() {});
                            },
                          ),
                      ],
                    ),

                    SizedBox(height: 16),

                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Include archived products',
                      ),
                      value: _showArchived,
                      activeTrackColor: _blue,
                      onChanged: (value) {
                        setState(() {
                          _visibleCount = _batchSize;
                          _showArchived = value;
                        });
                        refresh(() {});
                      },
                    ),

                    SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(13),
                          ),
                        ),
                        child: Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _categoryChoice(
      String label,
      bool selected,
      VoidCallback onTap,
      ) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _softBlue,
      backgroundColor: _background,
      side: BorderSide.none,
      labelStyle: TextStyle(
        color: selected ? _blue : _muted,
        fontWeight:
        selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Future<void> _showSortOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      // Inherit the unified TREXVEN bottom sheet appearance.
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20, 22, 20, 22,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Sort products',
                  style: TextStyle(
                    color: _navy,
                    fontSize: TrexvenFontSize.section,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 12),

                RadioListTile<String>(
                  title: Text('Name'),
                  value: 'name',
                  groupValue: _sort,
                  activeColor: _blue,
                  onChanged: (value) {
                    setState(() {
                      _visibleCount = _batchSize;
                        _sort = value ?? 'name';
                    });
                    Navigator.pop(sheetContext);
                  },
                ),

                RadioListTile<String>(
                  title: Text('Stock quantity'),
                  value: 'stock',
                  groupValue: _sort,
                  activeColor: _blue,
                  onChanged: (value) {
                    setState(() {
                      _visibleCount = _batchSize;
                        _sort = value ?? 'stock';
                    });
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: _buildBottomActions(),
        ),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _products,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TrexvenErrorState(
                message:
                'Unable to load inventory. Please retry.',
                onRetry: _retry,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const TrexvenSkeleton(kind: TrexvenSkeletonKind.inventory);
          }

          final allProducts = snapshot.data!;

          final products = allProducts.where((p) {
            final visible =
                _showArchived ||
                    p.active ||
                    p.isPricePending;

            final categoryMatches =
                _category == null ||
                    p.category == _category;

            final stockMatches =
                !_lowStockOnly || p.isLowStock;

            final query = _searchQuery.trim().toLowerCase();

            final searchMatches =
                query.isEmpty ||
                    [
                      p.name,
                      p.barcode ?? '',
                      p.sku ?? '',
                      p.category ?? '',
                    ].any(
                          (value) => value
                          .toLowerCase()
                          .contains(query),
                    );

            return visible &&
                categoryMatches &&
                stockMatches &&
                searchMatches;
          }).toList();

          products.sort((a, b) {
            if (_sort == 'stock') {
              return a.stock.compareTo(b.stock);
            }

            return a.name
                .toLowerCase()
                .compareTo(b.name.toLowerCase());
          });

          final visibleProducts = products.take(_visibleCount).toList();

          final activeProducts = allProducts
              .where(
                (p) => p.active || p.isPricePending,
          )
              .toList();

          final lowStockCount = activeProducts
              .where((p) => p.isLowStock)
              .length;

          final outOfStockCount = allProducts
              .where(
                (p) =>
            p.active &&
                !p.isPricePending &&
                p.stock == 0,
          )
              .length;

          return RefreshIndicator(
            onRefresh: () async {
              _retry();
            },
            color: _blue,
            child: CustomScrollView(
              physics:
              AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16, 20, 16, 0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),

                        SizedBox(height: 17),

                        _buildSearch(),

                        SizedBox(height: 14),

                        _buildStatistics(
                          activeProducts.length,
                          lowStockCount,
                          outOfStockCount,
                        ),

                        SizedBox(height: 18),

                        _secondaryAction(
                          icon: Icons.fact_check_outlined,
                          title: 'Stocktaking & stock management',
                          onTap: _openOperations,
                        ),
                        SizedBox(height: 16),
                        _buildProductsHeading(),

                        SizedBox(height: 16),

                        _buildFilterBar(allProducts),

                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                if (products.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding:
                    EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    sliver: SliverList.builder(
                      itemCount: visibleProducts.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding:
                          EdgeInsets.only(
                            bottom: 10,
                          ),
                          child: _buildProductCard(
                            visibleProducts[index],
                          ),
                        );
                      },
                    ),
                  ),
                if (products.length > visibleProducts.length)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _visibleCount += _batchSize;
                        }),
                        child: Text(
                          'Show more products (${visibleProducts.length} of ${products.length})',
                        ),
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Inventory', style: TextStyle(color: _navy,
        fontSize: 24, fontWeight: FontWeight.w700)),
      SizedBox(height: 5),
      Text('Products and stock management',
        style: TextStyle(color: _muted, fontSize: 13)),
    ])),
  ]);

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          setState(() {
            _visibleCount = _batchSize;
            _searchQuery = value.toLowerCase();
          });
        },
        style: TextStyle(
          color: _navy,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText:
          'Search name, barcode, category or SKU',
          hintStyle: TextStyle(
            color: _muted,
            fontSize: 12,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _muted,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
            ),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
          EdgeInsets.symmetric(
            vertical: 17,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // THREE COMPACT STATISTICS CARDS
  // ============================================================

  Widget _buildStatistics(int products, int lowStock, int outOfStock) {
    final values = [('$products', 'Products'), ('$lowStock', 'Low stock'),
      ('$outOfStock', 'Out of stock')];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card,
        borderRadius: BorderRadius.circular(TrexvenRadii.card)),
      child: LayoutBuilder(builder: (context, constraints) {
        final metrics = [
          for (final item in values)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.$1, style: TextStyle(color: _navy,
                fontSize: 25, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(item.$2, style: TextStyle(color: _muted, fontSize: 12)),
            ]),
        ];
        if (constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Wrap(spacing: 24, runSpacing: 16, children: metrics);
        }
        return Row(children: [for (final metric in metrics) Expanded(child: metric)]);
      }),
    );
  }

  // ============================================================
  // ALL PRODUCTS HEADER
  // ============================================================

  Widget _buildProductsHeading() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'All products',
            style: TextStyle(
              color: _navy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FILTER BAR
  // ============================================================

  Widget _buildFilterBar(
      List<Product> products,
      ) {
    return Row(
      children: [
        Expanded(
          flex: 11,
          child: _filterButton(
            text: _lowStockOnly
                ? 'Low stock'
                : 'All  |  Low stock',
            selected: true,
            onTap: () {
              setState(() {
                _visibleCount = _batchSize;
                  _lowStockOnly = !_lowStockOnly;
              });
            },
          ),
        ),

        SizedBox(width: 8),

        Expanded(
          flex: 10,
          child: _filterButton(
            text: _category ?? 'Category',
            selected: _category != null,
            onTap: () {
              _showCategoryFilters(products);
            },
          ),
        ),

        SizedBox(width: 8),

        Expanded(
          flex: 10,
          child: _filterButton(
            text: _sort == 'name'
                ? 'Sort by'
                : 'Stock ↑',
            selected: _sort == 'stock',
            onTap: _showSortOptions,
          ),
        ),
      ],
    );
  }

  Widget _filterButton({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? _softBlue : _card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: 8, vertical: 10,
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? _blue : _muted,
              fontSize: 11,
              fontWeight: selected
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCT CARD
  // ============================================================

  Widget _buildProductCard(
      Product product,
      ) {
    final currency = NumberFormat.currency(
      symbol: 'NGN ',
      decimalDigits: 2,
    );

    final price = product.isPricePending
        ? 'Price pending'
        : currency.format(product.price);

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          _openScreen(
            CatalogEditorScreen(
              database: _db,
              product: product,
            ),
          );
        },
        child: Container(
          constraints:
          BoxConstraints(minHeight: 88),
          padding: EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 13,
          ),
          child: Row(
            children: [
              Container(
                width: 53,
                height: 53,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _softBlue,
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: product.imageUrl?.trim().isNotEmpty == true
                    ? Image.network(product.imageUrl!, width: 53, height: 53,
                        fit: BoxFit.cover, cacheWidth: 160,
                        errorBuilder: (_, _, _) => Icon(Icons.inventory_2_outlined,
                          color: _blue, size: 25))
                    : Icon(Icons.inventory_2_outlined, color: _blue, size: 25),
              ),

              SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    SizedBox(height: 7),

                    Text(
                      'Catalog stock: ${product.stock} ${product.unit}',
                      style: TextStyle(
                        color: product.isLowStock
                            ? Color(0xFFDC633F)
                            : _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8),

              Flexible(
                child: Text(
                  price,
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _blue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM ACTIONS
  // ============================================================

  Widget _buildBottomActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _bottomAction(
                'Scan',
                _scan,
              ),
            ),

            SizedBox(width: 10),

            Expanded(
              child: _bottomAction(
                'Restock',
                _restock,
              ),
            ),
          ],
        ),

        SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _secondaryAction(
                icon: Icons.upload_file_outlined,
                title: 'Import products',
                onTap: () {
                  _openScreen(
                    CatalogImportScreen(
                      database: _db,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bottomAction(
      String title,
      VoidCallback onTap,
      ) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: _navy,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _secondaryAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: _blue,
        size: 18,
      ),
      label: Text(
        title,
        style: TextStyle(
          color: _blue,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final isSearching =
        _searchQuery.isNotEmpty ||
            _category != null ||
            _lowStockOnly;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 36,
      ),
      child: Column(
        children: [
          Icon(
            isSearching
                ? Icons.search_off_rounded
                : Icons.inventory_2_outlined,
            size: 48,
            color: _muted.withValues(alpha: 0.5),
          ),

          SizedBox(height: 12),

          Text(
            isSearching
                ? 'No matches found'
                : 'No products yet',
            style: TextStyle(
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          SizedBox(height: 5),

          Text(
            isSearching
                ? 'Try adjusting your search or filters.'
                : 'Start by adding your first product.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

