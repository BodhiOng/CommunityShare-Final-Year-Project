import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'constants.dart';
import 'models/product.dart';
import 'utils/page_transitions.dart';
import 'utils/image_utils.dart';

// Import seller pages
import 'seller_reviews_page.dart';
import 'seller_wallet_page.dart';
import 'seller_profile_page.dart';
import 'seller_add_product_page.dart';
import 'seller_edit_product_page.dart';
import 'seller_messages_page.dart';

class SellerListingPage extends StatefulWidget {
  const SellerListingPage({super.key});

  @override
  State<SellerListingPage> createState() => _SellerListingPageState();
}

class _SellerListingPageState extends State<SellerListingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String? _sellerId;
  int _selectedIndex = 0; // Default to My Listings tab

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _sellerId = _auth.currentUser?.uid;
    _fetchSellerProducts();

    // Add listener for search functionality
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
    super.dispose();
  }

  // Filter products based on search query
  void _filterProducts() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredProducts = List.from(_products);
      } else {
        _filteredProducts =
            _products.where((product) {
              return product.name.toLowerCase().contains(query) ||
                  product.description.toLowerCase().contains(query) ||
                  product.category.toLowerCase().contains(query);
            }).toList();
      }
    });
  }

  // Clear search and reset filtered products
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _filteredProducts = List.from(_products);
    });
  }

  // Fetch products for the current seller
  Future<void> _fetchSellerProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (_sellerId == null) {
        throw Exception('User not authenticated');
      }

      final QuerySnapshot productsSnapshot =
          await _firestore
              .collection('products')
              .where('sellerId', isEqualTo: _sellerId)
              .orderBy('listedDate', descending: true)
              .get();

      final List<Product> fetchedProducts = [];

      for (var doc in productsSnapshot.docs) {
        final productData = doc.data() as Map<String, dynamic>;
        fetchedProducts.add(Product.fromFirestore(productData, doc.id));
      }

      setState(() {
        _products = fetchedProducts;
        _filteredProducts = List.from(fetchedProducts);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching products: $e';
        _isLoading = false;
      });
    }
  }

  // Delete a product
  Future<void> _deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Product deleted successfully'),
            backgroundColor: AppColors.mutedTeal,
          ),
        );
        _fetchSellerProducts(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Handle bottom navigation
  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0: // Already on My Listings
        setState(() {
          _selectedIndex = index;
        });
        break;
      case 1: // Navigate to Reviews
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const SellerReviewsPage()),
        );
        break;
      case 2: // Navigate to Wallet
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const SellerWalletPage()),
        );
        break;
      case 3: // Navigate to Profile
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const SellerMessagesPage()),
        );
        break;
      case 4: // Navigate to Messages
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const SellerProfilePage()),
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
        foregroundColor: AppColors.coolGray,
        title:
            _isSearching
                ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: AppColors.coolGray),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: TextStyle(
                      color: AppColors.coolGray.withValues(alpha: 128),
                    ),
                    border: InputBorder.none,
                  ),
                )
                : const Text('My Listings'),
        actions: [
          // Search icon/close button
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _clearSearch();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navigate to add product page
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddProductPage()),
          );

          // Refresh products if a new product was added
          if (result == true) {
            _fetchSellerProducts();
          }
        },
        backgroundColor: AppColors.mutedTeal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: AppColors.mutedTeal),
              )
              : _errorMessage.isNotEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage,
                      style: TextStyle(color: AppColors.coolGray),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchSellerProducts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mutedTeal,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : _products.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory,
                      size: 64,
                      color: AppColors.coolGray.withValues(alpha: 128),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No products listed yet',
                      style: TextStyle(color: AppColors.coolGray),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _fetchSellerProducts,
                color: AppColors.mutedTeal,
                child:
                    _filteredProducts.isEmpty &&
                            _searchController.text.isNotEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: AppColors.coolGray.withValues(
                                  alpha: 200,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No products match "${_searchController.text}"',
                                style: TextStyle(color: AppColors.coolGray),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _clearSearch,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.mutedTeal,
                                ),
                                child: Text(
                                  'Clear Search',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return _buildProductCard(product);
                          },
                        ),
              ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Listings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_outline),
            label: 'Reviews',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            label: 'Messages',
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

  // Build error widget for image loading
  Widget _buildErrorImage() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.white54, size: 40),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.deepSlateGray,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image and status
          Stack(
            children: [
              // Product image with ImageUtils
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child:
                      product.imageUrl.isNotEmpty
                          ? ImageUtils.isBase64Image(product.imageUrl)
                              ? ImageUtils.base64ToImage(
                                product.imageUrl,
                                fit: BoxFit.cover,
                              )
                              : Image.network(
                                product.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        _buildErrorImage(),
                              )
                          : _buildErrorImage(),
                ),
              ),

              // Stock indicator
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: product.stock > 0 ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.stock > 0
                        ? 'In Stock: ${product.stock}'
                        : 'Out of Stock',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Boost indicator if product is boosted
              if (product.adBoost > 0)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: AppColors.charcoalBlack,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Boosted ${product.adBoost.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: AppColors.charcoalBlack,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Product details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.coolGray,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Price and category
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RM ${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mutedTeal,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.deepSlateGray,
                        border: Border.all(color: AppColors.mutedTeal),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.coolGray,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Min bargain price
                if (product.minBargainPrice != null)
                  Text(
                    'Min. Bargain: RM ${product.minBargainPrice!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.coolGray.withValues(alpha: 179),
                    ),
                  ),
                const SizedBox(height: 8),

                // Condition and listing date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Condition: ${product.condition}',
                      style: TextStyle(fontSize: 14, color: AppColors.coolGray),
                    ),
                    Text(
                      'Listed: ${_formatDate(product.listedDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.coolGray.withValues(alpha: 179),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Edit button
                    OutlinedButton.icon(
                      onPressed: () async {
                        // Navigate to edit product page
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => EditProductPage(product: product),
                          ),
                        );

                        // Refresh products if a product was updated
                        if (result == true) {
                          _fetchSellerProducts();
                        }
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.mutedTeal,
                        side: BorderSide(color: AppColors.mutedTeal),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Delete button
                    OutlinedButton.icon(
                      onPressed: () {
                        // Show confirmation dialog
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                backgroundColor: AppColors.deepSlateGray,
                                title: Text(
                                  'Delete Product',
                                  style: TextStyle(color: AppColors.coolGray),
                                ),
                                content: Text(
                                  'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
                                  style: TextStyle(color: AppColors.coolGray),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: AppColors.coolGray,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteProduct(product.id);
                                    },
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: AppColors.warmCoral,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        );
                      },
                      icon: Icon(
                        Icons.delete,
                        size: 16,
                        color: AppColors.coolGray,
                      ),
                      label: Text(
                        'Delete',
                        style: TextStyle(color: AppColors.coolGray),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warmCoral,
                        side: const BorderSide(color: AppColors.warmCoral),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Format date to a readable string
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 2) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${(difference.inDays / 365).floor()} years ago';
    }
  }
}
