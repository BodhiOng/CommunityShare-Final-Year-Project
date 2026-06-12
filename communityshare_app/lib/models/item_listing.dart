import 'package:cloud_firestore/cloud_firestore.dart';

class ItemListing {
  const ItemListing({
    required this.itemId,
    required this.donorId,
    required this.category,
    required this.title,
    required this.description,
    required this.quantity,
    required this.condition,
    required this.photoUrl,
    required this.expiryDate,
    required this.availabilityStatus,
    required this.createdAt,
  });

  final String itemId;
  final String donorId;
  final String category;
  final String title;
  final String description;
  final int quantity;
  final String condition;
  final String photoUrl;
  final DateTime? expiryDate;
  final String availabilityStatus;
  final DateTime? createdAt;

  factory ItemListing.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return ItemListing(
      itemId: _readString(data['itemId']).isNotEmpty
          ? _readString(data['itemId'])
          : doc.id,
      donorId: _readString(data['donorId']),
      category: _readString(data['category'], fallback: 'Uncategorized'),
      title: _readString(data['title'], fallback: 'Untitled item'),
      description: _readString(
        data['description'],
        fallback: 'No description provided.',
      ),
      quantity: _readInt(data['quantity']),
      condition: _readString(data['condition'], fallback: 'Not specified'),
      photoUrl: _readString(data['photoUrl']),
      expiryDate: _readDateTime(data['expiryDate']),
      availabilityStatus: _readString(
        data['availabilityStatus'],
        fallback: 'unknown',
      ),
      createdAt: _readDateTime(data['createdAt']),
    );
  }

  bool get isExpired {
    if (expiryDate == null) {
      return false;
    }

    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      expiryDate!.year,
      expiryDate!.month,
      expiryDate!.day,
    );
    return expiry.isBefore(cutoff);
  }

  bool get isAvailable {
    return availabilityStatus.toLowerCase() == 'available' &&
        quantity > 0 &&
        !isExpired;
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    return fallback;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
