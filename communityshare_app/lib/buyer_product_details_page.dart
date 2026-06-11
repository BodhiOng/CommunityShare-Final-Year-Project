// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'constants.dart';
import 'models/product.dart'; // To access the Product class
import 'models/cart_item.dart';
import 'buyer_report_item_page.dart';
import 'buyer_checkout_page.dart';
import 'buyer_chat_detail_page.dart';
import 'buyer_product_reviews_page.dart';
import 'utils/image_utils.dart';

class ProductDetailsPage extends StatefulWidget {
  final Product product;

  const ProductDetailsPage({super.key, required this.product});

  @override
  ProductDetailsPageState createState() => ProductDetailsPageState();
}

class ProductDetailsPageState extends State<ProductDetailsPage> {
  bool _showBargainSheet = false;
  double _bargainPrice = 0;
  final TextEditingController _bargainController = TextEditingController();

  // Get minimum bargain price from Firestore or fallback to 80% of product price
  double get _minimumPrice =>
      widget.product.minBargainPrice ?? (widget.product.price * 0.8);

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Seller data
  Map<String, dynamic> _seller = {
    'username': 'Loading...',
    'address': 'Loading...',
    'profileImageUrl': 'https://picsum.photos/id/1005/200/200', // Default image
    'rating': 0.0,
    'sales': 0,
    'joinDate': 'Loading...',
  };

  bool _isLoadingSeller = true;

  // Reviews data
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = true;
  double _productRating = 0.0;
  int _reviewCount = 0;

  @override
  void initState() {
    super.initState();
    // Set initial bargain price to 80% of original or slightly above minimum
    _bargainPrice = max(widget.product.price * 0.8, _minimumPrice + 0.01);
    _bargainController.text = _bargainPrice.toStringAsFixed(2);

    // Fetch seller information
    _fetchSellerInfo();

    // Fetch product reviews
    _fetchProductReviews();
  }

