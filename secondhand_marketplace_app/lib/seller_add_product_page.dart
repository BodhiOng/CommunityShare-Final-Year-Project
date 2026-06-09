import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'constants.dart';
import 'utils/image_converter.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  
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
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }
  
  // Convert image to base64 or use placeholder
  Future<String> _processImage() async {
    if (_imageFile != null) {
      // Convert image file to base64
      return await ImageConverter.fileToBase64(_imageFile!);
    } else {
      // Use placeholder image URL
      return 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAIjAiMDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD2zzP9lP8AvmjzP9lP++aZRQA/zP8AZT/vmjzP9lP++aZRQA/zP9lP++aPM/2U/wC+aZRQA/zP9lP++aPM/wBlP++aZRQA/wAz/ZT/AL5o8z/ZT/vmmUUAP8z/AGU/75o8z/ZT/vmmUUAP8z/ZT/vmjzP9lP8AvmmUUAP8z/ZT/vmjzP8AZT/vmmUUAP8AM/2U/wC+aPM/2U/75plFAD/M/wBlP++aPM/2U/75plFAD/M/2U/75o8z/ZT/AL5plFAD/M/2U/75o8z/AGU/75plFAD/ADP9lP8AvmjzP9lP++aZRQA/zP8AZT/vmjzP9lP++aZRQA/zP9lP++aPM/2U/wC+aZRQA/zP9lP++aPM/wBlP++aZRQA/wAz/ZT/AL5o8z/ZT/vmmUUAP8z/AGU/75o8z/ZT/vmmUUAP8z/ZT/vmjzP9lP8AvmmUUAP8z/ZT/vmjzP8AZT/vmmUUAP8AM/2U/wC+aPM/2U/75plFAD/M/wBlP++aPM/2U/75plFAD/M/2U/75o8z/ZT/AL5plFAD/M/2U/75o8z/AGU/75plFAD/ADP9lP8AvmjzP9lP++aZRQA/zP8AZT/vmjzP9lP++aZRQA/zP9lP++aPM/2U/wC+aZRQA/zP9lP++aPM/wBlP++aZRQA/wAz/ZT/AL5o8z/ZT/vmmUUAP8z/AGU/75o8z/ZT/vmmUUAP8z/ZT/vmjzP9lP8AvmmUUAP8z/ZT/vmjzP8AZT/vmmUUAP8AM/2U/wC+aPM/2U/75plFAD/M/wBlP++aPM/2U/75plFAD/M/2U/75oplFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUU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RQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAP81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKPNf1H5CiigA81/UfkKKKKAP//Z';
    }
  }
  
  // Submit the form
  Future<void> _submitForm() async {
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
        
        // Process image
        final String imageSource = await _processImage();
        
        // Generate a unique product ID
        final String productId = '${_selectedCategory}_${DateTime.now().millisecondsSinceEpoch}';
        
        // Create product data
        final Map<String, dynamic> productData = {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': double.parse(_priceController.text.trim()),
          'imageUrl': imageSource,
          'category': _selectedCategory,
          'sellerId': sellerId,
          'condition': _selectedCondition,
          'listedDate': Timestamp.now(),
          'stock': int.parse(_stockController.text.trim()),
          'adBoost': _adBoostController.text.isEmpty 
              ? 0.0 
              : double.parse(_adBoostController.text.trim()),
          'minBargainPrice': _minBargainPriceController.text.isEmpty 
              ? double.parse(_priceController.text.trim()) 
              : double.parse(_minBargainPriceController.text.trim()),
        };
        
        // Add to Firestore
        await _firestore.collection('products').doc(productId).set(productData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Product added successfully'),
              backgroundColor: AppColors.mutedTeal,
            ),
          );
          
          // Clear form after successful submission
          _clearForm();
          
          // Navigate back
          Navigator.pop(context, true);
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error adding product: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  // Clear form fields
  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _stockController.clear();
    _minBargainPriceController.clear();
    _adBoostController.clear();
    setState(() {
      _imageFile = null;
      _selectedCategory = 'clothing';
      _selectedCondition = 'New';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        title: const Text(
          'Add New Product',
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
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        margin: const EdgeInsets.only(bottom: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(25),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Product Image
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: AppColors.deepSlateGray,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: AppColors.mutedTeal,
                              width: 1.0,
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
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.add_photo_alternate,
                                      color: AppColors.mutedTeal,
                                      size: 50,
                                    ),
                                    const SizedBox(height: 8.0),
                                    const Text(
                                      'Add Product Image',
                                      style: TextStyle(
                                        color: AppColors.coolGray,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
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
                          return 'Please enter a product name';
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
                          return 'Please enter a product description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Price and Stock in a row
                    Row(
                      children: [
                        // Price
                        Expanded(
                          child: TextFormField(
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
                              if (double.tryParse(value) == null) {
                                return 'Invalid price';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        // Stock
                        Expanded(
                          child: TextFormField(
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
                        ),
                      ],
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
                            items: _categories.map((String category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(
                                  category[0].toUpperCase() + category.substring(1),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedCategory = newValue;
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
                            items: _conditions.map((String condition) {
                              return DropdownMenuItem<String>(
                                value: condition,
                                child: Text(
                                  condition,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedCondition = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Minimum Bargain Price (Optional)
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
                        helperStyle: TextStyle(color: AppColors.coolGray.withAlpha(179)),
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
                        helperStyle: TextStyle(color: AppColors.coolGray.withAlpha(179)),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mutedTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text(
                          'Add Product',
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
