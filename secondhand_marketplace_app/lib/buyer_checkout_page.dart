import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondhand_marketplace_app/constants.dart';
import 'package:secondhand_marketplace_app/models/cart_item.dart';
import 'package:secondhand_marketplace_app/buyer_order_confirmation_page.dart';

class CheckoutPage extends StatefulWidget {
  final List<CartItem> cartItems;
  final bool isBargainPurchase;

  const CheckoutPage({
    super.key, 
    required this.cartItems,
    this.isBargainPurchase = false,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late List<CartItem> _cartItems;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _cartItems = List.from(widget.cartItems);
    _saveCartItemsToLocalStorage();
  }
  
  // Save cart items to local storage
  Future<void> _saveCartItemsToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _auth.currentUser?.uid ?? 'guest';
      
      final List<Map<String, dynamic>> cartItemsJson = _cartItems.map((item) {
        return {
          'productId': item.product.id,
          'name': item.product.name,
          'price': item.product.price,
          'imageUrl': item.product.imageUrl,
          'condition': item.product.condition,
          'sellerId': item.product.sellerId,
          'category': item.product.category,
          'quantity': item.quantity,
          'isSelected': item.isSelected,
        };
      }).toList();
      
      await prefs.setString('cart_$userId', jsonEncode(cartItemsJson));
      debugPrint('Cart saved to local storage: ${_cartItems.length} items');
    } catch (e) {
      debugPrint('Error saving cart items: $e');
    }
  }
  
  // Clear cart items from local storage
  Future<void> _clearCartItemsFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _auth.currentUser?.uid ?? 'guest';
      await prefs.remove('cart_$userId');
    } catch (e) {
      debugPrint('Error clearing cart items: $e');
    }
  }

  // Calculate total price of all items in cart
  double get _totalPrice {
    return _cartItems.fold(0, (total, item) => total + item.totalPrice);
  }

  // Update quantity of an item
  void _updateQuantity(int index, int change) {
    setState(() {
      int newQuantity = _cartItems[index].quantity + change;
      if (newQuantity > 0) {
        if (change > 0 && newQuantity > _cartItems[index].product.stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot add more. Only ${_cartItems[index].product.stock} items in stock.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        _cartItems[index].quantity = newQuantity;
        _saveCartItemsToLocalStorage();
      } else {
        _showRemoveItemDialog(index);
      }
    });
  }

  // Show dialog to confirm item removal
  void _showRemoveItemDialog(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.deepSlateGray,
        title: Text(
          'Remove Item',
          style: TextStyle(color: AppColors.coolGray),
        ),
        content: Text(
          'Are you sure you want to remove ${_cartItems[index].product.name} from your cart?',
          style: TextStyle(color: AppColors.coolGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.mutedTeal),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _cartItems.removeAt(index);
                _saveCartItemsToLocalStorage();
              });
              Navigator.pop(context);
            },
            child: Text(
              'Remove',
              style: TextStyle(color: AppColors.warmCoral),
            ),
          ),
        ],
      ),
    );
  }

  // Proceed to checkout
  void _proceedToCheckout() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You need to be logged in to checkout')),
          );
        }
        return;
      }
      
      // Get user's wallet balance
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User profile not found')),
          );
        }
        return;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final walletBalance = (userData['walletBalance'] ?? 0.0).toDouble();
      
      // Check if wallet has enough balance
      if (walletBalance < _totalPrice) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Insufficient wallet balance. Please top up your wallet.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Process each cart item as an order
      final firestoreTimestamp = Timestamp.now();
      final batch = _firestore.batch();
      
      // Update wallet balance
      batch.update(
        _firestore.collection('users').doc(userId),
        {'walletBalance': FieldValue.increment(-_totalPrice)}
      );
      
      // Create orders
      for (var item in _cartItems) {
        // Generate unique IDs with shorter format
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final randomPart = timestamp.length > 8 ? timestamp.substring(timestamp.length - 8) : timestamp;
        final orderId = 'order_$randomPart';
        final buyerTransactionId = 'transaction_$randomPart';
        final sellerTransactionId = 'transaction_${(int.parse(randomPart) + 1).toString().padLeft(8, '0')}';
        
        // Get product reference to update stock
        final productRef = _firestore.collection('products').doc(item.product.id);
        
        // Reduce product stock based on quantity ordered
        batch.update(
          productRef,
          {'stock': FieldValue.increment(-item.quantity)}
        );
        
        // Add order to orders collection
        batch.set(
          _firestore.collection('orders').doc(orderId),
          {
            'id': orderId,
            'buyerId': userId,
            'sellerId': item.product.sellerId,
            'productId': item.product.id,
            'quantity': item.quantity,
            'originalPrice': item.product.price,
            'price': item.totalPrice,
            'purchaseDate': firestoreTimestamp,
            'status': 'Pending',
          }
        );
        
        // Add buyer transaction (negative amount)
        batch.set(
          _firestore.collection('walletTransactions').doc(buyerTransactionId),
          {
            'id': buyerTransactionId,
            'userId': userId,
            'type': 'Purchase',
            'amount': -item.totalPrice, // Negative amount for buyer
            'description': 'Payment for order $orderId',
            'relatedOrderId': orderId,
            'timestamp': firestoreTimestamp,
          }
        );
        
        // Add seller transaction (positive amount)
        batch.set(
          _firestore.collection('walletTransactions').doc(sellerTransactionId),
          {
            'id': sellerTransactionId,
            'userId': item.product.sellerId,
            'type': 'Sale',
            'amount': item.totalPrice, // Positive amount for seller
            'description': 'Product sale',
            'relatedOrderId': orderId,
            'timestamp': firestoreTimestamp,
          }
        );
      }
      
      // Commit all operations
      await batch.commit();
      
      // Clear cart from local storage
      await _clearCartItemsFromLocalStorage();
      
      // Navigate to the order confirmation page
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const OrderConfirmationPage(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error during checkout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during checkout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: AppColors.deepSlateGray,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Cart items list
          Expanded(
            child: _buildCartItemsList(),
          ),
          // Checkout summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.deepSlateGray,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.coolGray,
                      ),
                    ),
                    Text(
                      'RM ${_totalPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mutedTeal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _cartItems.isEmpty ? null : _proceedToCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mutedTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Proceed to Payment',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build the list of cart items
  Widget _buildCartItemsList() {
    if (_cartItems.isEmpty) {
      return const Center(
        child: Text('Your cart is empty'),
      );
    }

    return ListView.builder(
      itemCount: _cartItems.length,
      itemBuilder: (context, index) {
        final item = _cartItems[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.deepSlateGray,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First row: Image, name, and condition
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(item.product.imageUrl.split(',').last),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Product name and condition
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.coolGray,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Condition: ${item.product.condition}',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.coolGray.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Second row: Price and quantity controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price
                    Text(
                      'RM ${item.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mutedTeal,
                      ),
                    ),
                    // Quantity controls
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: AppColors.mutedTeal),
                          onPressed: () => _updateQuantity(index, -1),
                        ),
                        Text(
                          item.quantity.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.coolGray,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: AppColors.mutedTeal),
                          onPressed: () => _updateQuantity(index, 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
