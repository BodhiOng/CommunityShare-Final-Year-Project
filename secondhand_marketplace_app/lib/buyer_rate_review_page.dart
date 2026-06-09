import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:secondhand_marketplace_app/utils/image_utils.dart';
import 'dart:io';
import 'constants.dart';
import 'utils/image_converter.dart';
import 'models/purchase_order.dart';

class RateReviewPage extends StatefulWidget {
  final PurchaseOrder order;

  const RateReviewPage({super.key, required this.order});

  @override
  State<RateReviewPage> createState() => _RateReviewPageState();
}

class _RateReviewPageState extends State<RateReviewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _reviewController = TextEditingController();

  double _rating = 5.0;
  File? _selectedImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  // Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedImage != null && mounted) {
        setState(() {
          _selectedImage = File(pickedImage.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  // Add rating and review to order in Firestore
  Future<void> _submitRatingAndReview() async {
    if (!mounted) return;

    try {
      setState(() {
        _isSubmitting = true;
      });

      // Convert image to base64 if provided
      String? imageBase64;
      if (_selectedImage != null) {
        // Convert image file to base64 string
        imageBase64 = await ImageConverter.fileToBase64(_selectedImage!);
      }

      // Update order with rating and review
      await _firestore.collection('orders').doc(widget.order.id).update({
        'rating': _rating,
        'review':
            _reviewController.text.isNotEmpty ? _reviewController.text : null,
      });

      // Generate a unique review ID
      final String reviewId =
          'review_${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8)}';

      // Add to reviews collection for product rating calculation
      await _firestore.collection('reviews').doc(reviewId).set({
        'id': reviewId,
        'productId': widget.order.productId,
        'orderId': widget.order.id,
        'reviewerId': _auth.currentUser?.uid,
        'sellerId': widget.order.product?.sellerId,
        'rating': _rating,
        'text':
            _reviewController.text.isNotEmpty ? _reviewController.text : null,
        'imageUrl': imageBase64, // Store image as base64 string
        'date': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your review!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Return to previous screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error adding rating and review: $e');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save your review. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: AppColors.charcoalBlack,
        appBar: AppBar(
          backgroundColor: AppColors.deepSlateGray,
          foregroundColor: AppColors.coolGray,
          title: Text('Rate & Review'),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.deepSlateGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // Product image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          widget.order.product?.imageUrl != null
                              ? ImageUtils.base64ToImage(
                                widget.order.product!.imageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                              : Container(
                                width: 80,
                                height: 80,
                                color: AppColors.deepSlateGray,
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: AppColors.coolGray,
                                ),
                              ),
                    ),
                    const SizedBox(width: 16),
                    // Product details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.order.product?.name ?? 'Product',
                            style: TextStyle(
                              color: AppColors.coolGray,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.order.product?.description ??
                                'No description available',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.coolGray.withAlpha(150),
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '\$${widget.order.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: AppColors.mutedTeal,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' × ${widget.order.quantity}',
                                style: TextStyle(color: AppColors.coolGray),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Rating section
              Text(
                'How would you rate this product?',
                style: TextStyle(
                  color: AppColors.coolGray,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating.floor()
                          ? Icons.star
                          : (index == _rating.floor() &&
                              _rating - _rating.floor() >= 0.5)
                          ? Icons.star_half
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1.0;
                      });
                    },
                  );
                }),
              ),

              const SizedBox(height: 24),

              // Review section
              Text(
                'Write a review (optional):',
                style: TextStyle(
                  color: AppColors.coolGray,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reviewController,
                maxLines: 5,
                style: TextStyle(color: AppColors.coolGray),
                decoration: InputDecoration(
                  hintText: 'Share your experience with this product...',
                  hintStyle: TextStyle(
                    color: AppColors.coolGray.withAlpha(128),
                  ),
                  fillColor: AppColors.deepSlateGray,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Image upload section
              Text(
                'Add a photo (optional):',
                style: TextStyle(
                  color: AppColors.coolGray,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Image preview or upload button
                  if (_selectedImage != null) ...[
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
                                        child: Image.file(
                                          _selectedImage!,
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
                                        onPressed:
                                            () => Navigator.of(context).pop(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        );
                      },
                      child: Stack(
                        children: [
                          Container(
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
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImage!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImage = null;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color.fromRGBO(0, 0, 0, 0.7),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    InkWell(
                      onTap: _pickImage,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.deepSlateGray,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.coolGray.withAlpha(100),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              color: AppColors.mutedTeal,
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add Photo',
                              style: TextStyle(
                                color: AppColors.coolGray,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRatingAndReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mutedTeal,
                    disabledBackgroundColor: Color.alphaBlend(
                      AppColors.mutedTeal.withAlpha(128), // 50% opacity
                      Theme.of(context).disabledColor,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.0,
                            ),
                          )
                          : const Text(
                            'Submit Review',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
