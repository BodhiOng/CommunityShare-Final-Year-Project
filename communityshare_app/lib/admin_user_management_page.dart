import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'constants.dart';
import 'utils/image_utils.dart';
import 'admin_product_moderation_page.dart';
import 'admin_order_management_page.dart';
import 'admin_profile_page.dart';
import 'admin_customer_support_page.dart';
import 'utils/page_transitions.dart';

class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({super.key});

  @override
  State<AdminUserManagementPage> createState() =>
      _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage> {
  int _selectedIndex = 0; // 0 for User Management, 1 for Product Moderation, 2 for Order Moderation, 3 for Customer Support, 4 for Profile
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedRole = 'All';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch all users from Firestore
  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot usersSnapshot =
          await _firestore.collection('users').orderBy('username').get();

      List<Map<String, dynamic>> users = [];

      for (var doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Convert Firestore data to app format
        users.add({
          'id': doc.id,
          'username': data['username'] ?? 'Unknown User',
          'email': data['email'] ?? '',
          'role': (data['role'] ?? 'buyer').toLowerCase(),
          'address': data['address'] ?? '',
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'walletBalance': (data['walletBalance'] ?? 0.0).toDouble(),
          'joinDate':
              data['joinDate'] != null
                  ? (data['joinDate'] as Timestamp).toDate()
                  : DateTime.now(),
          'uid': data['uid'] ?? '',
        });
      }

      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Filter users based on search query and role
  void _filterUsers() {
    setState(() {
      _filteredUsers =
          _users.where((user) {
            final matchesSearch =
                user['username'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                user['email'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                user['address'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );

            final matchesRole =
                _selectedRole.toLowerCase() == 'all' ||
                user['role'].toString().toLowerCase() ==
                    _selectedRole.toLowerCase();

            return matchesSearch && matchesRole;
          }).toList();
    });
  }

  // Format date to readable string
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  // Show user details dialog
  void _showUserDetailsDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.deepSlateGray,
            title: Text(
              'User Details',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.mutedTeal.withValues(alpha: 0.2),
                      ),
                      child:
                          user['profileImageUrl'] != null &&
                                  (user['profileImageUrl'] as String).isNotEmpty
                              ? ClipOval(
                                child: ImageUtils.base64ToImage(
                                  user['profileImageUrl'] as String,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorWidget: const Icon(
                                    Icons.person,
                                    color: AppColors.mutedTeal,
                                    size: 64,
                                  ),
                                ),
                              )
                              : const Icon(
                                Icons.person,
                                color: AppColors.mutedTeal,
                                size: 64,
                              ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _detailRow('Username', user['username'] as String),
                  _detailRow('Email', user['email'] as String),
                  _detailRow('Role', user['role'] as String),
                  _detailRow('Address', user['address'] as String),
                  _detailRow(
                    'Wallet Balance',
                    'RM ${(user['walletBalance'] as double).toStringAsFixed(2)}',
                  ),
                  _detailRow(
                    'Join Date',
                    _formatDate(user['joinDate'] as DateTime),
                  ),
                  _detailRow('User ID', user['uid'] as String),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showEditUserDialog(user);
                },
                child: Text(
                  'Edit',
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

  // Show edit user dialog
  void _showEditUserDialog(Map<String, dynamic> user) {
    final TextEditingController usernameController = TextEditingController(
      text: user['username'] as String,
    );
    final TextEditingController emailController = TextEditingController(
      text: user['email'] as String,
    );
    final TextEditingController addressController = TextEditingController(
      text: user['address'] as String,
    );
    final TextEditingController walletBalanceController = TextEditingController(
      text: (user['walletBalance'] as double).toStringAsFixed(2),
    );
    String role = user['role'] as String;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.deepSlateGray,
            title: Text(
              'Edit User',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: TextStyle(color: AppColors.coolGray),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.coolGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.mutedTeal),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: AppColors.coolGray),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.coolGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.mutedTeal),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Address',
                      labelStyle: TextStyle(color: AppColors.coolGray),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.coolGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.mutedTeal),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: walletBalanceController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Wallet Balance (RM)',
                      labelStyle: TextStyle(color: AppColors.coolGray),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.coolGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.mutedTeal),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: role,
                    dropdownColor: AppColors.charcoalBlack,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Role',
                      labelStyle: TextStyle(color: AppColors.coolGray),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.coolGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.mutedTeal),
                      ),
                    ),
                    items:
                        ['buyer', 'seller', 'admin'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value.substring(0, 1).toUpperCase() +
                                  value.substring(1),
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        role = newValue;
                      }
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
              TextButton(
                onPressed: () {
                  // Update user in Firestore
                  _updateUser(
                    user['id'] as String,
                    usernameController.text,
                    emailController.text,
                    addressController.text,
                    double.tryParse(walletBalanceController.text) ??
                        user['walletBalance'] as double,
                    role,
                  );
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Save',
                  style: TextStyle(color: AppColors.mutedTeal),
                ),
              ),
            ],
          ),
    );
  }

  // Update user in Firestore
  Future<void> _updateUser(
    String userId,
    String username,
    String email,
    String address,
    double walletBalance,
    String role,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'username': username,
        'email': email,
        'address': address,
        'walletBalance': walletBalance,
        'role': role,
      });

      // Refresh user list
      _fetchUsers();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User updated successfully'),
            backgroundColor: AppColors.mutedTeal,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: AppColors.warmCoral,
          ),
        );
      }
    }
  }

  // Show delete user confirmation dialog
  void _showDeleteUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.deepSlateGray,
            title: Text(
              'Delete User',
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              'Are you sure you want to delete ${user['username']}? This action cannot be undone.',
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
                  _deleteUser(user['id'] as String);
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

  // Delete user and all related data from Firestore
  Future<void> _deleteUser(String userId) async {
    try {
      // Batch for all delete operations
      WriteBatch batch = _firestore.batch();

      // 1. Delete from users collection
      final userRef = _firestore.collection('users').doc(userId);
      batch.delete(userRef);

      // 2. Delete from helpCenterRequests where userId matches
      final helpCenterRequests =
          await _firestore
              .collection('helpCenterRequests')
              .where('userId', isEqualTo: userId)
              .get();
      for (var doc in helpCenterRequests.docs) {
        batch.delete(doc.reference);
      }

      // 3. Delete from orders where buyerId or sellerId matches
      final ordersAsBuyer =
          await _firestore
              .collection('orders')
              .where('buyerId', isEqualTo: userId)
              .get();
      for (var doc in ordersAsBuyer.docs) {
        batch.delete(doc.reference);
      }

      final ordersAsSeller =
          await _firestore
              .collection('orders')
              .where('sellerId', isEqualTo: userId)
              .get();
      for (var doc in ordersAsSeller.docs) {
        batch.delete(doc.reference);
      }

      // 4. Delete from products where sellerId matches
      final products =
          await _firestore
              .collection('products')
              .where('sellerId', isEqualTo: userId)
              .get();
      for (var doc in products.docs) {
        batch.delete(doc.reference);
      }

      // 5. Delete from reports where reporterId or sellerId matches
      final reportsAsReporter =
          await _firestore
              .collection('reports')
              .where('reporterId', isEqualTo: userId)
              .get();
      for (var doc in reportsAsReporter.docs) {
        batch.delete(doc.reference);
      }

      final reportsAsSeller =
          await _firestore
              .collection('reports')
              .where('sellerId', isEqualTo: userId)
              .get();
      for (var doc in reportsAsSeller.docs) {
        batch.delete(doc.reference);
      }

      // 6. Delete from reviews where reviewerId or sellerId matches
      final reviewsAsReviewer =
          await _firestore
              .collection('reviews')
              .where('reviewerId', isEqualTo: userId)
              .get();
      for (var doc in reviewsAsReviewer.docs) {
        batch.delete(doc.reference);
      }

      final reviewsAsSeller =
          await _firestore
              .collection('reviews')
              .where('sellerId', isEqualTo: userId)
              .get();
      for (var doc in reviewsAsSeller.docs) {
        batch.delete(doc.reference);
      }

      // 7. Delete from walletTransactions where userId matches
      final transactions =
          await _firestore
              .collection('walletTransactions')
              .where('userId', isEqualTo: userId)
              .get();
      for (var doc in transactions.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch
      await batch.commit();

      // Refresh user list
      _fetchUsers();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'User and all related data have been deleted successfully',
            ),
            backgroundColor: AppColors.mutedTeal,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting user data: ${e.toString()}'),
            backgroundColor: AppColors.warmCoral,
          ),
        );
      }
    }
  }

  // Show user actions menu
  void _showUserActionsMenu(BuildContext context, Map<String, dynamic> user) {
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
                  _showUserDetailsDialog(user);
                },
              ),
              ListTile(
                leading: Icon(Icons.edit, color: AppColors.mutedTeal),
                title: const Text(
                  'Edit User',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEditUserDialog(user);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.warmCoral),
                title: const Text(
                  'Delete User',
                  style: TextStyle(color: AppColors.warmCoral),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteUserDialog(user);
                },
              ),
              if (user['role'] != 'admin')
                ListTile(
                  leading: Icon(
                    Icons.admin_panel_settings,
                    color: AppColors.softLemonYellow,
                  ),
                  title: const Text(
                    'Make Admin',
                    style: TextStyle(color: AppColors.softLemonYellow),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _updateUser(
                      user['id'] as String,
                      user['username'] as String,
                      user['email'] as String,
                      user['address'] as String,
                      user['walletBalance'] as double,
                      'admin',
                    );
                  },
                ),
              if (user['role'] == 'user')
                ListTile(
                  leading: Icon(Icons.store, color: AppColors.softLemonYellow),
                  title: const Text(
                    'Make Seller',
                    style: TextStyle(color: AppColors.softLemonYellow),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _updateUser(
                      user['id'] as String,
                      user['username'] as String,
                      user['email'] as String,
                      user['address'] as String,
                      user['walletBalance'] as double,
                      'seller',
                    );
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
        // Already on Users page
        break;
      case 1:
        // Navigate to Products page
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminProductModerationPage()),
        );
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
          'User Management',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchUsers,
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
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16.0),
            color: AppColors.deepSlateGray,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    hintStyle: TextStyle(color: AppColors.coolGray),
                    prefixIcon: Icon(Icons.search, color: AppColors.coolGray),
                    filled: true,
                    fillColor: AppColors.charcoalBlack,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: AppColors.coolGray,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _filterUsers();
                                });
                              },
                            )
                            : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _filterUsers();
                    });
                  },
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildRoleFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('Buyer'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('Seller'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('Admin'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // User count and stats
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredUsers.length} ${_filteredUsers.length == 1 ? 'user' : 'users'} found',
                  style: TextStyle(color: AppColors.coolGray),
                ),
                Text(
                  'Total Users: ${_users.length}',
                  style: TextStyle(color: AppColors.coolGray),
                ),
              ],
            ),
          ),

          // User list
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.mutedTeal,
                      ),
                    )
                    : _filteredUsers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 64,
                            color: AppColors.coolGray.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: TextStyle(
                              color: AppColors.coolGray,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          color: AppColors.deepSlateGray,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.mutedTeal.withValues(
                                alpha: 0.2,
                              ),
                              child:
                                  user['profileImageUrl'] != null &&
                                          (user['profileImageUrl'] as String)
                                              .isNotEmpty
                                      ? ClipOval(
                                        child: ImageUtils.base64ToImage(
                                          user['profileImageUrl'] as String,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorWidget: const Icon(
                                            Icons.person,
                                            color: AppColors.mutedTeal,
                                            size: 32,
                                          ),
                                        ),
                                      )
                                      : const Icon(
                                        Icons.person,
                                        color: AppColors.mutedTeal,
                                        size: 32,
                                      ),
                            ),
                            title: Text(
                              user['username'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['email'] as String,
                                  style: TextStyle(
                                    color: AppColors.coolGray,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildRoleBadge(user['role'] as String),
                                    const SizedBox(width: 8),
                                    Text(
                                      'RM ${(user['walletBalance'] as double).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: AppColors.mutedTeal,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                  () => _showUserActionsMenu(context, user),
                            ),
                            onTap: () => _showUserDetailsDialog(user),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  // Build role filter chip
  Widget _buildRoleFilterChip(String role) {
    final isSelected = _selectedRole == role;

    return FilterChip(
      label: Text(
        role,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.coolGray,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      showCheckmark: false,
      backgroundColor: AppColors.charcoalBlack,
      selectedColor: AppColors.mutedTeal,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              isSelected
                  ? AppColors.mutedTeal
                  : AppColors.coolGray.withValues(alpha: 0.3),
        ),
      ),
      onSelected: (selected) {
        setState(() {
          _selectedRole = selected ? role : 'All';
          _filterUsers();
        });
      },
    );
  }

  // Build role badge
  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    final roleLower = role.toLowerCase();

    if (roleLower == 'admin') {
      badgeColor = AppColors.softLemonYellow;
    } else if (roleLower == 'seller') {
      badgeColor = Colors.green;
    } else {
      // buyer
      badgeColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.substring(0, 1).toUpperCase() + role.substring(1),
        style: TextStyle(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
