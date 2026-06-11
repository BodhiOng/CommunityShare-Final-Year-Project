// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'constants.dart';
import 'admin_profile_page.dart';
import 'admin_user_management_page.dart';
import 'admin_product_moderation_page.dart';
import 'admin_customer_support_page.dart';
import 'utils/page_transitions.dart';
import 'utils/image_utils.dart';

class AdminOrderModerationPage extends StatefulWidget {
  const AdminOrderModerationPage({super.key});

  @override
  State<AdminOrderModerationPage> createState() =>
      _AdminOrderModerationPageState();
}

class _AdminOrderModerationPageState extends State<AdminOrderModerationPage> {
  final int _selectedIndex =
      2; // 0 for User Management, 1 for Product Moderation, 2 for Order Moderation, 3 for Customer Support, 4 for Profile
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'All';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch all orders from Firestore
  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot ordersSnapshot =
          await _firestore
              .collection('orders')
              .orderBy('purchaseDate', descending: true)
              .get();

      List<Map<String, dynamic>> orders = [];

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Get product details
        DocumentSnapshot productDoc;
        Map<String, dynamic>? productData;

        try {
          productDoc =
              await _firestore
                  .collection('products')
                  .doc(data['productId'] as String)
                  .get();

          if (productDoc.exists) {
            productData = productDoc.data() as Map<String, dynamic>?;
          }
        } catch (e) {
          debugPrint('Error fetching product: $e');
          productData = null;
        }

        // Get buyer details
        DocumentSnapshot buyerDoc;
        Map<String, dynamic>? buyerData;

        try {
          buyerDoc =
              await _firestore
                  .collection('users')
                  .doc(data['buyerId'] as String)
                  .get();

          if (buyerDoc.exists) {
            buyerData = buyerDoc.data() as Map<String, dynamic>?;
          }
        } catch (e) {
          debugPrint('Error fetching buyer: $e');
          buyerData = null;
        }

        // Get seller details
        DocumentSnapshot sellerDoc;
        Map<String, dynamic>? sellerData;

        try {
          sellerDoc =
              await _firestore
                  .collection('users')
                  .doc(data['sellerId'] as String)
                  .get();

          if (sellerDoc.exists) {
            sellerData = sellerDoc.data() as Map<String, dynamic>?;
          }
        } catch (e) {
          debugPrint('Error fetching seller: $e');
          sellerData = null;
        }

