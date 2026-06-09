import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondhand_marketplace_app/utils/image_utils.dart';
import 'constants.dart';
import 'buyer_product_details_page.dart';
import 'models/product.dart';

class SearchResultsPage extends StatefulWidget {
  final String searchQuery;

  const SearchResultsPage({super.key, required this.searchQuery});

  @override
  SearchResultsPageState createState() => SearchResultsPageState();
}

class SearchResultsPageState extends State<SearchResultsPage> {
  final TextEditingController _searchController = TextEditingController();
  RangeValues _priceRange = const RangeValues(0, 10000);
  String _selectedCondition = 'All Conditions';
  bool _showFilterOptions = false;

  // Try to get Firestore instance, but handle the case where Firebase isn't initialized
  late final FirebaseFirestore? _firestore;

  // Flag to track if Firebase is available
  bool _isFirebaseAvailable = true;
  List<Product> _searchResults = [];
  bool _isLoading = true;
  
  // Map to store calculated ratings from reviews collection
  final Map<String, double> _calculatedRatings = {};

  // Sample conditions
  final List<String> _conditions = [
    'All Conditions',
    'New',
    'Like New',
    'Good',
    'Fair',
    'Poor',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;

    // Initialize Firestore and check if it's available
    try {
      _firestore = FirebaseFirestore.instance;
      _performSearch();
    } catch (e) {
      debugPrint('Error accessing Firestore: $e');
      setState(() {
        _isFirebaseAvailable = false;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Perform search using Firestore
  Future<void> _performSearch() async {
    if (!_isFirebaseAvailable || _firestore == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String query = _searchController.text.toLowerCase();

      // Get all products (or a reasonable subset)
      final QuerySnapshot allProducts =
          await _firestore
              .collection('products')
              .limit(100) // Limit to prevent performance issues
              .get();

      final List<Product> products = [];

      for (final doc in allProducts.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final id = doc.id;
        final product = Product.fromFirestore(data, id);

        // Client-side filtering for partial matches
        if (product.name.toLowerCase().contains(query) ||
            product.description.toLowerCase().contains(query) ||
            product.category.toLowerCase().contains(query)) {
          products.add(product);
        }
      }

      // Fetch ratings for each product from reviews collection
      for (var product in products) {
        await _fetchProductRating(product);
      }

      // Sort by listedDate, newest first
      products.sort((a, b) {
        return b.listedDate.compareTo(a.listedDate); // Newest first
      });

      setState(() {
        _searchResults = products;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error searching products: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fetch and calculate average rating for a product from reviews collection
  Future<void> _fetchProductRating(Product product) async {
    try {
      final QuerySnapshot reviewsSnapshot = await _firestore!
          .collection('reviews')
          .where('productId', isEqualTo: product.id)
          .get();
      
      if (reviewsSnapshot.docs.isNotEmpty) {
        double totalRating = 0;
        for (var doc in reviewsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('rating')) {
            totalRating += (data['rating'] as num).toDouble();
          }
        }
        
        // Calculate average rating
        double averageRating = totalRating / reviewsSnapshot.docs.length;
        // Store calculated rating in the map
        _calculatedRatings[product.id] = double.parse(averageRating.toStringAsFixed(1));
      }
    } catch (e) {
      debugPrint('Error fetching ratings for product ${product.id}: $e');
      // Keep the default rating from the product document if there's an error
    }
  }

  // Filter the search results based on selected filters
  List<Product> get filteredResults {
    return _searchResults.where((product) {
      // Price filter
      final bool priceMatch =
          product.price >= _priceRange.start &&
          product.price <= _priceRange.end;

      // Condition filter
      final bool conditionMatch =
          _selectedCondition == 'All Conditions' ||
          product.condition == _selectedCondition;

      return priceMatch && conditionMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: AppColors.deepSlateGray,
        foregroundColor: AppColors.coolGray,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.coolGray),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: AppColors.mutedTeal,
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  hintStyle: TextStyle(
                    color: AppColors.coolGray.withAlpha(179),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.deepSlateGray,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: AppColors.coolGray),
                    onPressed: () {
                      // Implement search functionality
                      setState(() {});
                    },
                  ),
                ),
                onSubmitted: (value) {
                  // Implement search functionality
                  setState(() {});
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.filter_list, color: AppColors.coolGray),
              onPressed: () {
                setState(() {
                  _showFilterOptions = !_showFilterOptions;
                });
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter options
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _showFilterOptions ? 280 : 0,
            color: AppColors.deepSlateGray,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.coolGray,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Price Range Slider
                    Text(
                      'Price Range',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.coolGray,
                      ),
                    ),
                    RangeSlider(
                      values: _priceRange,
                      min: 0,
                      max: 10000,
                      activeColor: AppColors.mutedTeal,
                      inactiveColor: AppColors.coolGray.withAlpha(77),
                      labels: RangeLabels(
                        'RM ${_priceRange.start.round()}',
                        'RM ${_priceRange.end.round()}',
                      ),
                      onChanged: (RangeValues values) {
                        setState(() {
                          _priceRange = values;
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RM ${_priceRange.start.round()}',
                          style: TextStyle(color: AppColors.coolGray),
                        ),
                        Text(
                          'RM ${_priceRange.end.round()}',
                          style: TextStyle(color: AppColors.coolGray),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Item Condition Dropdown
                    Text(
                      'Item Condition',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.coolGray,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.deepSlateGray,
                        border: Border.all(
                          color: AppColors.mutedTeal.withAlpha(77),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedCondition,
                        underline: Container(),
                        dropdownColor: AppColors.deepSlateGray,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.coolGray,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCondition = newValue;
                            });
                          }
                        },
                        items:
                            _conditions.map<DropdownMenuItem<String>>((
                              String value,
                            ) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: TextStyle(color: AppColors.coolGray),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search results
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.mutedTeal,
                      ),
                    )
                    : filteredResults.isEmpty
                    ? Center(
                      child: Text(
                        'No results found',
                        style: TextStyle(color: AppColors.coolGray),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: filteredResults.length,
                      itemBuilder: (context, index) {
                        final product = filteredResults[index];
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
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            color: AppColors.deepSlateGray,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: ImageUtils.base64ToImage(
                                      product.imageUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Product details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Product name with more space
                                        Text(
                                          product.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.coolGray,
                                            fontSize: 16,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        // Rating and condition
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.star,
                                              size: 16,
                                              color: Colors.amber[700],
                                            ),
                                            Text(
                                              ' ${_calculatedRatings.containsKey(product.id) ? _calculatedRatings[product.id]!.toString() : product.rating.toString()} \u2022 ',
                                              style: TextStyle(
                                                color: AppColors.coolGray,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                product.condition,
                                                style: TextStyle(
                                                  color: AppColors.coolGray,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Price in its own row
                                        Text(
                                          'RM ${product.price.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.mutedTeal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
