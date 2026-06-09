import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secondhand_marketplace_app/utils/image_utils.dart';
import 'constants.dart';
import 'utils/image_converter.dart';
import 'buyer_rate_review_page.dart';
import 'buyer_home_page.dart';
import 'buyer_wallet_page.dart';
import 'buyer_profile_page.dart';
import 'models/purchase_order.dart';
import 'models/product.dart';
import 'utils/page_transitions.dart';

class MyPurchasesPage extends StatefulWidget {
  const MyPurchasesPage({super.key});

  @override
  State<MyPurchasesPage> createState() => _MyPurchasesPageState();
}

class _MyPurchasesPageState extends State<MyPurchasesPage> {
  int _selectedIndex = 1; // Set to 1 for My Purchases tab

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State variables
  List<PurchaseOrder> _purchaseOrders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserOrders();
  }

  // Fetch orders for the current user
  Future<void> _fetchUserOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user ID
      final User? currentUser = _auth.currentUser;

      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please log in to view your purchases';
        });
        return;
      }

      // Query orders where buyerId matches current user ID (without orderBy to avoid index requirement)
      final QuerySnapshot orderSnapshot =
          await _firestore
              .collection('orders')
              .where('buyerId', isEqualTo: currentUser.uid)
              .get();

      // Convert to PurchaseOrder objects
      final List<PurchaseOrder> orders = [];

      for (var doc in orderSnapshot.docs) {
        final order = PurchaseOrder.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );

        // Fetch product details for each order
        await _fetchProductDetails(order);

        orders.add(order);
      }

      // Sort orders locally by purchase date (newest first)
      orders.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

      if (mounted) {
        setState(() {
          _purchaseOrders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading purchases: $e';
        });
      }
    }
  }

  // Fetch product details for an order
  Future<void> _fetchProductDetails(PurchaseOrder order) async {
    try {
      final DocumentSnapshot productDoc =
          await _firestore.collection('products').doc(order.productId).get();

      if (productDoc.exists) {
        final productData = productDoc.data() as Map<String, dynamic>;
        order.product = Product.fromFirestore(productData, order.productId);
      }
    } catch (e) {
      debugPrint('Error fetching product ${order.productId}: $e');
    }
  }

  // Update order status in Firestore
  Future<void> _updateOrderStatus(
    PurchaseOrder order,
    OrderStatus newStatus,
  ) async {
    try {
      String statusText = newStatus.toString().split('.').last;
      // Capitalize the first letter of the status
      statusText = statusText[0].toUpperCase() + statusText.substring(1);
      
      await _firestore.collection('orders').doc(order.id).update({
        'status': statusText,
      });

      // Update local state
      if (mounted) {
        setState(() {
          order.status = newStatus;
        });
      }
    } catch (e) {
      debugPrint('Error updating order status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order status: $e')),
        );
      }
    }
  }

  // Cancel an order
  void _cancelOrder(PurchaseOrder order) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.charcoalBlack,
            title: Text(
              'Cancel Order',
              style: TextStyle(
                color: AppColors.coolGray,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Are you sure you want to cancel this order?',
              style: TextStyle(color: AppColors.coolGray),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('No', style: TextStyle(color: AppColors.mutedTeal)),
              ),
              TextButton(
                onPressed: () {
                  // Update order status to cancelled in Firestore
                  _updateOrderStatus(order, OrderStatus.cancelled);
                  Navigator.pop(context);
                },
                child: Text(
                  'Yes',
                  style: TextStyle(color: AppColors.warmCoral),
                ),
              ),
            ],
          ),
    );
  }

  // Mark order as received and navigate to review page
  void _markAsReceived(PurchaseOrder order) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.charcoalBlack,
            title: Text(
              'Confirm Receipt',
              style: TextStyle(
                color: AppColors.coolGray,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Have you received this item? This action cannot be undone.',
              style: TextStyle(color: AppColors.coolGray),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('No', style: TextStyle(color: AppColors.mutedTeal)),
              ),
              TextButton(
                onPressed: () {
                  // Update order status to received in Firestore
                  _updateOrderStatus(order, OrderStatus.received);
                  Navigator.pop(context);
                  // Navigate to rating page after marking as received
                  _navigateToRatingPage(order);
                },
                child: Text(
                  'Yes',
                  style: TextStyle(color: AppColors.mutedTeal),
                ),
              ),
            ],
          ),
    );
  }

  // Navigate to the rating page
  void _navigateToRatingPage(PurchaseOrder order) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RateReviewPage(order: order),
      ),
    );
    
    // If review was submitted successfully, refresh the orders
    if (result == true) {
      _fetchUserOrders();
    }
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      // Navigate directly to HomePage
      Navigator.pushReplacement(
        context,
        DarkPageReplaceRoute(
          page: const MyHomePage(title: 'Secondhand Marketplace'),
        ),
      );
    } else if (index == 1) {
      // Already on My Purchases page, just update index
      setState(() {
        _selectedIndex = index;
      });
    } else if (index == 2) {
      // Navigate to My Wallet page
      Navigator.pushReplacement(
        context,
        DarkPageReplaceRoute(page: const MyWalletPage()),
      );
    } else if (index == 3) {
      // Navigate to Profile page
      Navigator.pushReplacement(
        context,
        DarkPageReplaceRoute(page: const MyProfilePage()),
      );
    }
  }

  // Empty purchases view
  Widget _buildEmptyPurchases() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: AppColors.coolGray.withAlpha(150),
          ),
          const SizedBox(height: 16),
          Text(
            'No purchases yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.coolGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your purchase history will appear here',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.coolGray.withAlpha(150),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mutedTeal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Start Shopping',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Purchases list view
  Widget _buildPurchasesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: TextStyle(color: AppColors.coolGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchUserOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mutedTeal,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_purchaseOrders.isEmpty) {
      return _buildEmptyPurchases();
    }

    return ListView.builder(
      itemCount: _purchaseOrders.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final order = _purchaseOrders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: AppColors.deepSlateGray,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Order header with ID and date
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.charcoalBlack.withAlpha(100),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order ${order.id}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.coolGray,
                      ),
                    ),
                    Text(
                      '${order.purchaseDate.day}/${order.purchaseDate.month}/${order.purchaseDate.year}',
                      style: TextStyle(
                        color: AppColors.coolGray.withAlpha(150),
                      ),
                    ),
                  ],
                ),
              ),
              // Order content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          order.product?.imageUrl != null
                              ? ImageUtils.base64ToImage(
                                order.product!.imageUrl,
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
                            order.product?.name ?? 'Product Unavailable',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.coolGray,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.product?.description ??
                                'No description available',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.coolGray.withAlpha(150),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Price and quantity
                          Row(
                            children: [
                              Text(
                                'RM ${order.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.mutedTeal,
                                ),
                              ),
                              Text(
                                ' × ${order.quantity}',
                                style: TextStyle(color: AppColors.coolGray),
                              ),
                            ],
                          ),
                          // Savings displayed below price and quantity
                          if (order.savings > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Saved: RM ${order.savings.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[300],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Status and action buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.charcoalBlack.withAlpha(100),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  children: [
                    // Status row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Status: ',
                              style: TextStyle(color: AppColors.coolGray),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: order.getStatusColor().withAlpha(50),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                order.getStatusText(),
                                style: TextStyle(
                                  color: order.getStatusColor(),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Rating if available
                        if (order.rating != null)
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 16,
                                color: AppColors.softLemonYellow,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                order.rating!.toStringAsFixed(1),
                                style: TextStyle(color: AppColors.coolGray),
                              ),
                            ],
                          ),
                      ],
                    ),
                    // Action buttons
                    if (order.canCancel ||
                        order.canMarkAsReceived ||
                        order.canRate)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Cancel button
                            if (order.canCancel)
                              ElevatedButton(
                                onPressed: () => _cancelOrder(order),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.warmCoral,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel Order',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            // Mark as received button
                            if (order.canMarkAsReceived) ...[
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () => _markAsReceived(order),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.mutedTeal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Confirm Receipt',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                            // Rate button
                            if (order.canRate) ...[
                              FutureBuilder<QuerySnapshot>(
                                future: _firestore
                                    .collection('reviews')
                                    .where('orderId', isEqualTo: order.id)
                                    .where('reviewerId', isEqualTo: _auth.currentUser?.uid)
                                    .limit(1)
                                    .get(),
                                builder: (context, snapshot) {
                                  // Show loading indicator while checking
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const SizedBox(
                                      width: 70,
                                      height: 32,
                                      child: Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                   
                                  // Only show rate button if no review exists
                                  final bool hasReview = snapshot.hasData && 
                                      snapshot.data != null && 
                                      snapshot.data!.docs.isNotEmpty;
                                   
                                  if (!hasReview) {
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: ElevatedButton(
                                        onPressed: () => _navigateToRatingPage(order),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.softLemonYellow,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          'Rate & Review',
                                          style: TextStyle(
                                            color: AppColors.charcoalBlack,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                   
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    // Review if available
                    if (order.review != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.charcoalBlack.withAlpha(150),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.coolGray.withAlpha(50),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Your Review:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.coolGray,
                                    ),
                                  ),
                                  // Show rating stars
                                  Row(
                                    children: List.generate(5, (index) {
                                      return Icon(
                                        index < order.rating!.floor()
                                            ? Icons.star
                                            : (index == order.rating!.floor() &&
                                                order.rating! -
                                                        order.rating!.floor() >=
                                                    0.5)
                                            ? Icons.star_half
                                            : Icons.star_border,
                                        color: Colors.amber,
                                        size: 16,
                                      );
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                order.review!,
                                style: TextStyle(
                                  color: AppColors.coolGray.withAlpha(200),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),

                              // Display review image if available
                              FutureBuilder<QuerySnapshot>(
                                future:
                                    _firestore
                                        .collection('reviews')
                                        .where('orderId', isEqualTo: order.id)
                                        .limit(1)
                                        .get(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox.shrink();
                                  }

                                  if (snapshot.hasData &&
                                      snapshot.data != null &&
                                      snapshot.data!.docs.isNotEmpty) {
                                    final reviewDoc = snapshot.data!.docs.first;
                                    final reviewData =
                                        reviewDoc.data()
                                            as Map<String, dynamic>;
                                    final imageUrl = reviewData['imageUrl'];

                                    if (imageUrl != null &&
                                        imageUrl.toString().isNotEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.memory(
                                            ImageConverter.base64ToBytes(
                                              imageUrl,
                                            ),
                                            height: 120,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    }
                                  }

                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: AppColors.deepSlateGray,
        title: Text(
          'My Purchases',
          style: TextStyle(color: AppColors.coolGray),
        ),
      ),
      body: _buildPurchasesList(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            label: 'My Purchases',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Wallet',
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