        // Convert Firestore data to app format
        orders.add({
          'id': doc.id,
          'productId': data['productId'] as String,
          'productName': productData?['name'] ?? 'Product Unavailable',
          'productImage': productData?['imageUrl'] ?? '',
          'productPrice': data['originalPrice'] ?? 0.0,
          'finalPrice': data['price'] ?? 0.0,
          'quantity': data['quantity'] ?? 1,
          'buyerId': data['buyerId'] as String,
          'buyerName': buyerData?['username'] ?? 'Unknown User',
          'sellerId': data['sellerId'] as String,
          'sellerName': sellerData?['username'] ?? 'Unknown Seller',
          'purchaseDate': (data['purchaseDate'] as Timestamp).toDate(),
          'status': data['status'] as String,
        });
      }

      setState(() {
        _orders = orders;
        _filteredOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Filter orders based on search query and status
  void _filterOrders() {
    setState(() {
      _filteredOrders =
          _orders.where((order) {
            final matchesSearch =
                order['productName'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                order['buyerName'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                order['sellerName'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );

            final matchesStatus =
                _selectedStatus.toLowerCase() == 'all' ||
                order['status'].toString().toLowerCase() ==
                    _selectedStatus.toLowerCase();

            return matchesSearch && matchesStatus;
          }).toList();
    });
  }

  // Navigate between admin pages
  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0:
        // Navigate to User Management page
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminUserManagementPage()),
        );
        break;
      case 1:
        // Navigate to Product Moderation page
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminProductModerationPage()),
        );
        break;
      case 2:
        // Already on Order Moderation page
        break;
      case 3:
        // Navigate to Customer Support page
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminCustomerSupportPage()),
        );
        break;
      case 4:
        // Navigate to Profile page
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminProfilePage()),
        );
        break;
    }
  }

  // Format date for display
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy - h:mm a').format(date);
  }

  // Helper method to display detail rows in dialogs
  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.coolGray,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: TextStyle(color: AppColors.coolGray)),
        ),
      ],
    );
  }

  // Show order details dialog
  void _showOrderDetailsDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.deepSlateGray,
            title: Text(
              'Order Details',
              style: TextStyle(color: AppColors.coolGray),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image
                  if (order['productImage'] != null && (order['productImage'] as String).isNotEmpty)
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.mutedTeal.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: ImageUtils.base64ToImage(
                            order['productImage'] as String,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                            errorWidget: const Icon(
                              Icons.shopping_bag,
                              color: AppColors.mutedTeal,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  _detailRow('Order ID:', order['id']),
                  const SizedBox(height: 8),
                  _detailRow('Product:', order['productName']),
                  const SizedBox(height: 8),
                  _detailRow(
                    'Original Price:',
                    'RM ${order['productPrice'].toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _detailRow(
                    'Final Price:',
                    'RM ${order['finalPrice'].toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _detailRow('Quantity:', order['quantity'].toString()),
                  const SizedBox(height: 8),
                  _detailRow('Buyer:', order['buyerName']),
                  const SizedBox(height: 8),
                  _detailRow('Seller:', order['sellerName']),
                  const SizedBox(height: 8),
                  _detailRow(
                    'Purchase Date:',
                    _formatDate(order['purchaseDate']),
                  ),
                  const SizedBox(height: 8),
                  _detailRow('Status:', order['status']),
                  const SizedBox(height: 16),
                  Center(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showOrderActionsDialog(order);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.mutedTeal,
                        side: const BorderSide(color: AppColors.mutedTeal),
                      ),
                      child: const Text('Manage Order'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(color: AppColors.coolGray),
                ),
              ),
            ],
          ),
    );
  }

  // Show dialog with actions for order management
  void _showOrderActionsDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.deepSlateGray,
            title: Text(
              'Manage Order',
              style: TextStyle(color: AppColors.coolGray),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit, color: AppColors.mutedTeal),
                  title: Text(
                    'Update Status',
                    style: TextStyle(color: AppColors.coolGray),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showUpdateStatusDialog(order);
                  },
                ),
                const Divider(color: AppColors.coolGray),
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.warmCoral),
                  title: Text(
                    'Delete Order',
                    style: TextStyle(color: AppColors.coolGray),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteOrderConfirmation(order);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.coolGray),
                ),
              ),
            ],
          ),
    );
  }

  // Show confirmation dialog before deleting an order
  void _showDeleteOrderConfirmation(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.deepSlateGray,
            title: Text(
              'Delete Order',
              style: TextStyle(color: AppColors.coolGray),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete this order?',
                  style: TextStyle(color: AppColors.coolGray),
                ),
                const SizedBox(height: 16),
                Text(
                  'This action cannot be undone and will remove all data associated with this order.',
                  style: TextStyle(
                    color: AppColors.coolGray.withAlpha(179),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.coolGray),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteOrder(order);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warmCoral,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  // Delete an order and related data
  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    try {
      final String orderId = order['id'] as String;

      // Batch for all delete operations
      WriteBatch batch = _firestore.batch();

      // Delete the order
      final orderRef = _firestore.collection('orders').doc(orderId);
      batch.delete(orderRef);

      // Delete any reviews related to this order
      final relatedReviews =
          await _firestore
              .collection('reviews')
              .where('orderId', isEqualTo: orderId)
              .get();

      for (var doc in relatedReviews.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch
      await batch.commit();

      // Refresh orders list
      _fetchOrders();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order has been deleted'),
            backgroundColor: AppColors.mutedTeal,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting order: ${e.toString()}'),
            backgroundColor: AppColors.warmCoral,
          ),
        );
      }
    }
  }

  // Show dialog to update order status
  void _showUpdateStatusDialog(Map<String, dynamic> order) {
    String selectedStatus = order['status'];

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  backgroundColor: AppColors.deepSlateGray,
                  title: Text(
                    'Update Order Status',
                    style: TextStyle(color: AppColors.coolGray),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Status: ${order['status']}',
                        style: TextStyle(color: AppColors.coolGray),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select New Status:',
                        style: TextStyle(color: AppColors.coolGray),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        children:
                            [
                                  'Pending',
                                  'Processed',
                                  'Out For Delivery',
                                  'Received',
                                  'Cancelled',
                                ]
                                .map(
                                  (status) => ChoiceChip(
                                    label: Text(status),
                                    selected: selectedStatus == status,
                                    onSelected: (selected) {
                                      setState(() {
                                        selectedStatus = status;
                                      });
                                    },
                                    backgroundColor: AppColors.charcoalBlack,
                                    selectedColor: AppColors.mutedTeal,
                                    labelStyle: TextStyle(
                                      color:
                                          selectedStatus == status
                                              ? Colors.white
                                              : AppColors.coolGray,
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.coolGray),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateOrderStatus(order['id'], selectedStatus);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mutedTeal,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Update'),
                    ),
                  ],
                ),
          ),
    );
  }

  // Update order status
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
      });

      // Refresh orders list
      _fetchOrders();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to $newStatus'),
            backgroundColor: AppColors.mutedTeal,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating order status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order status: ${e.toString()}'),
            backgroundColor: AppColors.warmCoral,
          ),
        );
      }
    }
  }

  // Build the UI for the status badge
  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    
    // Since status is already in title case, we can use it directly
    switch (status) {
      case 'Processed':
        badgeColor = AppColors.mutedTeal;
        break;
      case 'Out For Delivery':
        badgeColor = Colors.orange;
        break;
      case 'Received':
        badgeColor = Colors.green;
        break;
      case 'Cancelled':
        badgeColor = AppColors.coolGray;
        break;
      case 'Pending':
      default:
        badgeColor = AppColors.warmCoral;
        break;
    }
    
    // Use the status as is since it's already in title case
    final displayStatus = status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: badgeColor,
          fontSize: 10.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Build status filter chip
  Widget _buildStatusFilterChip(String status) {
    final isSelected = _selectedStatus == status;
    String displayStatus = status;
    
    // Convert status to title case for display
    if (status.toLowerCase() == 'out for delivery') {
      displayStatus = 'Out For Delivery';
    } else if (status.isNotEmpty) {
      displayStatus = status[0].toUpperCase() + status.substring(1).toLowerCase();
    }
    
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(displayStatus),
        selected: isSelected,
        checkmarkColor: Colors.white,
        selectedColor: AppColors.mutedTeal,
        backgroundColor: AppColors.charcoalBlack,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.coolGray,
        ),
        onSelected: (selected) {
          setState(() {
            _selectedStatus = status;
            _filterOrders();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: AppColors.deepSlateGray,
        title: const Text(
          'Order Management',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: const EdgeInsets.all(16.0),
            color: AppColors.deepSlateGray,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search orders...',
                    hintStyle: TextStyle(color: AppColors.coolGray),
                    prefixIcon: Icon(Icons.search, color: AppColors.coolGray),
                    filled: true,
                    fillColor: AppColors.charcoalBlack,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _filterOrders();
                    });
                  },
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatusFilterChip('All'),
                          _buildStatusFilterChip('pending'),
                          _buildStatusFilterChip('processed'),
                          _buildStatusFilterChip('out for delivery'),
                          _buildStatusFilterChip('received'),
                          _buildStatusFilterChip('cancelled'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Orders count
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            color: AppColors.mutedTeal.withValues(alpha: 0.2),
            child: Row(
              children: [
                Text(
                  'Total Orders: ${_filteredOrders.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          // Orders list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredOrders.isEmpty
                    ? Center(
                      child: Text(
                        'No orders found',
                        style: TextStyle(color: AppColors.coolGray),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = _filteredOrders[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4.0,
                            horizontal: 8.0,
                          ),
                          color: AppColors.deepSlateGray,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.mutedTeal.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child:
                                  order['productImage'] != null &&
                                          (order['productImage'] as String)
                                              .isNotEmpty
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          8.0,
                                        ),
                                        child: ImageUtils.base64ToImage(
                                          order['productImage'] as String,
                                          fit: BoxFit.cover,
                                          width: 50,
                                          height: 50,
                                          errorWidget: const Icon(
                                            Icons.shopping_bag,
                                            color: AppColors.mutedTeal,
                                          ),
                                        ),
                                      )
                                      : const Icon(
                                        Icons.shopping_bag,
                                        color: AppColors.mutedTeal,
                                      ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    order['productName'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildStatusBadge(order['status']),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'RM ${order['finalPrice'].toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: AppColors.mutedTeal,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Qty: ${order['quantity']}',
                                      style: TextStyle(
                                        color: AppColors.coolGray,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _formatDate(order['purchaseDate']),
                                    style: TextStyle(
                                      color: AppColors.coolGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                              ),
                              onPressed: () => _showOrderActionsDialog(order),
                            ),
                            onTap: () => _showOrderDetailsDialog(order),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.deepSlateGray,
        selectedItemColor: AppColors.softLemonYellow,
        unselectedItemColor: AppColors.coolGray,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_outlined),
            activeIcon: Icon(Icons.receipt),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.support_agent_outlined),
            activeIcon: Icon(Icons.support_agent),
            label: 'Support',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
