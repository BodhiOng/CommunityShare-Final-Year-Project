import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';
import 'models/product.dart';
import 'utils/image_converter.dart';
import 'utils/image_utils.dart';

class ProductReviewsPage extends StatefulWidget {
  final Product product;
  final double averageRating;
  final int reviewCount;

  const ProductReviewsPage({
    super.key,
    required this.product,
    required this.averageRating,
    required this.reviewCount,
  });

  @override
  State<ProductReviewsPage> createState() => _ProductReviewsPageState();
}

class _ProductReviewsPageState extends State<ProductReviewsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllReviews();
  }

  Future<void> _fetchAllReviews() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Query reviews collection for this product
      final QuerySnapshot reviewsSnapshot =
          await _firestore
              .collection('reviews')
              .where('productId', isEqualTo: widget.product.id)
              .orderBy('date', descending: true) // Most recent reviews first
              .get();

      if (reviewsSnapshot.docs.isNotEmpty) {
        final List<Map<String, dynamic>> fetchedReviews = [];

        for (var doc in reviewsSnapshot.docs) {
          final reviewData = doc.data() as Map<String, dynamic>;

          // Fetch reviewer information
          final String reviewerId = reviewData['reviewerId'] ?? '';
          String username = 'Anonymous';
          String profileImageUrl =
              'https://i.pinimg.com/736x/07/c4/72/07c4720d19a9e9edad9d0e939eca304a.jpg';

          if (reviewerId.isNotEmpty) {
            try {
              final userDoc =
                  await _firestore.collection('users').doc(reviewerId).get();
              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>;
                username = userData['username'] ?? 'User';
                profileImageUrl =
                    userData['profileImageUrl'] ??
                    'https://i.pinimg.com/736x/07/c4/72/07c4720d19a9e9edad9d0e939eca304a.jpg';
              }
            } catch (e) {
              debugPrint('Error fetching reviewer info: $e');
            }
          }

          // Format the review date
          String formattedDate = 'Recently';
          if (reviewData['date'] != null) {
            final timestamp = reviewData['date'] as Timestamp;
            final reviewDate = timestamp.toDate();
            final now = DateTime.now();
            final difference = now.difference(reviewDate);

            if (difference.inDays < 1) {
              formattedDate = 'Today';
            } else if (difference.inDays < 2) {
              formattedDate = 'Yesterday';
            } else if (difference.inDays < 7) {
              formattedDate = '${difference.inDays} days ago';
            } else if (difference.inDays < 30) {
              formattedDate = '${(difference.inDays / 7).floor()} weeks ago';
            } else if (difference.inDays < 365) {
              formattedDate = '${(difference.inDays / 30).floor()} months ago';
            } else {
              formattedDate = '${(difference.inDays / 365).floor()} years ago';
            }
          }

          // Add review to the list
          fetchedReviews.add({
            'id': reviewData['id'] ?? '',
            'username': username,
            'profilePic': profileImageUrl,
            'rating': (reviewData['rating'] as num).toDouble(),
            'date': formattedDate,
            'text': reviewData['text'] ?? 'No comment provided',
            'image': reviewData['imageUrl'],
          });
        }

        setState(() {
          _reviews = fetchedReviews;
          _isLoading = false;
        });
      } else {
        // No reviews found
        setState(() {
          _reviews = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching product reviews: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor()
              ? Icons.star
              : (index < rating)
              ? Icons.star_half
              : Icons.star_border,
          color: AppColors.warmCoral,
          size: 16,
        );
      }),
    );
  }

  ImageProvider? _getProfileImage(String? imageData) {
    if (imageData == null || imageData.isEmpty) return null;
    
    try {
      // Handle data URLs (starts with 'data:image/')
      if (imageData.startsWith('data:image/')) {
        // Extract the base64 part after the comma
        final base64String = imageData.split(',').last;
        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      }
      
      // Handle raw base64 strings
      try {
        final bytes = base64Decode(imageData);
        return MemoryImage(bytes);
      } catch (e) {
        // Not a valid base64 string, try other formats
      }
      
      // Handle network images
      if (imageData.startsWith('http')) {
        return NetworkImage(imageData);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error loading profile image: $e');
      return null;
    }
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      color: AppColors.deepSlateGray,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Reviewer Profile Pic
                CircleAvatar(
                  radius: 20,
                  backgroundImage: _getProfileImage(review['profilePic']),
                  onBackgroundImageError: (exception, stackTrace) {
                    // Handle image loading error if needed
                  },
                  child: review['profilePic'] == null || review['profilePic'].toString().isEmpty
                      ? const Icon(Icons.person, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),

                // Reviewer Name and Verification
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            review['username'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.coolGray,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        review['date'],
                        style: TextStyle(
                          color: AppColors.coolGray.withAlpha(179),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Rating
            Row(
              children: [
                _buildRatingStars(review['rating']),
                const SizedBox(width: 8),
                Text(
                  '${review['rating'].toStringAsFixed(1)}',
                  style: TextStyle(
                    color: AppColors.coolGray,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Review Text
            Text(
              review['text'],
              style: TextStyle(
                color: AppColors.coolGray,
                fontSize: 15,
                height: 1.4,
              ),
            ),

            // Review Image (if any)
            if (review['image'] != null &&
                review['image'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => Dialog.fullscreen(
                          backgroundColor: Colors.black87,
                          child: Stack(
                            children: [
                              Center(
                                child: InteractiveViewer(
                                  minScale: 0.5,
                                  maxScale: 4.0,
                                  child:
                                      ImageUtils.isBase64Image(review['image'])
                                          ? Image.memory(
                                            ImageConverter.base64ToBytes(
                                              review['image'],
                                            ),
                                            fit: BoxFit.contain,
                                          )
                                          : Image.network(
                                            review['image'],
                                            fit: BoxFit.contain,
                                          ),
                                ),
                              ),
                              Positioned(
                                top: 40,
                                right: 20,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                            ],
                          ),
                        ),
                  );
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.mutedTeal.withAlpha(100),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: ImageUtils.base64ToImage(
                      review['image'],
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: AppColors.deepSlateGray,
        foregroundColor: AppColors.coolGray,
        title: Text('Reviews for ${widget.product.name}'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Rating Summary
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.deepSlateGray,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.averageRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.coolGray,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRatingStars(widget.averageRating),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.reviewCount} ${widget.reviewCount == 1 ? 'review' : 'reviews'}',
                          style: TextStyle(color: AppColors.coolGray),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Reviews List
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.mutedTeal,
                      ),
                    )
                    : _reviews.isEmpty
                    ? Center(
                      child: Text(
                        'No reviews yet',
                        style: TextStyle(
                          color: AppColors.coolGray,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reviews.length,
                      itemBuilder: (context, index) {
                        return _buildReviewItem(_reviews[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