  // Fetch reviews for this product from Firestore
  Future<void> _fetchProductReviews() async {
    try {
      setState(() {
        _isLoadingReviews = true;
      });

      // Query reviews collection for this product
      final QuerySnapshot reviewsSnapshot =
          await _firestore
              .collection('reviews')
              .where('productId', isEqualTo: widget.product.id)
              .get();

      // Calculate average rating and count reviews
      if (reviewsSnapshot.docs.isNotEmpty) {
        double totalRating = 0;
        final List<Map<String, dynamic>> fetchedReviews = [];

        for (var doc in reviewsSnapshot.docs) {
          final reviewData = doc.data() as Map<String, dynamic>;

          // Add rating to total for average calculation
          if (reviewData.containsKey('rating')) {
            totalRating += (reviewData['rating'] as num).toDouble();
          }

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

        // Calculate average rating
        final double averageRating = totalRating / reviewsSnapshot.docs.length;

        setState(() {
          _reviews = fetchedReviews;
          _productRating = double.parse(averageRating.toStringAsFixed(1));
          _reviewCount = reviewsSnapshot.docs.length;
          _isLoadingReviews = false;
        });
      } else {
        // No reviews found
        setState(() {
          _reviews = [];
          _productRating = 0.0;
          _reviewCount = 0;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching product reviews: $e');
      setState(() {
        _isLoadingReviews = false;
      });
    }
  }

  // Fetch seller information from Firestore
  Future<void> _fetchSellerInfo() async {
    try {
      final String sellerId = widget.product.sellerId;
      final DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(sellerId).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _seller = {
            'username': userData['username'] ?? 'Unknown Seller',
            'address': userData['address'] ?? 'Location not available',

            'profileImageUrl':
                userData['profileImageUrl'] ??
                'https://picsum.photos/id/1005/200/200',
            'rating': userData['rating'] ?? 4.0,
            'sales': userData['sales'] ?? 0,
            'joinDate': userData['joinDate'] ?? 'New seller',
          };
          _isLoadingSeller = false;
        });
      } else {
        // If user document doesn't exist, use default values
        setState(() {
          _seller['username'] = 'Seller ${sellerId.substring(0, 4)}';
          _isLoadingSeller = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching seller info: $e');
      setState(() {
        _isLoadingSeller = false;
      });
    }
  }

  @override
  void dispose() {
    _bargainController.dispose();
    super.dispose();
  }

  // Get the average rating calculated from reviews
  double get _averageRating {
    return _productRating;
  }

  // Build star rating widget
  Widget _buildRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: Colors.amber[700], size: 16);
        } else if (index < rating.ceil() && index > rating.floor()) {
          return Icon(Icons.star_half, color: Colors.amber[700], size: 16);
        } else {
          return Icon(Icons.star_border, color: Colors.amber[700], size: 16);
        }
      }),
    );
  }

  void _showBargainBottomSheet() {
    setState(() {
      _showBargainSheet = true;
    });
  }

  void _hideBargainBottomSheet() {
    setState(() {
      _showBargainSheet = false;
    });
  }

  // Submit bargain and proceed to checkout
  void _submitBargain() async {
    // Hide the bargain sheet
    setState(() {
      _showBargainSheet = false;
    });

    // Check if the bargain price is valid
    if (_bargainPrice < _minimumPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bargain price must be at least RM${_minimumPrice.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Create a product with the bargained price
      final bargainedProduct = Product(
        id: widget.product.id,
        name: widget.product.name,
        description: widget.product.description,
        price: _bargainPrice, // Use the bargained price
        imageUrl: widget.product.imageUrl,
        category: widget.product.category,
        sellerId: widget.product.sellerId,
        seller: widget.product.seller,
        rating: widget.product.rating,
        condition: widget.product.condition,
        listedDate: widget.product.listedDate,
        stock: widget.product.stock,
        adBoost: widget.product.adBoost,
        minBargainPrice: widget.product.minBargainPrice,
      );

      // Create a cart item with the bargained product
      final cartItem = CartItem(
        product: bargainedProduct,
      );

      // Navigate to checkout page with the bargained item
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutPage(
              cartItems: [cartItem],
              isBargainPurchase: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _createChatAndNavigate(
    String sellerId,
    String productId, {
    String? initialMessage,
  }) async {
    try {
      // Get current user
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need to be logged in to chat with sellers'),
          ),
        );
        return;
      }

      // Create a new chat document
      final chatDoc = await _firestore.collection('chats').add({
        'participants': [currentUser.uid, sellerId],
        'participantNames': {
          currentUser.uid: currentUser.displayName ?? 'Buyer',
          sellerId: _seller['username'] ?? 'Seller',
        },
        'lastMessage': initialMessage ?? 'Chat started',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'product': {
          'id': productId,
          'name': widget.product.name,
          'imageUrl': widget.product.imageUrl,
          'price': widget.product.price,
        },
        'unreadCount': {sellerId: 1, currentUser.uid: 0},
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add initial message if provided
      if (initialMessage != null) {
        await _firestore
            .collection('chats')
            .doc(chatDoc.id)
            .collection('messages')
            .add({
              'text': initialMessage,
              'senderId': currentUser.uid,
              'timestamp': FieldValue.serverTimestamp(),
              'type': 'text',
              'read': false,
            });
      }

      // Prepare chat data for the detail page
      final Map<String, dynamic> chatData = {
        'participants': [currentUser.uid, sellerId],
        'participantNames': {
          currentUser.uid: currentUser.displayName ?? 'Buyer',
          sellerId: _seller['username'] ?? 'Seller',
        },
        'product': {
          'id': productId,
          'name': widget.product.name,
          'imageUrl': widget.product.imageUrl,
          'price': widget.product.price,
        },
      };

      // Navigate to chat detail page
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    ChatDetailPage(chatId: chatDoc.id, chatData: chatData),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating chat: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: AppColors.deepSlateGray,
        foregroundColor: AppColors.coolGray,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: AppColors.coolGray),
            onPressed: () {
              // Navigate to report item page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReportItemPage(product: widget.product),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                AspectRatio(
                  aspectRatio: 1,
                  child: ImageUtils.base64ToImage(
                    widget.product.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                // Product Info
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        widget.product.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.coolGray,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Price and Stock
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RM ${widget.product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.mutedTeal,
                            ),
                          ),
                          Text(
                            '${widget.product.stock} in stock',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.coolGray.withAlpha(179),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Divider
                      Divider(color: AppColors.coolGray.withAlpha(77)),
                      const SizedBox(height: 16),

                      // Seller Information Section
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.deepSlateGray,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            _isLoadingSeller
                                ? Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.mutedTeal,
                                  ),
                                )
                                : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Seller Information',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.coolGray,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        // Seller Profile Pic
                                        CircleAvatar(
                                          radius: 30,
                                          backgroundImage: _seller['profileImageUrl'] != null && _seller['profileImageUrl'].isNotEmpty
                                              ? MemoryImage(ImageUtils.isBase64Image(_seller['profileImageUrl'])
                                                  ? ImageUtils.decodeBase64Image(_seller['profileImageUrl'])
                                                  : Uint8List(0))
                                              : const AssetImage('assets/images/default_profile.png') as ImageProvider,
                                        ),
                                        const SizedBox(width: 16),

                                        // Seller Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _seller['username'],
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: AppColors.coolGray,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _seller['address'],
                                                style: TextStyle(
                                                  color: AppColors.coolGray,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                      ),
                      const SizedBox(height: 16),

                      // Divider
                      Divider(color: AppColors.coolGray.withAlpha(77)),
                      const SizedBox(height: 16),

                      // Description
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.coolGray,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.product.description,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.coolGray,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Divider
                      Divider(color: AppColors.coolGray.withAlpha(77)),
                      const SizedBox(height: 16),

                      // Reviews Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Reviews',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.coolGray,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ProductReviewsPage(
                                        product: widget.product,
                                        averageRating: _productRating,
                                        reviewCount: _reviewCount,
                                      ),
                                ),
                              );
                            },
                            child: Text(
                              'View All',
                              style: TextStyle(color: AppColors.mutedTeal),
                            ),
                          ),
                        ],
                      ),

                      // Rating Summary
                      Row(
                        children: [
                          _buildRatingStars(_averageRating),
                          const SizedBox(width: 8),
                          Text(
                            '${_averageRating.toStringAsFixed(1)} ($_reviewCount reviews)',
                            style: TextStyle(color: AppColors.coolGray),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Reviews List
                      _isLoadingReviews
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
                          : Column(
                            children:
                                _reviews
                                    .take(3)
                                    .map((review) => _buildReviewItem(review))
                                    .toList(),
                          ),

                      // Bottom padding to ensure content isn't hidden behind the action buttons
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.deepSlateGray,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(77),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Chat Button
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: () {
                        // Message for the seller
                        final String message =
                            "Hello, I'm interested in your ${widget.product.name}. Is it still available? [This is a system-generated message]";

                        // Create a chat in Firestore and navigate to chat detail page
                        _createChatAndNavigate(
                          widget.product.sellerId,
                          widget.product.id,
                          initialMessage: message,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepSlateGray,
                        foregroundColor: AppColors.coolGray,
                        side: BorderSide(color: AppColors.mutedTeal),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Icon(Icons.chat_bubble_outline),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Buy Now Button
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed:
                          widget.product.stock > 0
                              ? () {
                                // Create a cart item with the current product
                                final cartItem = CartItem(
                                  product: widget.product,
                                );

                                // Navigate to checkout page with the item
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            CheckoutPage(cartItems: [cartItem]),
                                  ),
                                );
                              }
                              : null, // Disable button if stock is 0
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mutedTeal,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.mutedTeal.withAlpha(
                          100,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        widget.product.stock > 0 ? 'Buy Now' : 'Out of Stock',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Bargain Button
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed:
                          widget.product.stock > 0
                              ? _showBargainBottomSheet
                              : null, // Disable if stock is 0
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warmCoral,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.warmCoral.withAlpha(
                          100,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Bargain'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bargain Bottom Sheet
          if (_showBargainSheet)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.deepSlateGray,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(77),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Make an Offer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.coolGray,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: AppColors.coolGray),
                          onPressed: _hideBargainBottomSheet,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Input your desired price for item',
                      style: TextStyle(color: AppColors.coolGray),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _bargainController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixText: 'RM ',
                        prefixStyle: TextStyle(color: AppColors.mutedTeal),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.mutedTeal.withAlpha(77),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.mutedTeal),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          setState(() {
                            _bargainPrice =
                                double.tryParse(value) ??
                                widget.product.price * 0.8;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Minimum amount is: RM ${_minimumPrice.toStringAsFixed(2)}',
                      style: TextStyle(color: AppColors.warmCoral),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _bargainPrice >= _minimumPrice
                                ? () => _submitBargain()
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mutedTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          disabledBackgroundColor: AppColors.coolGray.withAlpha(
                            77,
                          ),
                        ),
                        child: const Text('Bargain'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Reviewer Profile Pic
              ClipOval(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: ImageUtils.base64ToImage(
                    review['profilePic'],
                    fit: BoxFit.cover,
                    errorWidget: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Reviewer Name
              Text(
                review['username'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.coolGray,
                ),
              ),
              const Spacer(),

              // Review Date
              Text(
                review['date'],
                style: TextStyle(
                  color: AppColors.coolGray.withAlpha(179),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Rating
          _buildRatingStars(review['rating']),
          const SizedBox(height: 4),

          // Review Text
          Text(review['text'], style: TextStyle(color: AppColors.coolGray)),

          // Review Image (if any)
          if (review['image'] != null && review['image'].isNotEmpty)
            GestureDetector(
              onTap: () {
                if (mounted) {
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
                                  child: ImageUtils.base64ToImage(
                                    review['image'],
                                    fit: BoxFit.contain,
                                    errorWidget: Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.grey[400],
                                        size: 50,
                                      ),
                                    ),
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
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ImageUtils.base64ToImage(
                    review['image'],
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),
          Divider(color: AppColors.coolGray.withAlpha(77)),
        ],
      ),
    );
  }
}
