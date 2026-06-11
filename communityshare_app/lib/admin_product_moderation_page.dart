// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'constants.dart';
import 'utils/image_utils.dart';
import 'admin_profile_page.dart';
import 'admin_user_management_page.dart';
import 'admin_order_management_page.dart';
import 'admin_customer_support_page.dart';
import 'utils/page_transitions.dart';

class AdminProductModerationPage extends StatefulWidget {
  const AdminProductModerationPage({super.key});

  @override
  State<AdminProductModerationPage> createState() =>
      _AdminProductModerationPageState();
}

class _AdminProductModerationPageState
    extends State<AdminProductModerationPage> {
  int _selectedIndex =
      1; // 0 for User Management, 1 for Product Moderation, 2 for Order Moderation, 3 for Customer Support, 4 for Profile
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _filteredReports = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'All';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch all reports from Firestore
  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot reportsSnapshot =
          await _firestore
              .collection('reports')
              .orderBy('timestamp', descending: true)
              .get();

      List<Map<String, dynamic>> reports = [];

      for (var doc in reportsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Get product details
        DocumentSnapshot productDoc =
            await _firestore
                .collection('products')
                .doc(data['productId'] as String)
                .get();

        Map<String, dynamic>? productData;
        if (productDoc.exists) {
          productData = productDoc.data() as Map<String, dynamic>?;
        }

        // Get reporter details
        DocumentSnapshot reporterDoc =
            await _firestore
                .collection('users')
                .doc(data['reporterId'] as String)
                .get();

        Map<String, dynamic>? reporterData;
        if (reporterDoc.exists) {
          reporterData = reporterDoc.data() as Map<String, dynamic>?;
        }

        // Get seller details
        DocumentSnapshot sellerDoc =
            await _firestore
                .collection('users')
                .doc(data['sellerId'] as String)
                .get();

        Map<String, dynamic>? sellerData;
        if (sellerDoc.exists) {
          sellerData = sellerDoc.data() as Map<String, dynamic>?;
        }

        // Convert Firestore data to app format
        reports.add({
          'id': doc.id,
          'productId': data['productId'] as String,
          'productName': productData?['name'] ?? 'Product Unavailable',
          'productImage': productData?['imageUrl'] ?? '',
          'productPrice': productData?['price'] ?? 0.0,
          'reporterId': data['reporterId'] as String,
          'reporterName': reporterData?['username'] ?? 'Unknown User',
          'sellerId': data['sellerId'] as String,
          'sellerName': sellerData?['username'] ?? 'Unknown Seller',
          'reason': data['reason'] as String,
          'description': data['description'] as String,
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
          'status': data['status'] as String,
        });
      }

      setState(() {
        _reports = reports;
        _filteredReports = reports;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching reports: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Filter reports based on search query and status
  void _filterReports() {
    setState(() {
      _filteredReports =
          _reports.where((report) {
            final matchesSearch =
                report['productName'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                report['sellerName'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );

            final matchesStatus =
                _selectedStatus.toLowerCase() == 'all' ||
                report['status'].toString().toLowerCase() ==
                    _selectedStatus.toLowerCase();

            return matchesSearch && matchesStatus;
          }).toList();
    });
  }

  // Format date to readable string
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy - h:mm a').format(date);
  }

  // Show report details dialog
  void _showReportDetailsDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.deepSlateGray,
            title: Text(
              'Report Details',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppColors.mutedTeal.withValues(alpha: 0.2),
                      ),
                      child:
                          report['productImage'] != null &&
                                  (report['productImage'] as String).isNotEmpty
                              ? ImageUtils.base64ToImage(
                                report['productImage'] as String,
                                width: 150,
                                height: 150,
                                fit: BoxFit.cover,
                                errorWidget: const Icon(
                                  Icons.image_not_supported,
                                  color: AppColors.mutedTeal,
                                  size: 64,
                                ),
                              )
                              : const Icon(
                                Icons.image_not_supported,
                                color: AppColors.mutedTeal,
                                size: 64,
                              ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _detailRow('Product', report['productName'] as String),
                  _detailRow(
                    'Price',
                    'RM ${report['productPrice'].toStringAsFixed(2)}',
                  ),
                  _detailRow('Seller', report['sellerName'] as String),
                  _detailRow('Reported By', report['reporterName'] as String),
                  _detailRow('Reason', report['reason'] as String),
                  _detailRow('Description', report['description'] as String),
                  _detailRow('Status', report['status'] as String),
                  _detailRow(
                    'Report Date',
                    _formatDate(report['timestamp'] as DateTime),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showProductActionsDialog(report);
                },
                child: Text(
                  'Take Action',
                  style: TextStyle(color: AppColors.mutedTeal),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: TextStyle(color: AppColors.coolGray),
                ),
              ),
            ],
          ),
    );
  }

  // Helper to create detail row
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.coolGray,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          Divider(color: AppColors.coolGray.withValues(alpha: 0.3)),
        ],
      ),
    );
  }

  // Show product actions dialog
  void _showProductActionsDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.deepSlateGray,
            title: Text(
              'Take Action',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'What action would you like to take for this reported product?',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(
                      Icons.check_circle,
                      color: AppColors.mutedTeal,
                    ),
                    title: const Text(
                      'Approve Product',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Dismiss the report and keep the product',
                      style: TextStyle(color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _updateReportStatus(report['id'] as String, 'Dismissed');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.warning, color: Colors.orange),
                    title: const Text(
                      'Mark as Investigating',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Flag for further review',
                      style: TextStyle(color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _updateReportStatus(
                        report['id'] as String,
                        'Investigating',
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete, color: AppColors.warmCoral),
                    title: const Text(
                      'Remove Product',
                      style: TextStyle(color: AppColors.warmCoral),
                    ),
                    subtitle: const Text(
                      'Delete the product and resolve the report',
                      style: TextStyle(color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteProductConfirmation(report);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.coolGray),
                ),
              ),
            ],
          ),
    );
  }

  // Show delete product confirmation dialog
  void _showDeleteProductConfirmation(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.deepSlateGray,
            title: Text(
              'Delete Product',
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              'Are you sure you want to delete "${report['productName']}"? This action cannot be undone.',
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.coolGray),
                ),
              ),
              TextButton(
                onPressed: () {
                  _deleteProduct(report);
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Delete',
                  style: TextStyle(color: AppColors.warmCoral),
                ),
              ),
            ],
          ),
    );
  }

  // Update report status
  Future<void> _updateReportStatus(String reportId, String status) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': status,
      });

      // Refresh reports list
      _fetchReports();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report status updated to $status'),
            backgroundColor: AppColors.mutedTeal,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating report status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating report status: $e'),
            backgroundColor: AppColors.warmCoral,
          ),
        );
      }
    }
  }

  // Delete product and update report
  Future<void> _deleteProduct(Map<String, dynamic> report) async {
    try {
      final String productId = report['productId'] as String;

      // Batch for all delete operations
      WriteBatch batch = _firestore.batch();

      // 1. Delete the product
      final productRef = _firestore.collection('products').doc(productId);
      batch.delete(productRef);

      // 2. Delete all reports related to this product
      final relatedReports =
          await _firestore
              .collection('reports')
              .where('productId', isEqualTo: productId)
              .get();

      for (var doc in relatedReports.docs) {
        batch.delete(doc.reference);
      }

      // 3. Delete all orders related to this product
      final relatedOrders =
          await _firestore
              .collection('orders')
              .where('productId', isEqualTo: productId)
              .get();

      for (var doc in relatedOrders.docs) {
        batch.delete(doc.reference);
      }

      // 4. Delete all reviews related to this product
      final relatedReviews =
          await _firestore
              .collection('reviews')
              .where('productId', isEqualTo: productId)
              .get();

      for (var doc in relatedReviews.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch
      await batch.commit();

      // Refresh reports list
      _fetchReports();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product and all related data have been deleted'),
            backgroundColor: AppColors.mutedTeal,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting product and related data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting product: ${e.toString()}'),
            backgroundColor: AppColors.warmCoral,
          ),
        );
      }
    }
  }

  // Show report actions menu
  void _showReportActionsMenu(
    BuildContext context,
    Map<String, dynamic> report,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepSlateGray,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.info_outline, color: AppColors.mutedTeal),
                title: const Text(
                  'View Details',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDetailsDialog(report);
                },
              ),
              ListTile(
                leading: Icon(Icons.check_circle, color: AppColors.mutedTeal),
                title: const Text(
                  'Approve Product',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _updateReportStatus(report['id'] as String, 'Dismissed');
                },
              ),
              ListTile(
                leading: Icon(Icons.warning, color: Colors.orange),
                title: const Text(
                  'Mark as Investigating',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _updateReportStatus(report['id'] as String, 'Investigating');
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.warmCoral),
                title: const Text(
                  'Delete Product',
                  style: TextStyle(color: AppColors.warmCoral),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteProductConfirmation(report);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        // Navigate to User Management page
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminUserManagementPage()),
        );
        break;
      case 1:
        // Already on Products page
        break;
      case 2:
        // Navigate to Order Moderation page
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminOrderModerationPage()),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: AppColors.deepSlateGray,
        title: const Text(
          'Product Moderation',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchReports,
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
                    hintText: 'Search products...',
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
                      _filterReports();
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
                          _buildStatusFilterChip('Pending'),
                          _buildStatusFilterChip('Investigating'),
                          _buildStatusFilterChip('Dismissed'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Reports count
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            color: AppColors.mutedTeal.withValues(alpha: 0.2),
            child: Row(
              children: [
                Text(
                  'Flagged Products: ${_filteredReports.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Pending: ${_reports.where((r) => r['status'] == 'Pending').length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          // Reports list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredReports.isEmpty
                    ? Center(
                      child: Text(
                        'No flagged products found',
                        style: TextStyle(color: AppColors.coolGray),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredReports.length,
                      itemBuilder: (context, index) {
                        final report = _filteredReports[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4.0,
                            horizontal: 8.0,
                          ),
                          color: AppColors.deepSlateGray,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                            ),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.mutedTeal.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              child:
                                  report['productImage'] != null &&
                                          (report['productImage'] as String)
                                              .isNotEmpty
                                      ? ImageUtils.base64ToImage(
                                        report['productImage'] as String,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorWidget: const Icon(
                                          Icons.image_not_supported,
                                          color: AppColors.mutedTeal,
                                          size: 24,
                                        ),
                                      )
                                      : const Icon(
                                        Icons.image_not_supported,
                                        color: AppColors.mutedTeal,
                                        size: 24,
                                      ),
                            ),
                            title: Text(
                              report['productName'] as String,
                              style: const TextStyle(color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reason: ${report['reason']}',
                                  style: TextStyle(color: AppColors.coolGray),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  'Seller: ${report['sellerName']}',
                                  style: TextStyle(color: AppColors.coolGray),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    _buildStatusBadge(
                                      report['status'] as String,
                                    ),
                                    Text(
                                      _formatDate(
                                        report['timestamp'] as DateTime,
                                      ),
                                      style: TextStyle(
                                        color: AppColors.coolGray,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                              ),
                              onPressed:
                                  () => _showReportActionsMenu(context, report),
                            ),
                            onTap: () => _showReportDetailsDialog(report),
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

  Widget _buildStatusFilterChip(String status) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(status),
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
            _filterReports();
          });
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    final statusLower = status.toLowerCase();

    if (statusLower == 'investigating') {
      badgeColor = Colors.orange;
    } else if (statusLower == 'dismissed') {
      badgeColor = AppColors.coolGray;
    } else {
      // Pending
      badgeColor = AppColors.warmCoral;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: badgeColor,
          fontSize: 10.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
