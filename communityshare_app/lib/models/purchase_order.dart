import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';

enum OrderStatus {
  pending,
  processed,
  outForDelivery,
  received,
  cancelled
}

// Convert string to OrderStatus
OrderStatus stringToOrderStatus(String status) {
  switch (status.toLowerCase()) {
    case 'pending': return OrderStatus.pending;
    case 'processed': return OrderStatus.processed;
    case 'out for delivery': return OrderStatus.outForDelivery;
    case 'received': return OrderStatus.received;
    case 'cancelled': return OrderStatus.cancelled;
    default: return OrderStatus.pending;
  }
}

class PurchaseOrder {
  final String id;
  final String productId;  // Store productId separately for Firestore queries
  final String buyerId;    // Store buyerId for filtering user purchases
  final String sellerId;   // Store sellerId for reference
  Product? product;        // Product can be null initially and loaded later
  final int quantity;
  final double price;
  final double originalPrice;
  final DateTime purchaseDate;
  OrderStatus status;
  double? rating;
  String? review;

  PurchaseOrder({
    required this.id,
    required this.productId,
    required this.buyerId,
    required this.sellerId,
    this.product,
    required this.quantity,
    required this.price,
    required this.originalPrice,
    required this.purchaseDate,
    this.status = OrderStatus.pending,
    this.rating,
    this.review,
  });
  
  // Create PurchaseOrder from Firestore document
  factory PurchaseOrder.fromFirestore(Map<String, dynamic> data, String id) {
    return PurchaseOrder(
      id: id,
      productId: data['productId'] ?? '',
      buyerId: data['buyerId'] ?? '',
      sellerId: data['sellerId'] ?? '',
      product: null, // Will be loaded separately
      quantity: data['quantity'] ?? 1,
      price: (data['price'] ?? 0).toDouble(),
      originalPrice: (data['originalPrice'] ?? 0).toDouble(),
      purchaseDate: (data['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] != null ? stringToOrderStatus(data['status']) : OrderStatus.pending,
      rating: data['rating']?.toDouble(),
      review: data['review'],
    );
  }

  // Total price of the order
  double get totalPrice => price * quantity;
  
  // Calculate savings compared to original price
  double get savings => (originalPrice - price) * quantity;

  // Check if order can be cancelled
  bool get canCancel => status == OrderStatus.pending;

  // Check if order can be marked as received
  bool get canMarkAsReceived => status == OrderStatus.outForDelivery;

  // Check if order can be rated
  bool get canRate => status == OrderStatus.received && (rating == null);

  // Get status color
  Color getStatusColor() {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.processed:
        return Colors.blue;
      case OrderStatus.outForDelivery:
        return Colors.purple;
      case OrderStatus.received:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  // Get status text
  String getStatusText() {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.processed:
        return 'Processed';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.received:
        return 'Received';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}
