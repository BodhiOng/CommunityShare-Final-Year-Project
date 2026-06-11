// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'constants.dart';
import 'admin_profile_page.dart';
import 'admin_user_management_page.dart';
import 'admin_product_moderation_page.dart';
import 'admin_order_management_page.dart';
import 'utils/page_transitions.dart';
import 'utils/image_utils.dart';
import 'admin_messages_page.dart';
import 'admin_chat_detail_page.dart';

class AdminCustomerSupportPage extends StatefulWidget {
  const AdminCustomerSupportPage({super.key});

  @override
  State<AdminCustomerSupportPage> createState() =>
      _AdminCustomerSupportPageState();
}

class _AdminCustomerSupportPageState extends State<AdminCustomerSupportPage> {
  final int _selectedIndex =
      3; // 0 for User Management, 1 for Product Moderation, 2 for Order Moderation, 3 for Customer Support, 4 for Profile
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _supportRequests = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'All';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSupportRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch all support requests from Firestore
  Future<void> _fetchSupportRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot requestsSnapshot =
          await _firestore
              .collection('helpCenterRequests')
              .orderBy('createdAt', descending: true)
              .get();

      List<Map<String, dynamic>> requests = [];

      for (var doc in requestsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Convert Firestore data to app format
        requests.add({
          'id': doc.id,
          'userId': data['userId'] as String? ?? '',
          'username': data['username'] as String? ?? 'Anonymous User',
          'email': data['email'] as String? ?? '',
          'subject': data['subject'] as String? ?? 'No Subject',
          'message': data['message'] as String? ?? '',
          'status': data['status'] as String? ?? 'Pending',
          'userRole': data['userRole'] as String? ?? '',
          'createdAt':
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'attachment': data['attachment'] as String? ?? '',
        });
      }

