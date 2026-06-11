// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

// Mock classes for Firebase dependencies
class MockFirebaseFirestore {}
class MockFirebaseAuth {}
class MockQuerySnapshot {
  final List<MockDocumentSnapshot> docs;
  MockQuerySnapshot(this.docs);
}
class MockDocumentSnapshot {
  final String id;
  final Map<String, dynamic> _data;
  MockDocumentSnapshot(this.id, this._data);
  Map<String, dynamic> data() => _data;
}
class MockTimestamp {
  final DateTime dateTime;
  MockTimestamp(this.dateTime);
  DateTime toDate() => dateTime;
}

// Create a testable version of AdminCustomerSupportPage that doesn't depend on Firebase
class TestableAdminCustomerSupportPage extends StatefulWidget {
  final List<Map<String, dynamic>> mockSupportRequests;
  
  const TestableAdminCustomerSupportPage({
    super.key,
    required this.mockSupportRequests,
  });

  @override
  State<TestableAdminCustomerSupportPage> createState() => _TestableAdminCustomerSupportPageState();
}

class _TestableAdminCustomerSupportPageState extends State<TestableAdminCustomerSupportPage> {
  final int _selectedIndex = 3; // Customer Support tab
  
  List<Map<String, dynamic>> _supportRequests = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  final bool _isLoading = false;
  String _searchQuery = '';
  String _selectedStatus = 'All';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _supportRequests = widget.mockSupportRequests;
    _filterRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filter support requests based on search query and status
  void _filterRequests() {
    setState(() {
      if (_searchQuery.isEmpty && _selectedStatus == 'All') {
        _filteredRequests = List.from(_supportRequests);
      } else {
        _filteredRequests = _supportRequests.where((request) {
          // Filter by status
          bool statusMatch = _selectedStatus == 'All' ||
              request['status'].toString().toLowerCase() ==
                  _selectedStatus.toLowerCase();

          // Filter by search query (username, email, subject, or message)
          bool searchMatch = _searchQuery.isEmpty ||
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

  // Format date for display
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  // Build status badge widget
  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    IconData badgeIcon;

    switch (status.toLowerCase()) {
      case 'pending':
        badgeColor = Colors.orange;
        badgeIcon = Icons.hourglass_empty;
        break;
      case 'in progress':
        badgeColor = Colors.blue;
        badgeIcon = Icons.sync;
        break;
      case 'resolved':
        badgeColor = Colors.green;
        badgeIcon = Icons.check_circle;
        break;
      case 'closed':
        badgeColor = Colors.grey;
        badgeIcon = Icons.cancel;
        break;
      default:
        badgeColor = Colors.purple;
        badgeIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(fontSize: 12, color: badgeColor),
          ),
        ],
      ),
    );
  }

  // Build status filter chip
  Widget _buildStatusFilterChip(String status) {
    bool isSelected = _selectedStatus == status;

    return FilterChip(
      label: Text(status),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? status : 'All';
          _filterRequests();
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.blue[100],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Support'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search support requests...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('Pending'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('In Progress'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('Resolved'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('Closed'),
                ],
              ),
            ),
          ),
          
