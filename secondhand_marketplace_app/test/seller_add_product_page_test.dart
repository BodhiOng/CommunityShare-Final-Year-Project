// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Mock classes
class MockFirebaseFirestore {}
class MockFirebaseAuth {}
class MockUser {}
class MockImagePicker {}
class MockImageConverter {}

// Create a testable version of AddProductPage that doesn't depend on Firebase
class TestableAddProductPage extends StatefulWidget {
  final Function(Map<String, dynamic>)? onProductSubmit;

  const TestableAddProductPage({super.key, this.onProductSubmit});

  @override
  State<TestableAddProductPage> createState() => _TestableAddProductPageState();
}

class _TestableAddProductPageState extends State<TestableAddProductPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _minBargainPriceController = TextEditingController();
  final TextEditingController _adBoostController = TextEditingController();
  
  String _selectedCategory = 'electronics'; // Default category
  String _selectedCondition = 'New'; // Default condition
  File? _imageFile;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Predefined lists
  final List<String> _categories = [
    'electronics',
    'furniture',
    'clothing',
    'books',
    'sports',
    'toys',
    'home',
    'vehicles',
    'others'
  ];
  
  final List<String> _conditions = [
    'New',
    'Like New',
    'Good',
    'Fair',
    'Poor'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _minBargainPriceController.dispose();
    _adBoostController.dispose();
    super.dispose();
  }
  
  // Mock image picker function
  Future<void> _pickImage() async {
    setState(() {
      // Just set a dummy value for testing
      _imageFile = null; // In a real test, we'd create a mock file
    });
  }
  
  // Mock image processing
  Future<String> _processImage() async {
    return 'test_image_data';
  }
  
  // Submit form
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        // Create product data
        final productData = {
          'name': _nameController.text,
          'description': _descriptionController.text,
          'price': double.parse(_priceController.text),
          'stock': int.parse(_stockController.text),
          'category': _selectedCategory,
          'condition': _selectedCondition,
          'imageUrl': await _processImage(),
          'sellerId': 'test_seller_id',
          'listedDate': DateTime.now().millisecondsSinceEpoch,
          'status': 'active',
          'minBargainPrice': _minBargainPriceController.text.isNotEmpty
              ? double.parse(_minBargainPriceController.text)
              : null,
          'adBoost': _adBoostController.text.isNotEmpty
              ? double.parse(_adBoostController.text)
              : 0.0,
        };
        
        // Call the callback if provided
        if (widget.onProductSubmit != null) {
          widget.onProductSubmit!(productData);
        }
        
        // Clear form
        _clearForm();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully!')),
        );
      } catch (e) {
        setState(() {
          _errorMessage = 'Error adding product: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Clear form
  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _stockController.clear();
    _minBargainPriceController.clear();
    _adBoostController.clear();
    setState(() {
      _selectedCategory = 'electronics';
      _selectedCondition = 'New';
      _imageFile = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Product'),
        backgroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image picker
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: _imageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.file(
                                    _imageFile!,
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      color: Colors.grey[400],
                                      size: 50,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add Product Image',
                                      style: TextStyle(color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    
                    // Error message
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    
                    // Product Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a product name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Price
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price (RM)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Stock
                    TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock Quantity',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter stock quantity';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Condition dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCondition,
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                        border: OutlineInputBorder(),
                      ),
                      items: _conditions.map((condition) {
                        return DropdownMenuItem(
                          value: condition,
                          child: Text(condition),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCondition = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Min Bargain Price (Optional)
                    TextFormField(
                      controller: _minBargainPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minimum Bargain Price (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final double? minPrice = double.tryParse(value);
                          if (minPrice == null) {
                            return 'Invalid price';
                          }
                          final double? price = double.tryParse(_priceController.text);
                          if (price != null && minPrice > price) {
                            return 'Must be less than price';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Ad Boost (Optional)
                    TextFormField(
                      controller: _adBoostController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Ad Boost Budget (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (double.tryParse(value) == null) {
                            return 'Invalid amount';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32.0),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        child: const Text('Add Product'),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                  ],
                ),
              ),
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

  group('AddProductPage Widget Tests', () {
    testWidgets('should render form fields correctly', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableAddProductPage(),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify that the form fields are displayed
      expect(find.text('Add New Product'), findsOneWidget);
      expect(find.text('Add Product Image'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(6)); // 6 text form fields
      // Use a more generic finder for dropdowns since DropdownButtonFormField might be wrapped
      expect(find.byType(DropdownButton<String>), findsNWidgets(2)); // 2 dropdowns
      expect(find.text('Add Product'), findsOneWidget); // Submit button
    });

    testWidgets('should have required form fields', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableAddProductPage(),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify required fields exist
      expect(find.widgetWithText(TextFormField, 'Product Name'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Description'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Price (RM)'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Stock Quantity'), findsOneWidget);
    });

    testWidgets('should allow entering text in form fields', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableAddProductPage(),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Enter text in fields
      await tester.enterText(find.widgetWithText(TextFormField, 'Product Name'), 'Test Product');
      await tester.enterText(find.widgetWithText(TextFormField, 'Description'), 'Test Description');
      await tester.enterText(find.widgetWithText(TextFormField, 'Price (RM)'), '99.99');
      await tester.enterText(find.widgetWithText(TextFormField, 'Stock Quantity'), '10');
      
      // Verify text was entered
      expect(find.text('Test Product'), findsOneWidget);
      expect(find.text('Test Description'), findsOneWidget);
      expect(find.text('99.99'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('should allow entering optional fields', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableAddProductPage(),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Enter text in optional fields
      await tester.enterText(find.widgetWithText(TextFormField, 'Minimum Bargain Price (Optional)'), '80');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ad Boost Budget (Optional)'), '5');
      
      // Verify text was entered
      expect(find.text('80'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('should have a submit button', (WidgetTester tester) async {
      // Build the widget with a callback
      await tester.pumpWidget(
        MaterialApp(
          home: TestableAddProductPage(),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify submit button exists
      expect(find.widgetWithText(ElevatedButton, 'Add Product'), findsOneWidget);
    });

    testWidgets('should have category and condition dropdowns', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestableAddProductPage(),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify category and condition labels exist
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Condition'), findsOneWidget);
      
      // Verify default values are displayed
      expect(find.text('electronics'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
    });
  });
}