      setState(() {
        _supportRequests = requests;
        _filterRequests();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching support requests: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Filter support requests based on search query and status
  void _filterRequests() {
    setState(() {
      if (_searchQuery.isEmpty && _selectedStatus == 'All') {
        _filteredRequests = List.from(_supportRequests);
      } else {
        _filteredRequests =
            _supportRequests.where((request) {
              // Filter by status
              bool statusMatch =
                  _selectedStatus == 'All' ||
                  request['status'].toString().toLowerCase() ==
                      _selectedStatus.toLowerCase();

              // Filter by search query (username, email, subject, or message)
              bool searchMatch =
                  _searchQuery.isEmpty ||
                  request['username'].toString().toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  request['email'].toString().toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  request['subject'].toString().toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  request['message'].toString().toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  );

              return statusMatch && searchMatch;
            }).toList();
      }
    });
  }

  // Handle bottom navigation
  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminUserManagementPage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminProductModerationPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminOrderModerationPage()),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminProfilePage()),
        );
        break;
    }
  }

  // Format date for display
  String _formatDate(DateTime date) {
    return DateFormat("MMM d, yyyy 'at' h:mm a").format(date);
  }

  // Create a detail row for the support request details dialog
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.coolGray,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Show support request details dialog
  // Method to start a chat with a user for support purposes
  Future<void> _startChatWithUser(String userId, String username) async {
    try {
      if (userId.isEmpty) {
        throw Exception('User ID is required');
      }

      // Get current admin ID
      final adminId = FirebaseAuth.instance.currentUser?.uid;
      if (adminId == null) {
        throw Exception('Admin not authenticated');
      }

      // Check if a chat already exists between admin and this user
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: adminId)
              .get();

      String? existingChatId;

      // Look for an existing chat with this user
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);

        if (participants.contains(userId)) {
          // Chat already exists
          existingChatId = doc.id;
          break;
        }
      }

      // If no existing chat, create a new one
      if (existingChatId == null) {
        // Get user details
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
        final userData = userDoc.data();

        if (userData == null) {
          throw Exception('User not found');
        }

        // Create a new chat document
        final chatRef = FirebaseFirestore.instance.collection('chats').doc();

        // Set up the chat document for support
        await chatRef.set({
          'id': chatRef.id,
          'participants': [adminId, userId],
          'productId': 'support', // Just a marker to identify support chats
          'lastMessage': 'Support chat started',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'lastMessageSenderId': adminId,
          'unreadCount': {userId: 1, adminId: 0},
          'participantNames': {adminId: 'Admin Support', userId: username},
          'isSupport': true, // Flag to identify this as a support chat
        });

        existingChatId = chatRef.id;
      }

      // existingChatId is guaranteed to be non-null at this point based on our logic above
      // Check if this is a new chat based on the lastMessage
      final chatDoc =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(existingChatId)
              .get();
      final chatData = chatDoc.data() as Map<String, dynamic>;
      final bool isNewChat = chatData['lastMessage'] == 'Support chat started';

      if (isNewChat) {
        // New chat - send welcome message first
        // Create message document for welcome message
        final welcomeMessageRef =
            FirebaseFirestore.instance
                .collection('chats')
                .doc(existingChatId)
                .collection('messages')
                .doc();

        await welcomeMessageRef.set({
          'id': welcomeMessageRef.id,
          'senderId': adminId,
          'text': 'Hello, this is Help Center. How may I assist you? [This message is system-generated]',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'imageUrl': null,
          'chatId': existingChatId,
        });

        // Update the chat document with the welcome message
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(existingChatId)
            .update({
              'lastMessage':
                  'Hello, this is Help Center. How may I assist you?',
              'lastMessageTimestamp': FieldValue.serverTimestamp(),
              'lastMessageSenderId': adminId,
            });

        // Get the updated chat data
        final updatedChatDoc =
            await FirebaseFirestore.instance
                .collection('chats')
                .doc(existingChatId)
                .get();
        final updatedChatData = updatedChatDoc.data() as Map<String, dynamic>;

        // Navigate to chat detail page with updated data
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => AdminChatDetailPage(
                  chatId: existingChatId!,
                  chatData: updatedChatData,
                ),
          ),
        );
      } else {
        // Existing chat - just navigate to it
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => AdminChatDetailPage(
                  chatId: existingChatId!,
                  chatData: chatData,
                ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Navigate to messages page
  void _navigateToMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminMessagesPage()),
    );
  }

  void _showRequestDetailsDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.deepSlateGray,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Title with status
                  // Title row
                  Text(
                    request['subject'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  
                  // Status row with some top margin
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                      child: _buildStatusBadge(request['status']),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Request details
                  // User details section
                  _detailRow('From', request['username']),
                  _detailRow('Email', request['email']),
                  _detailRow('User Role', request['userRole']),
                  _detailRow('Date', _formatDate(request['createdAt'])),
                  
                  const SizedBox(height: 16),
                  
                  // Message content
                  const Text(
                    'Message:',
                    style: TextStyle(
                      color: AppColors.coolGray,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150, // Fixed height for the message container
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: AppColors.deepSlateGray.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: AppColors.coolGray.withValues(alpha: 0.3),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          request['message'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),

                  // Display attachment if available
                  if (request['attachment'] != null &&
                      request['attachment'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Attachment:',
                      style: TextStyle(
                        color: AppColors.coolGray,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: AppColors.coolGray.withValues(alpha: 0.3),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ImageUtils.base64ToImage(
                        request['attachment'],
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                  
                  // Buttons at the bottom with enhanced styling
                  const SizedBox(height: 24),
                  IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Chat button - only show if user ID is available
                        if (request['userId'] != null && request['userId'].toString().isNotEmpty) ...[
                          Expanded(
                            flex: 2,
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.mutedTeal, width: 1.5),
                              ),
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.mutedTeal),
                                label: const Text(
                                  'Chat',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _startChatWithUser(
                                    request['userId'],
                                    request['username'] ?? 'User',
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                        
                        // Resolve/Pending button - takes remaining space
                        Expanded(
                          flex: 3,
                          child: Container(
                            margin: request['userId'] != null && request['userId'].toString().isNotEmpty
                                ? const EdgeInsets.only(left: 8)
                                : null,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: request['status'] == 'Pending' 
                                    ? AppColors.mutedTeal 
                                    : Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _updateRequestStatus(
                                  request['id'],
                                  request['status'] == 'Pending' ? 'Resolved' : 'Pending',
                                );
                              },
                              child: Text(
                                request['status'] == 'Pending' 
                                    ? 'Mark as Resolved' 
                                    : 'Mark as Pending',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Update support request status
  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    try {
      await _firestore.collection('helpCenterRequests').doc(requestId).update({
        'status': newStatus,
      });

      // Refresh the list
      _fetchSupportRequests();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request marked as $newStatus'),
          backgroundColor: AppColors.mutedTeal,
        ),
      );
    } catch (e) {
      debugPrint('Error updating request status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update request status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Build status badge for support request
  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    Color textColor = Colors.white;

    switch (status.toLowerCase()) {
      case 'pending':
        badgeColor = Colors.orange;
        break;
      case 'resolved':
        badgeColor = AppColors.mutedTeal;
        break;
      default:
        badgeColor = AppColors.coolGray;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Build status filter chip
  Widget _buildStatusFilterChip(String status) {
    final isSelected = _selectedStatus == status;

    return FilterChip(
      selected: isSelected,
      selectedColor: AppColors.mutedTeal.withValues(alpha: 0.8),
      backgroundColor: AppColors.deepSlateGray,
      checkmarkColor: Colors.white,
      label: Text(
        status,
        style: TextStyle(color: isSelected ? Colors.white : AppColors.coolGray),
      ),
      onSelected: (selected) {
        setState(() {
          _selectedStatus = status;
          _filterRequests();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: AppColors.deepSlateGray,
        title: const Text(
          'Customer Support',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          // Messages button
          IconButton(
            icon: const Icon(Icons.message_outlined, color: Colors.white),
            tooltip: 'Messages',
            onPressed: _navigateToMessages,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchSupportRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by username, email, subject, or message',
                hintStyle: TextStyle(color: AppColors.coolGray),
                prefixIcon: Icon(Icons.search, color: AppColors.coolGray),
                filled: true,
                fillColor: AppColors.deepSlateGray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppColors.coolGray,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _filterRequests();
                            });
                          },
                        )
                        : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterRequests();
                });
              },
            ),
          ),

          // Status filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8.0,
              children: [
                _buildStatusFilterChip('All'),
                _buildStatusFilterChip('Pending'),
                _buildStatusFilterChip('Resolved'),
              ],
            ),
          ),

          // Support requests list
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.mutedTeal,
                      ),
                    )
                    : _filteredRequests.isEmpty
                    ? Center(
                      child: Text(
                        'No support requests found',
                        style: TextStyle(
                          color: AppColors.coolGray,
                          fontSize: 16.0,
                        ),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: _filteredRequests.length,
                      itemBuilder: (context, index) {
                        final request = _filteredRequests[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4.0,
                            horizontal: 8.0,
                          ),
                          color: AppColors.deepSlateGray,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    request['subject'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildStatusBadge(request['status']),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      request['username'],
                                      style: TextStyle(
                                        color: AppColors.mutedTeal,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${request['userRole']})',
                                      style: TextStyle(
                                        color: AppColors.coolGray,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  request['message'],
                                  style: TextStyle(
                                    color: AppColors.coolGray,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                // Show attachment indicator if available
                                if (request['attachment'] != null &&
                                    request['attachment'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.image,
                                          size: 14,
                                          color: AppColors.mutedTeal,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Has attachment',
                                          style: TextStyle(
                                            color: AppColors.mutedTeal,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    _formatDate(request['createdAt']),
                                    style: TextStyle(
                                      color: AppColors.coolGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _showRequestDetailsDialog(request),
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
