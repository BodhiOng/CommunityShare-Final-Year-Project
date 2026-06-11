import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final List<String>? additionalImages;
  final String category;
  final String sellerId;
  final String? seller; // For backward compatibility
  final double rating;
  final String condition;
  final DateTime listedDate;
  final int stock;
  final double adBoost;
  final double? minBargainPrice; // Minimum price for bargaining

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.additionalImages,
    required this.category,
    required this.sellerId,
    this.seller,
    this.rating = 0.0,
    required this.condition,
    required this.listedDate,
    required this.stock,
    required this.adBoost,
    this.minBargainPrice,
  });

  // Factory constructor to create a Product from Firestore data
  factory Product.fromFirestore(Map<String, dynamic> data, String id) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
      additionalImages: null, // Field doesn't exist in database
      category: data['category'] ?? '',
      sellerId: data['sellerId'] ?? '',
      seller: null, // We'll fetch this separately if needed
      rating: 0.0, // Default rating, will be calculated from reviews
      condition: data['condition'] ?? '',
      listedDate:
          data['listedDate'] != null
              ? (data['listedDate'] as Timestamp).toDate()
              : DateTime.now(),
      stock: data['stock'] ?? 0,
      adBoost: (data['adBoost'] ?? 0).toDouble(),
      minBargainPrice: data['minBargainPrice'] != null
          ? (data['minBargainPrice'] as num).toDouble()
          : null,
    );
  }
}

class Category {
  final String name;
  final IconData icon;

  Category({required this.name, required this.icon});
}
