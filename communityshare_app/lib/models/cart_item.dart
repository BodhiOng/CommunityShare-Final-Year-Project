import 'product.dart';

class CartItem {
  final Product product;
  int quantity;
  bool isSelected; // For edit mode selection

  CartItem({
    required this.product,
    this.quantity = 1,
    this.isSelected = false,
  });

  double get totalPrice => product.price * quantity;
}
