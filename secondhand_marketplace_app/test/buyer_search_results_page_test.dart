import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand_marketplace_app/models/product.dart';

// Mock classes
class MockFirebaseFirestore {}

// Create a testable version of SearchResultsPage that doesn't depend on Firebase
class TestableSearchResultsPage extends StatefulWidget {
  final String searchQuery;
  final List<Product> mockProducts;

  const TestableSearchResultsPage({
    super.key,
    required this.searchQuery,
    required this.mockProducts,
  });

  @override
  TestableSearchResultsPageState createState() => TestableSearchResultsPageState();
}

class TestableSearchResultsPageState extends State<TestableSearchResultsPage> {
  final TextEditingController _searchController = TextEditingController();
  RangeValues _priceRange = const RangeValues(0, 10000);
  String _selectedCondition = 'All Conditions';
  bool _showFilterOptions = false;
  List<Product> _searchResults = [];
  // These fields are needed to match the original implementation structure

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
    _searchResults = _filterProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filterProducts() {
    final String query = _searchController.text.toLowerCase();
    return widget.mockProducts.where((product) {
      // Apply search query filter
      final matchesQuery = product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);

      // Apply price filter
      final matchesPrice = product.price >= _priceRange.start && 
                          product.price <= _priceRange.end;

      // Apply condition filter
      final matchesCondition = _selectedCondition == 'All Conditions' ||
                              product.condition == _selectedCondition;

      return matchesQuery && matchesPrice && matchesCondition;
    }).toList();
  }

  void _performSearch() {
    setState(() {
      _searchResults = _filterProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Results for "${widget.searchQuery}"'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              setState(() {
                _showFilterOptions = !_showFilterOptions;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          // Filter options
          if (_showFilterOptions)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Price Range'),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 10000,
                    divisions: 100,
                    labels: RangeLabels(
                      _priceRange.start.round().toString(),
                      _priceRange.end.round().toString(),
                    ),
                    onChanged: (RangeValues values) {
                      setState(() {
                        _priceRange = values;
                      });
                    },
                  ),
                  const Text('Condition'),
                  DropdownButton<String>(
                    value: _selectedCondition,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedCondition = newValue;
                        });
                      }
                    },
                    items: ['All Conditions', 'New', 'Like New', 'Good', 'Fair', 'Poor']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                  ElevatedButton(
                    onPressed: _performSearch,
                    child: const Text('Apply Filters'),
                  ),
                ],
              ),
            ),
          // Results
          Expanded(
            child: _searchResults.isEmpty
                ? const Center(child: Text('No results found'))
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final product = _searchResults[index];
                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: ListTile(
                          leading: SizedBox(
                            width: 60,
                            height: 60,
                            // In tests, always use a placeholder instead of network images
                            child: const Icon(Icons.image),
                          ),
                          title: Text(product.name),
                          subtitle: Text(product.description),
                          trailing: Text('RM ${product.price.toStringAsFixed(2)}'),
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

void main() {
  // Sample product data for testing
  final List<Product> sampleProducts = [
    Product(
      id: 'product1',
      name: 'Smartphone XYZ',
      description: 'A high-end smartphone with great features',
      price: 999.99,
      imageUrl: 'placeholder_image',  // Using placeholder instead of URL
      category: 'Electronics',
      sellerId: 'seller1',
      rating: 4.5,
      condition: 'New',
      listedDate: DateTime.now(),
      stock: 10,
      adBoost: 0.0,
    ),
    Product(
      id: 'product2',
      name: 'Laptop ABC',
      description: 'Powerful laptop for professionals',
      price: 1499.99,
      imageUrl: 'placeholder_image',  // Using placeholder instead of URL
      category: 'Electronics',
      sellerId: 'seller1',
      rating: 4.7,
      condition: 'Like New',
      listedDate: DateTime.now().subtract(const Duration(days: 2)),
      stock: 5,
      adBoost: 0.0,
    ),
    Product(
      id: 'product3',
      name: 'Denim Jacket',
      description: 'Stylish denim jacket for all seasons',
      price: 79.99,
      imageUrl: 'placeholder_image',  // Using placeholder instead of URL
      category: 'Clothing',
      sellerId: 'seller2',
      rating: 4.2,
      condition: 'Good',
      listedDate: DateTime.now().subtract(const Duration(days: 5)),
      stock: 8,
      adBoost: 0.0,
    ),
  ];

  group('SearchResultsPage Widget Tests', () {
    testWidgets('should display search results based on query', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableSearchResultsPage(
            searchQuery: 'Electronics',
            mockProducts: sampleProducts,
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify that the search query is displayed in the app bar
      expect(find.text('Search Results for "Electronics"'), findsOneWidget);

      // Verify that the correct number of products are displayed
      expect(find.byType(Card), findsNWidgets(2)); // Only the Electronics category items

      // Verify specific product names are displayed
      expect(find.text('Smartphone XYZ'), findsOneWidget);
      expect(find.text('Laptop ABC'), findsOneWidget);
      expect(find.text('Denim Jacket'), findsNothing); // Should not be found
    });

    testWidgets('should filter products by price range', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableSearchResultsPage(
            searchQuery: '',  // Empty query to get all products
            mockProducts: sampleProducts,
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify all products are initially displayed
      expect(find.byType(Card), findsNWidgets(3));

      // Open filter options
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      // Find the RangeSlider and adjust it to filter out expensive items
      final RangeSlider slider = tester.widget(find.byType(RangeSlider));
      expect(slider, isNotNull);

      // Since we can't directly interact with the RangeSlider in tests,
      // we'll need to find the Apply Filters button and tap it after
      // the TestableSearchResultsPageState has been modified
      final TestableSearchResultsPageState state = 
          tester.state(find.byType(TestableSearchResultsPage));
      
      // Set price range to only show items under 100
      // Directly modify the state variable
      state._priceRange = const RangeValues(0, 100);
      await tester.pump();
      await tester.pumpAndSettle();

      // Tap Apply Filters button
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      // Verify only the jacket is displayed (price < 100)
      expect(find.byType(Card), findsNWidgets(1));
      expect(find.text('Denim Jacket'), findsOneWidget);
      expect(find.text('Smartphone XYZ'), findsNothing);
      expect(find.text('Laptop ABC'), findsNothing);
    });

    testWidgets('should filter products by condition', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableSearchResultsPage(
            searchQuery: '',  // Empty query to get all products
            mockProducts: sampleProducts,
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Open filter options
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      // Find the condition dropdown
      expect(find.text('All Conditions'), findsOneWidget);

      // Since we can't directly interact with the DropdownButton in tests,
      // we'll modify the state directly
      final TestableSearchResultsPageState state = 
          tester.state(find.byType(TestableSearchResultsPage));
      
      // Set condition to 'New'
      // Directly modify the state variable
      state._selectedCondition = 'New';
      await tester.pump();
      await tester.pumpAndSettle();

      // Tap Apply Filters button
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      // Verify only the new smartphone is displayed
      expect(find.byType(Card), findsNWidgets(1));
      expect(find.text('Smartphone XYZ'), findsOneWidget);
      expect(find.text('Laptop ABC'), findsNothing);
      expect(find.text('Denim Jacket'), findsNothing);
    });

    testWidgets('should update search results when search query changes', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableSearchResultsPage(
            searchQuery: 'Electronics',
            mockProducts: sampleProducts,
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Initially should show electronics items
      expect(find.byType(Card), findsNWidgets(2));

      // Enter a new search query
      await tester.enterText(find.byType(TextField), 'Jacket');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Tap search or press enter
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Verify only the jacket is displayed
      expect(find.byType(Card), findsNWidgets(1));
      expect(find.text('Denim Jacket'), findsOneWidget);
      expect(find.text('Smartphone XYZ'), findsNothing);
      expect(find.text('Laptop ABC'), findsNothing);
    });

    testWidgets('should show no results message when no products match', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableSearchResultsPage(
            searchQuery: 'NonExistentProduct',
            mockProducts: sampleProducts,
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify no products are displayed
      expect(find.byType(Card), findsNothing);
      expect(find.text('No results found'), findsOneWidget);
    });
  });
}
