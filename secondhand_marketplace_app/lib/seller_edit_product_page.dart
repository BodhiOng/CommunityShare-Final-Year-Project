import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'constants.dart';
import 'utils/image_converter.dart';
import 'utils/image_utils.dart';
import 'models/product.dart';

class EditProductPage extends StatefulWidget {
  final Product product;
  
  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  
  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _minBargainPriceController;
  late TextEditingController _adBoostController;
  
  late String _selectedCategory;
  late String _selectedCondition;
  File? _imageFile;
  bool _isLoading = false;
  String? _errorMessage;
  bool _imageChanged = false;
  String _originalImageUrl = '';
  
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
  void initState() {
    super.initState();
    // Initialize controllers with existing product data
    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController = TextEditingController(text: widget.product.description);
    _priceController = TextEditingController(text: widget.product.price.toString());
    _stockController = TextEditingController(text: widget.product.stock.toString());
    _minBargainPriceController = TextEditingController(
      text: widget.product.minBargainPrice?.toString() ?? ''
    );
    _adBoostController = TextEditingController(
      text: widget.product.adBoost > 0 ? widget.product.adBoost.toString() : ''
    );
    
    // Make sure the category is one of the available options
    _selectedCategory = _categories.contains(widget.product.category) 
        ? widget.product.category 
        : 'others';
        
    // Make sure the condition is one of the available options
    _selectedCondition = _conditions.contains(widget.product.condition)
        ? widget.product.condition
        : 'Good';
        
    _originalImageUrl = widget.product.imageUrl;
  }

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
  
  // Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _imageChanged = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }
  
  // Convert image to base64 or use existing image
  Future<String> _processImage() async {
    if (_imageChanged && _imageFile != null) {
      // Convert new image file to base64
      return await ImageConverter.fileToBase64(_imageFile!);
    } else {
      // Use existing image URL
      return _originalImageUrl;
    }
  }
  
  // Submit the form to update product
  Future<void> _updateProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        final String? sellerId = _auth.currentUser?.uid;
        if (sellerId == null) {
          throw Exception('User not authenticated');
        }
        
        // Verify this is the seller's product
        if (widget.product.sellerId != sellerId) {
          throw Exception('You can only edit your own products');
        }
        
        // Process image
        final String imageSource = await _processImage();
        
        // Create updated product data
        final Map<String, dynamic> updatedData = {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': double.parse(_priceController.text.trim()),
          'imageUrl': imageSource,
          'category': _selectedCategory,
          'condition': _selectedCondition,
          'stock': int.parse(_stockController.text.trim()),
          'adBoost': _adBoostController.text.isEmpty 
              ? 0.0 
              : double.parse(_adBoostController.text.trim()),
          'minBargainPrice': _minBargainPriceController.text.isEmpty 
              ? double.parse(_priceController.text.trim()) 
              : double.parse(_minBargainPriceController.text.trim()),
          // Don't update these fields:
          // 'sellerId': preserved from original
          // 'listedDate': preserved from original
        };
        
        // Update in Firestore
        await _firestore.collection('products').doc(widget.product.id).update(updatedData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Product updated successfully'),
              backgroundColor: AppColors.mutedTeal,
            ),
          );
          
          // Navigate back with success result
          Navigator.pop(context, true);
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error updating product: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        title: const Text(
          'Edit Product',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.deepSlateGray,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.mutedTeal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error message if any
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      
                    // Product Image
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: AppColors.deepSlateGray,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: AppColors.coolGray.withValues(alpha: 0.3),
                              ),
                            ),
                            child: _imageFile != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.file(
                                      _imageFile!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : _originalImageUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8.0),
                                        child: ImageUtils.isBase64Image(_originalImageUrl)
                                            ? ImageUtils.base64ToImage(
                                                _originalImageUrl,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.network(
                                                _originalImageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return const Center(
                                                    child: Icon(
                                                      Icons.image_not_supported,
                                                      color: Colors.white54,
                                                      size: 40,
                                                    ),
                                                  );
                                                },
                                              ),
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.add_photo_alternate,
                                          color: Colors.white54,
                                          size: 40,
                                        ),
                                      ),
                          ),
                          const SizedBox(height: 16.0),
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Change Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.deepSlateGray,
                              foregroundColor: AppColors.coolGray,
                              side: BorderSide(
                                color: AppColors.coolGray.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    
                    // Product Name
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Product Name',
                        labelStyle: TextStyle(color: AppColors.coolGray),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppColors.coolGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppColors.mutedTeal),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Product Description
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(color: AppColors.coolGray),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppColors.coolGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppColors.mutedTeal),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Price
                    TextFormField(
                      controller: _priceController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Price',
                        labelStyle: TextStyle(color: AppColors.coolGray),
                        prefixText: 'RM ',
                        prefixStyle: const TextStyle(color: Colors.white),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppColors.coolGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppColors.mutedTeal),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        final price = double.tryParse(value);
                        if (price == null) {
                          return 'Invalid price';
                        }
                        if (price <= 0) {
                          return 'Must be greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Stock
                    TextFormField(
                      controller: _stockController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Stock',
                        labelStyle: TextStyle(color: AppColors.coolGray),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppColors.coolGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppColors.mutedTeal),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        final stock = int.tryParse(value);
                        if (stock == null) {
                          return 'Invalid';
                        }
                        if (stock <= 0) {
                          return 'Must be at least 1';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Category and Condition in a row
                    Row(
                      children: [
                        // Category dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            dropdownColor: AppColors.deepSlateGray,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Category',
                              labelStyle: TextStyle(color: AppColors.coolGray),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: BorderSide(color: AppColors.coolGray),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: BorderSide(color: AppColors.mutedTeal),
                              ),
                            ),
                            items: _categories.map((category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(
                                  category[0].toUpperCase() + category.substring(1),
                                  style: const TextStyle(color: Colors.white),
                                ),
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
                        ),
                        const SizedBox(width: 16.0),
                        
                        // Condition dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCondition,
                            dropdownColor: AppColors.deepSlateGray,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Condition',
                              labelStyle: TextStyle(color: AppColors.coolGray),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: BorderSide(color: AppColors.coolGray),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: BorderSide(color: AppColors.mutedTeal),
                              ),
                            ),
                            items: _conditions.map((condition) {
                              return DropdownMenuItem<String>(
                                value: condition,
                                child: Text(
                                  condition,
                                  style: const TextStyle(color: Colors.white),
                                ),
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Min Bargain Price (Optional)
                    TextFormField(
                      controller: _minBargainPriceController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Minimum Bargain Price (Optional)',
                        labelStyle: TextStyle(color: AppColors.coolGray),
                        prefixText: 'RM ',
                        prefixStyle: const TextStyle(color: Colors.white),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppColors.coolGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppColors.mutedTeal),
                        ),
                        helperText: 'Lowest price you\'re willing to accept for bargaining',
                        helperStyle: TextStyle(color: AppColors.coolGray.withValues(alpha: 0.7)),
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
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Ad Boost Budget (Optional)',
                        labelStyle: TextStyle(color: AppColors.coolGray),
                        prefixText: 'RM ',
                        prefixStyle: const TextStyle(color: Colors.white),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppColors.coolGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppColors.mutedTeal),
                        ),
                        helperText: 'Amount to spend on promoting this listing',
                        helperStyle: TextStyle(color: AppColors.coolGray.withValues(alpha: 0.7)),
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
                    
                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _updateProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mutedTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text(
                          'Update Product',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