          // Support requests list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRequests.isEmpty
                    ? const Center(
                        child: Text('No support requests found'),
                      )
                    : ListView.builder(
                        itemCount: _filteredRequests.length,
                        itemBuilder: (context, index) {
                          final request = _filteredRequests[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      request['subject'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                      const Icon(
                                        Icons.person_outline,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        request['username'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    request['message'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      _formatDate(request['createdAt']),
                                      style: const TextStyle(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {}, // No-op for testing
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.grey[900],
        selectedItemColor: Colors.yellow[200],
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (_) {}, // No-op for testing
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

void main() {
  // Set a larger test window size to accommodate all UI elements
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestWidgetsFlutterBinding.instance.window.physicalSizeTestValue = const Size(1024, 1600);
    TestWidgetsFlutterBinding.instance.window.devicePixelRatioTestValue = 1.0;
  });

  tearDownAll(() {
    TestWidgetsFlutterBinding.instance.window.clearPhysicalSizeTestValue();
    TestWidgetsFlutterBinding.instance.window.clearDevicePixelRatioTestValue();
  });

  // Sample support request data for testing
  final List<Map<String, dynamic>> sampleSupportRequests = [
    {
      'id': 'request1',
      'userId': 'user1',
      'username': 'John Doe',
      'email': 'john@example.com',
      'subject': 'Payment Issue',
      'message': 'I made a payment but it hasn\'t been reflected in my account.',
      'status': 'Pending',
      'userRole': 'buyer',
      'createdAt': DateTime.now().subtract(const Duration(days: 1)),
      'attachment': '',
    },
    {
      'id': 'request2',
      'userId': 'user2',
      'username': 'Jane Smith',
      'email': 'jane@example.com',
      'subject': 'Product Delivery Delay',
      'message': 'My order has been delayed for over a week.',
      'status': 'In Progress',
      'userRole': 'buyer',
      'createdAt': DateTime.now().subtract(const Duration(days: 3)),
      'attachment': 'image_data',
    },
    {
      'id': 'request3',
      'userId': 'user3',
      'username': 'Mike Johnson',
      'email': 'mike@example.com',
      'subject': 'Account Verification',
      'message': 'I need help verifying my seller account.',
      'status': 'Resolved',
      'userRole': 'seller',
      'createdAt': DateTime.now().subtract(const Duration(days: 5)),
      'attachment': '',
    },
    {
      'id': 'request4',
      'userId': 'user4',
      'username': 'Sarah Williams',
      'email': 'sarah@example.com',
      'subject': 'Refund Request',
      'message': 'I would like to request a refund for my recent purchase.',
      'status': 'Closed',
      'userRole': 'buyer',
      'createdAt': DateTime.now().subtract(const Duration(days: 10)),
      'attachment': '',
    },
  ];

  group('AdminCustomerSupportPage Widget Tests', () {
    testWidgets('should render customer support page with requests', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableAdminCustomerSupportPage(
            mockSupportRequests: sampleSupportRequests,
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify that the app bar is displayed
      expect(find.text('Customer Support'), findsOneWidget);
      
      // Verify that the search bar is displayed
      expect(find.widgetWithText(TextField, 'Search support requests...'), findsOneWidget);
      
      // Verify that status filter chips are displayed
      expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Pending'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'In Progress'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Resolved'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Closed'), findsOneWidget);
      
      // Verify that support requests are displayed
      expect(find.text('Payment Issue'), findsOneWidget);
      expect(find.text('Product Delivery Delay'), findsOneWidget);
      expect(find.text('Account Verification'), findsOneWidget);
      expect(find.text('Refund Request'), findsOneWidget);
    });

    testWidgets('should filter requests by status', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableAdminCustomerSupportPage(
            mockSupportRequests: sampleSupportRequests,
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Initially all requests should be visible
      expect(find.text('Payment Issue'), findsOneWidget);
      expect(find.text('Product Delivery Delay'), findsOneWidget);
      expect(find.text('Account Verification'), findsOneWidget);
      expect(find.text('Refund Request'), findsOneWidget);

      // Tap on the 'Pending' filter chip
      await tester.tap(find.widgetWithText(FilterChip, 'Pending'));
      await tester.pumpAndSettle();

      // Only pending requests should be visible
      expect(find.text('Payment Issue'), findsOneWidget); // Pending
      expect(find.text('Product Delivery Delay'), findsNothing); // In Progress
      expect(find.text('Account Verification'), findsNothing); // Resolved
      expect(find.text('Refund Request'), findsNothing); // Closed

      // Tap on the 'Resolved' filter chip
      await tester.tap(find.widgetWithText(FilterChip, 'Resolved'));
      await tester.pumpAndSettle();

      // Only resolved requests should be visible
      expect(find.text('Payment Issue'), findsNothing); // Pending
      expect(find.text('Product Delivery Delay'), findsNothing); // In Progress
      expect(find.text('Account Verification'), findsOneWidget); // Resolved
      expect(find.text('Refund Request'), findsNothing); // Closed

      // Tap on the 'All' filter chip to reset
      await tester.tap(find.widgetWithText(FilterChip, 'All'));
      await tester.pumpAndSettle();

      // All requests should be visible again
      expect(find.text('Payment Issue'), findsOneWidget);
      expect(find.text('Product Delivery Delay'), findsOneWidget);
      expect(find.text('Account Verification'), findsOneWidget);
      expect(find.text('Refund Request'), findsOneWidget);
    });

    testWidgets('should filter requests by search query', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableAdminCustomerSupportPage(
            mockSupportRequests: sampleSupportRequests,
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.widgetWithText(TextField, 'Search support requests...'), 'payment');
      await tester.pumpAndSettle();

      // Only requests containing 'payment' should be visible
      expect(find.text('Payment Issue'), findsOneWidget);
      expect(find.text('Product Delivery Delay'), findsNothing);
      expect(find.text('Account Verification'), findsNothing);
      expect(find.text('Refund Request'), findsNothing);

      // Clear search query
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // All requests should be visible again
      expect(find.text('Payment Issue'), findsOneWidget);
      expect(find.text('Product Delivery Delay'), findsOneWidget);
      expect(find.text('Account Verification'), findsOneWidget);
      expect(find.text('Refund Request'), findsOneWidget);

      // Search by username
      await tester.enterText(find.widgetWithText(TextField, 'Search support requests...'), 'jane');
      await tester.pumpAndSettle();

      // Only Jane's request should be visible
      expect(find.text('Payment Issue'), findsNothing);
      expect(find.text('Product Delivery Delay'), findsOneWidget);
      expect(find.text('Account Verification'), findsNothing);
      expect(find.text('Refund Request'), findsNothing);
    });

    testWidgets('should display correct status badges', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableAdminCustomerSupportPage(
            mockSupportRequests: sampleSupportRequests,
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify all status badges are displayed - using more specific finders
      // We're looking for the status text inside the Container that forms the badge
      final pendingFinder = find.descendant(
        of: find.byWidgetPredicate((widget) => 
          widget is Container && 
          (widget.decoration as BoxDecoration?)?.color?.withAlpha(255) == Colors.orange.withOpacity(0.2).withAlpha(255)
        ),
        matching: find.text('Pending')
      );
      
      final inProgressFinder = find.descendant(
        of: find.byWidgetPredicate((widget) => 
          widget is Container && 
          (widget.decoration as BoxDecoration?)?.color?.withAlpha(255) == Colors.blue.withOpacity(0.2).withAlpha(255)
        ),
        matching: find.text('In Progress')
      );
      
      final resolvedFinder = find.descendant(
        of: find.byWidgetPredicate((widget) => 
          widget is Container && 
          (widget.decoration as BoxDecoration?)?.color?.withAlpha(255) == Colors.green.withOpacity(0.2).withAlpha(255)
        ),
        matching: find.text('Resolved')
      );
      
      final closedFinder = find.descendant(
        of: find.byWidgetPredicate((widget) => 
          widget is Container && 
          (widget.decoration as BoxDecoration?)?.color?.withAlpha(255) == Colors.grey.withOpacity(0.2).withAlpha(255)
        ),
        matching: find.text('Closed')
      );
      
      expect(pendingFinder, findsOneWidget);
      expect(inProgressFinder, findsOneWidget);
      expect(resolvedFinder, findsOneWidget);
      expect(closedFinder, findsOneWidget);
    });

    testWidgets('should display dates correctly', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableAdminCustomerSupportPage(
            mockSupportRequests: sampleSupportRequests,
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify dates are formatted correctly
      final yesterday = DateFormat('MMM d, yyyy').format(DateTime.now().subtract(const Duration(days: 1)));
      expect(find.text(yesterday), findsOneWidget);
    });
  });
}
