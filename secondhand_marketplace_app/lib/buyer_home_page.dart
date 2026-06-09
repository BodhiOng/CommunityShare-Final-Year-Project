import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';
import 'buyer_search_results_page.dart';
import 'buyer_product_details_page.dart';
import 'buyer_purchases_page.dart';
import 'buyer_wallet_page.dart';
import 'buyer_profile_page.dart';
import 'buyer_messages_page.dart';
import 'buyer_category_page.dart';
import 'buyer_featured_items_page.dart';
import 'buyer_recent_items_page.dart';
import 'models/product.dart';
import 'utils/page_transitions.dart';
import 'utils/image_utils.dart';

// Homepage for the secondhand marketplace app
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  // Try to get Firestore instance, but handle the case where Firebase isn't initialized
  late final FirebaseFirestore? _firestore;

  // Flag to track if Firebase is available
  bool _isFirebaseAvailable = true;
  List<Product> _featuredProducts = [];
  List<Product> _recentProducts = [];
  bool _isLoadingFeatured = true;
  bool _isLoadingRecent = true;

  @override
  void initState() {
    super.initState();

    // Initialize Firestore and check if it's available
    try {
      _firestore = FirebaseFirestore.instance;
      _fetchFeaturedProducts();
      _fetchRecentProducts();
    } catch (e) {
      debugPrint('Error accessing Firestore: $e');
      setState(() {
        _isFirebaseAvailable = false;
        _isLoadingFeatured = false;
        _isLoadingRecent = false;
      });
    }
  }

  // Fetch products with highest ad boost price
  Future<void> _fetchFeaturedProducts() async {
    if (!_isFirebaseAvailable || _firestore == null) {
      setState(() {
        _isLoadingFeatured = false;
      });
      return;
    }

    setState(() {
      _isLoadingFeatured = true;
    });

    try {
      // Query products collection, order by adBoost in descending order, limit to 10
      final QuerySnapshot snapshot =
          await _firestore
              .collection('products')
              .orderBy('adBoost', descending: true)
              .limit(10)
              .get();

      // Convert the documents to Product objects
      final List<Product> products =
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Product.fromFirestore(data, doc.id);
          }).toList();

      setState(() {
        _featuredProducts = products;
        _isLoadingFeatured = false;
      });
    } catch (e) {
      // Log error fetching featured products
      debugPrint('Error fetching featured products: $e');
      setState(() {
        _isLoadingFeatured = false;
      });
    }
  }

  // Fetch recently added products
  Future<void> _fetchRecentProducts() async {
    if (!_isFirebaseAvailable || _firestore == null) {
      setState(() {
        _isLoadingRecent = false;
      });
      return;
    }

    setState(() {
      _isLoadingRecent = true;
    });

    try {
      // Query products collection, order by listedDate timestamp in descending order (newest first), limit to 5
      final QuerySnapshot snapshot =
          await _firestore
              .collection('products')
              .orderBy(
                'listedDate',
                descending: true,
              ) // Using the listedDate timestamp to sort by newest first
              .limit(5)
              .get();

      // Convert the documents to Product objects
      final List<Product> products =
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Product.fromFirestore(data, doc.id);
          }).toList();

      setState(() {
        _recentProducts = products;
        _isLoadingRecent = false;
      });
    } catch (e) {
      // Log error fetching recent products
      debugPrint('Error fetching recent products: $e');
      setState(() {
        _isLoadingRecent = false;
      });
    }
  }

  // Sample categories
  final List<Category> _categories = [
    Category(name: 'Electronics', icon: Icons.devices),
    Category(name: 'Furniture', icon: Icons.chair),
    Category(name: 'Clothing', icon: Icons.checkroom),
    Category(name: 'Books', icon: Icons.book),
    Category(name: 'Sports', icon: Icons.sports_soccer),
    Category(name: 'Toys', icon: Icons.toys),
    Category(name: 'Home', icon: Icons.home),
    Category(name: 'Vehicles', icon: Icons.directions_car),
    Category(name: 'Others', icon: Icons.more_horiz),
  ];

  void _onItemTapped(int index) {
    // Only update the index if we're staying on this page
    if (index == 0) {
      setState(() {
        _selectedIndex = index;
      });
    } else if (index == 1) {
      // Navigate to My Purchases page
      Navigator.push(context, DarkPageRoute(page: const MyPurchasesPage()));
    } else if (index == 2) {
      // Navigate to My Wallet page
      Navigator.push(context, DarkPageRoute(page: const MyWalletPage()));
    } else if (index == 3) {
      // Navigate to My Profile page
      Navigator.push(context, DarkPageRoute(page: const MyProfilePage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: AppColors.deepSlateGray,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.deepSlateGray,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.mutedTeal.withAlpha(100)),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: AppColors.coolGray), // Make text visible
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              hintText: 'Search for items...',
              hintStyle: TextStyle(color: AppColors.coolGray.withAlpha(128)),
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: AppColors.mutedTeal),
                onPressed: () {
                  if (_searchController.text.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => SearchResultsPage(
                              searchQuery: _searchController.text,
                            ),
                      ),
                    );
                  }
                },
              ),
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SearchResultsPage(searchQuery: value),
                  ),
                );
              }
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.message_outlined, color: AppColors.coolGray),
            onPressed: () {
              // Navigate to messages page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MessagesPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Categories
              Text(
                'Categories',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.coolGray,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        // Navigate to the category page when a category is tapped
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => CategoryPage(
                                  categoryName: _categories[index].name,
                                ),
                          ),
                        );
                      },
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: AppColors.deepSlateGray,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.mutedTeal.withAlpha(100),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _categories[index].icon,
                              color: AppColors.mutedTeal,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _categories[index].name,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.coolGray,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Featured items (products with highest ad boost)
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Featured Items',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.coolGray,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to all featured items
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FeaturedItemsPage(),
                        ),
                      );
                    },
                    child: Text(
                      'See All',
                      style: TextStyle(
                        color: AppColors.mutedTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child:
                    !_isFirebaseAvailable
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_off,
                                size: 48,
                                color: AppColors.coolGray.withAlpha(150),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Firebase connection unavailable',
                                style: TextStyle(color: AppColors.coolGray),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sample data is displayed',
                                style: TextStyle(
                                  color: AppColors.coolGray.withAlpha(150),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                        : _isLoadingFeatured
                        ? const Center(child: CircularProgressIndicator())
                        : _featuredProducts.isEmpty
                        ? Center(
                          child: Text(
                            'No featured products available',
                            style: TextStyle(color: AppColors.coolGray),
                          ),
                        )
                        : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _featuredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _featuredProducts[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ProductDetailsPage(
                                          product: product,
                                        ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 180,
                                margin: const EdgeInsets.only(right: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.deepSlateGray,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(50),
                                      blurRadius: 5,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                          ),
                                          child: ImageUtils.base64ToImage(
                                            product.imageUrl,
                                            height: 120,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorWidget: Container(
                                              height: 120,
                                              width: double.infinity,
                                              color: Colors.grey[800],
                                              child: const Icon(
                                                Icons.image_not_supported,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Ad boost badge
                                        if (product.adBoost > 0)
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withAlpha(
                                                  230,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Featured',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: AppColors.coolGray,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            product.description,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.coolGray
                                                  .withAlpha(179),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'RM ${product.price.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: AppColors.mutedTeal,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
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
              ),

              // Recently added
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recently Added',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.coolGray,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to all recent items
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RecentItemsPage(),
                        ),
                      );
                    },
                    child: Text(
                      'See All',
                      style: TextStyle(
                        color: AppColors.mutedTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              !_isFirebaseAvailable
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            size: 32,
                            color: AppColors.coolGray.withAlpha(150),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Firebase connection unavailable',
                            style: TextStyle(color: AppColors.coolGray),
                          ),
                        ],
                      ),
                    ),
                  )
                  : _isLoadingRecent
                  ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                  : _recentProducts.isEmpty
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No recent products available',
                        style: TextStyle(color: AppColors.coolGray),
                      ),
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount:
                        _recentProducts.length > 3
                            ? 3
                            : _recentProducts.length, // Show only 3 items max
                    itemBuilder: (context, index) {
                      final product = _recentProducts[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      ProductDetailsPage(product: product),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.deepSlateGray,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(50),
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                                child: ImageUtils.base64ToImage(
                                  product.imageUrl,
                                  height: 100,
                                  width: 100,
                                  fit: BoxFit.cover,
                                  errorWidget: Container(
                                    height: 100,
                                    width: 100,
                                    color: Colors.grey[800],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.coolGray,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        product.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.coolGray.withAlpha(
                                            179,
                                          ),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'RM ${product.price.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: AppColors.mutedTeal,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ],
          ),
        ),
      ),
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
