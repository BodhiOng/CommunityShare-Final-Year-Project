import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:secondhand_marketplace_app/utils/image_utils.dart';

import 'constants.dart';
import 'seller_listing_page.dart';
import 'seller_messages_page.dart';
import 'seller_profile_page.dart';
import 'seller_wallet_page.dart';
import 'utils/page_transitions.dart';

class SellerReviewsPage extends StatefulWidget {
  const SellerReviewsPage({super.key});

  @override
  State<SellerReviewsPage> createState() => _SellerReviewsPageState();
}

class _SellerReviewsPageState extends State<SellerReviewsPage> {
  int _selectedIndex = 1; // Set to 1 for Reviews tab
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _sellerId;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  double _averageRating = 0.0;
  int _totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _sellerId = _auth.currentUser?.uid;
    _fetchReviews();
  }

  // Fetch reviews for the current seller
  Future<void> _fetchReviews() async {
    try {
      setState(() {
        _isLoading = true;
      });

      if (_sellerId == null) {
        throw Exception('User not authenticated');
      }

      // Get all orders that have reviews for this seller
      final QuerySnapshot reviewsSnapshot =
          await _firestore
              .collection('orders')
              .where('sellerId', isEqualTo: _sellerId)
              .where('rating', isGreaterThan: 0) // Only get orders with ratings
              .orderBy('rating', descending: true) // Show highest ratings first
              .orderBy('purchaseDate', descending: true) // Then by most recent
              .get();

      List<Map<String, dynamic>> reviews = [];
      double ratingSum = 0;
      int reviewCount = 0;

      // Process each review
      for (var doc in reviewsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Get buyer info
        String buyerName = 'Anonymous User';
        String buyerPhotoUrl = '';

        try {
          final buyerDoc =
              await _firestore
                  .collection('users')
                  .doc(data['buyerId'] as String)
                  .get();

          if (buyerDoc.exists) {
            final buyerData = buyerDoc.data() as Map<String, dynamic>;
            buyerName = buyerData['username'] ?? 'Anonymous User';
            buyerPhotoUrl = buyerData['profileImageUrl'] ?? '';
          }
        } catch (e) {
          debugPrint('Error fetching buyer info: $e');
        }

        // Get product info
        String productName = 'Unknown Product';
        String productImageUrl = '';

        try {
          final productDoc =
              await _firestore
                  .collection('products')
                  .doc(data['productId'] as String)
                  .get();

          if (productDoc.exists) {
            final productData = productDoc.data() as Map<String, dynamic>;
            productName = productData['name'] ?? 'Unknown Product';
            productImageUrl = productData['imageUrl'] ?? '';
          }
        } catch (e) {
          debugPrint('Error fetching product info: $e');
        }

        // Add to reviews list
        reviews.add({
          'id': doc.id,
          'rating': (data['rating'] ?? 0.0).toDouble(),
          'review': data['review'] ?? '',
          'date': (data['purchaseDate'] as Timestamp).toDate(),
          'buyerName': buyerName,
          'buyerPhotoUrl': buyerPhotoUrl,
          'productName': productName,
          'productImageUrl': productImageUrl,
        });

        // Update rating sum and count
        ratingSum += (data['rating'] ?? 0.0).toDouble();
        reviewCount++;
      }

      // Calculate average rating
      double avgRating = reviewCount > 0 ? ratingSum / reviewCount : 0.0;

      setState(() {
        _reviews = reviews;
        _averageRating = avgRating;
        _totalReviews = reviewCount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Handle bottom navigation bar taps
  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0: // Navigate to My Listings
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const SellerListingPage()),
        );
        break;
      case 1: // Already on Reviews page
        setState(() {
          _selectedIndex = index;
        });
        break;
      case 2: // Navigate to Wallet
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const SellerWalletPage()),
        );
        break;
      case 3: // Navigate to Messages
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const SellerMessagesPage()),
        );
        break;
      case 4: // Navigate to Profile
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const SellerProfilePage()),
        );
        break;
    }
  }

  // Format date to a readable string
  String _formatDate(DateTime date) {
    // Calculate the difference between the date and now
    final now = DateTime.now();
    final difference = now.difference(date);

    // If less than a day, show relative time
    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        final minutes = difference.inMinutes;
        return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        final hours = difference.inHours;
        return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
      }
    }
    // If less than a week, show day of week
    else if (difference.inDays < 7) {
      final DateFormat formatter = DateFormat('EEEE');
      return formatter.format(date);
    }
    // Otherwise show full date
    else {
      final DateFormat formatter = DateFormat('MMM d, yyyy');
      return formatter.format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: AppColors.deepSlateGray,
        title: const Text(
          'My Reviews',
          style: TextStyle(color: AppColors.coolGray),
        ),
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.mutedTeal),
              )
              : RefreshIndicator(
                onRefresh: _fetchReviews,
                color: AppColors.mutedTeal,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating summary card
                      Card(
                        margin: const EdgeInsets.all(16),
                        color: AppColors.deepSlateGray,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              // Rating icon
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.softLemonYellow.withAlpha(
                                    50,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.star,
                                  color: AppColors.softLemonYellow,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Rating text
                              Text(
                                'Your Overall Rating',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.coolGray,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _averageRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '/5',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: AppColors.coolGray,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Based on $_totalReviews ${_totalReviews == 1 ? 'review' : 'reviews'}',
                                style: TextStyle(
                                  color: AppColors.coolGray.withAlpha(180),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Reviews list header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Customer Reviews',
                              style: TextStyle(
                                color: AppColors.coolGray,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.refresh,
                                color: AppColors.coolGray,
                              ),
                              onPressed: _fetchReviews,
                              tooltip: 'Refresh reviews',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Reviews list
                      _reviews.isEmpty
                          ? Card(
                            margin: const EdgeInsets.all(16),
                            color: AppColors.deepSlateGray,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.rate_review_outlined,
                                    color: AppColors.coolGray.withValues(
                                      alpha: 150,
                                    ),
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No reviews yet',
                                    style: TextStyle(
                                      color: AppColors.coolGray,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'When customers review your products, they will appear here.',
                                    style: TextStyle(
                                      color: AppColors.coolGray.withAlpha(180),
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _reviews.length,
                            itemBuilder: (context, index) {
                              final review = _reviews[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                color: AppColors.deepSlateGray,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Buyer info and rating
                                      Row(
                                        children: [
                                          // Buyer avatar
                                          Builder(
                                            builder: (context) {
                                              try {
                                                final photoUrl =
                                                    review['buyerPhotoUrl']
                                                        as String?;
                                                if (photoUrl == null ||
                                                    photoUrl.isEmpty) {
                                                  return CircleAvatar(
                                                    radius: 20,
                                                    backgroundColor: AppColors
                                                        .mutedTeal
                                                        .withValues(alpha: 0.2),
                                                    child: Icon(
                                                      Icons.person,
                                                      color:
                                                          AppColors.mutedTeal,
                                                    ),
                                                  );
                                                }

                                                // Handle data URLs (starts with 'data:image/')
                                                if (photoUrl.startsWith(
                                                  'data:image/',
                                                )) {
                                                  try {
                                                    final base64String =
                                                        photoUrl
                                                            .split(',')
                                                            .last;
                                                    final bytes = base64Decode(
                                                      base64String,
                                                    );
                                                    return CircleAvatar(
                                                      radius: 20,
                                                      backgroundColor: AppColors
                                                          .mutedTeal
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      child: ClipOval(
                                                        child: Image.memory(
                                                          bytes,
                                                          width: 40,
                                                          height: 40,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (
                                                                _,
                                                                __,
                                                                ___,
                                                              ) => Icon(
                                                                Icons.person,
                                                                color:
                                                                    AppColors
                                                                        .mutedTeal,
                                                              ),
                                                        ),
                                                      ),
                                                    );
                                                  } catch (e) {
                                                    debugPrint(
                                                      'Error decoding base64 image: $e',
                                                    );
                                                    // Fall through to default icon
                                                  }
                                                }

                                                // Handle network images
                                                if (photoUrl.startsWith(
                                                  'http',
                                                )) {
                                                  return CircleAvatar(
                                                    radius: 20,
                                                    backgroundColor: AppColors
                                                        .mutedTeal
                                                        .withValues(alpha: 0.2),
                                                    child: ClipOval(
                                                      child: Image.network(
                                                        photoUrl,
                                                        width: 40,
                                                        height: 40,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              _,
                                                              __,
                                                              ___,
                                                            ) => Icon(
                                                              Icons.person,
                                                              color:
                                                                  AppColors
                                                                      .mutedTeal,
                                                            ),
                                                      ),
                                                    ),
                                                  );
                                                }

                                                // Fallback to default icon
                                                return CircleAvatar(
                                                  radius: 20,
                                                  backgroundColor: AppColors
                                                      .mutedTeal
                                                      .withValues(alpha: 0.2),
                                                  child: Icon(
                                                    Icons.person,
                                                    color: AppColors.mutedTeal,
                                                  ),
                                                );
                                              } catch (e) {
                                                debugPrint(
                                                  'Error loading buyer photo: $e',
                                                );
                                                return CircleAvatar(
                                                  radius: 20,
                                                  backgroundColor: AppColors
                                                      .mutedTeal
                                                      .withValues(alpha: 0.2),
                                                  child: Icon(
                                                    Icons.person,
                                                    color: AppColors.mutedTeal,
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          // Buyer name and date
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  review['buyerName'] as String,
                                                  style: const TextStyle(
                                                    color: AppColors.coolGray,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  _formatDate(
                                                    review['date'] as DateTime,
                                                  ),
                                                  style: TextStyle(
                                                    color: AppColors.coolGray
                                                        .withValues(alpha: 150),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Rating
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.softLemonYellow
                                                  .withAlpha(30),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  color:
                                                      AppColors.softLemonYellow,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  (review['rating'] as double)
                                                      .toStringAsFixed(1),
                                                  style: const TextStyle(
                                                    color:
                                                        AppColors
                                                            .softLemonYellow,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Review text
                                      if ((review['review'] as String)
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Text(
                                          review['review'] as String,
                                          style: const TextStyle(
                                            color: AppColors.coolGray,
                                          ),
                                        ),
                                      ],

                                      // Product info
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.charcoalBlack,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // Product image
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: SizedBox(
                                                width: 48,
                                                height: 48,
                                                child: review['productImageUrl'].isNotEmpty
                                                    ? ImageUtils.base64ToImage(
                                                        review['productImageUrl'] as String,
                                                        fit: BoxFit.cover,
                                                        errorWidget: Container(
                                                          color: AppColors.deepSlateGray,
                                                          child: const Icon(
                                                            Icons.image_not_supported,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      )
                                                    : Container(
                                                        color: AppColors.deepSlateGray,
                                                        child: Icon(
                                                          Icons.image_not_supported,
                                                          color: AppColors.coolGray.withValues(alpha: 150),
                                                          size: 24,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Product name
                                            Expanded(
                                              child: Text(
                                                review['productName'] as String,
                                                style: const TextStyle(
                                                  color: AppColors.coolGray,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      // Add bottom padding
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Listings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_outline),
            label: 'Reviews',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        backgroundColor: AppColors.deepSlateGray,
        selectedItemColor: AppColors.softLemonYellow,
        unselectedItemColor: AppColors.coolGray,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
