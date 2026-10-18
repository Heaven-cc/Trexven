import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/product.dart';

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
  (ref) => CartNotifier(),
);

class CartItem {
  final Product product;
  final num quantity;
  final double selectedPrice;
  final String priceLevel;
  final double discount;

  const CartItem({
    required this.product,
    this.quantity = 1,
    required this.selectedPrice,
    required this.priceLevel,this.discount=0,
  });

  double get total => ((BigInt.from((selectedPrice * 100).round()) * BigInt.from((quantity * 1000).round()) + BigInt.from(500)) ~/ BigInt.from(1000)).toInt() / 100 - discount;

  CartItem copyWith({
    Product? product,
    num? quantity,
    double? selectedPrice,
    String? priceLevel,
    double? discount,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedPrice: selectedPrice ?? this.selectedPrice,
      priceLevel: priceLevel ?? this.priceLevel,
      discount: discount ?? this.discount,
    );
  }
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super(const []);
  String checkoutRequestId = const Uuid().v4();
  @override
  set state(List<CartItem> value) {
    checkoutRequestId = const Uuid().v4();
    super.state = value;
  }

  /// Adds a product to the cart.
  ///
  /// If the same product with the same price level
  /// already exists, its quantity is increased.
  ///
  /// A different price level creates a separate
  /// cart line.
  void addProduct(Product product, double price, String level) {
    final normalizedLevel = level.trim().toLowerCase();

    final index = state.indexWhere(
      (item) =>
          item.product.id == product.id && item.priceLevel == normalizedLevel,
    );

    if (index == -1) {
      state = [
        ...state,
        CartItem(
          product: product,
          quantity: 1,
          selectedPrice: price,
          priceLevel: normalizedLevel,
        ),
      ];

      return;
    }

    final updatedItem = state[index].copyWith(
      quantity: state[index].quantity + 1,
    );

    final updatedCart = [...state];

    updatedCart[index] = updatedItem;

    state = updatedCart;
  }

  /// Removes an entire cart line.
  void removeProduct(String productId, String level) {
    final normalizedLevel = level.trim().toLowerCase();

    state = state
        .where(
          (item) =>
              !(item.product.id == productId &&
                  item.priceLevel == normalizedLevel),
        )
        .toList();
  }

  /// Updates the quantity of a cart item.
  ///
  /// Quantity <= 0 removes the item.
  void updateQuantity(String productId, String level, num quantity) {
    final normalizedLevel = level.trim().toLowerCase();

    final index = state.indexWhere(
      (item) =>
          item.product.id == productId && item.priceLevel == normalizedLevel,
    );

    if (index == -1) {
      return;
    }

    if (quantity <= 0) {
      removeProduct(productId, normalizedLevel);
      return;
    }

    if (!quantity.isFinite || quantity < 0 ||
        (quantity * 1000 - (quantity * 1000).round()).abs() > 0.0000001 ||
        (!state[index].product.supportsFractionalQuantity && quantity != quantity.truncate())) {
      throw ArgumentError('Use whole pieces or up to three decimal places for measurable units.');
    }
    if(state[index].discount>quantity*state[index].selectedPrice)throw ArgumentError('Adjust discount before reducing quantity.');
    final updatedItem = state[index].copyWith(quantity: quantity);

    final updatedCart = [...state];

    updatedCart[index] = updatedItem;

    state = updatedCart;
  }

  /// Increases a cart item's quantity by one.
  void increment(String productId, String level) {
    final item = _findItem(productId, level);

    if (item == null) {
      return;
    }

    updateQuantity(productId, level, item.quantity + 1);
  }

  /// Decreases a cart item's quantity by one.
  ///
  /// If the quantity reaches zero,
  /// the item is removed.
  void decrement(String productId, String level) {
    final item = _findItem(productId, level);

    if (item == null) {
      return;
    }

    updateQuantity(productId, level, item.quantity - 1);
  }

  void updateTerms(String productId,String level,double price,double discount){
    final index=state.indexWhere((i)=>i.product.id==productId&&i.priceLevel==level);
    if(index<0)return;
    if(!price.isFinite||price<0||!discount.isFinite||discount<0||discount>state[index].quantity*price||
      (price*100-(price*100).round()).abs()>0.000001||(discount*100-(discount*100).round()).abs()>0.000001){
      throw ArgumentError('Use valid prices and discounts with two decimal places.');
    }
    state=[for(var i=0;i<state.length;i++)i==index?state[i].copyWith(selectedPrice:price,discount:discount):state[i]];
  }

  /// Completely empties the cart.
  void clear() {
    state = const [];
  }

  /// Number of individual units in the cart.
  num get itemCount {
    final units = state.fold<int>(0, (sum, item) => sum + (item.quantity * 1000).round());
    return units % 1000 == 0 ? units ~/ 1000 : units / 1000;
  }

  /// Number of different cart lines.
  int get uniqueItemCount {
    return state.length;
  }

  /// Total monetary value of the cart.
  double get total {
    return state.fold<int>(0, (sum, item) => sum + (item.total * 100).round()) /
        100;
  }

  /// Returns true when the cart contains
  /// at least one item.
  bool get isNotEmpty => state.isNotEmpty;

  /// Returns true when the cart is empty.
  bool get isEmpty => state.isEmpty;

  /// Finds a specific cart item.
  CartItem? _findItem(String productId, String level) {
    final normalizedLevel = level.trim().toLowerCase();

    for (final item in state) {
      if (item.product.id == productId && item.priceLevel == normalizedLevel) {
        return item;
      }
    }

    return null;
  }
}
