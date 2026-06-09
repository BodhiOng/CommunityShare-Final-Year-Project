import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secondhand_marketplace_app/utils/image_utils.dart';
import 'constants.dart';
import 'models/product.dart';

class ReportItemPage extends StatefulWidget {
  final Product product;

  const ReportItemPage({super.key, required this.product});

  @override
  State<ReportItemPage> createState() => _ReportItemPageState();
}

class _ReportItemPageState extends State<ReportItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String _sellerUsername = 'Loading...';
  String _sellerId = '';
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _sellerId = widget.product.sellerId;
    _currentUserId = _auth.currentUser?.uid ?? 'guest';
    _fetchSellerInfo();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchSellerInfo() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_sellerId).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _sellerUsername = userData['username'] ?? 'Unknown Seller';
            _isLoading = false;
          });
        }
      } else {
        // If user document doesn't exist, use default values
        if (mounted) {
          setState(() {
            _sellerUsername = 'Seller ${_sellerId.substring(0, 4)}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching seller info: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _submitReport() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      // Create a report document in Firestore
      _firestore.collection('reports').add({
        'reporterId': _currentUserId,
        'productId': widget.product.id,
        'sellerId': _sellerId,
        'reason': _subjectController.text,
        'description': _descriptionController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Pending'
      }).then((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Report submitted successfully'),
              backgroundColor: AppColors.mutedTeal,
              duration: const Duration(seconds: 2),
            ),
          );

          // Navigate back after a short delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting report: $error'),
              backgroundColor: AppColors.warmCoral,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: AppColors.deepSlateGray,
        title: Text('Report Item', style: TextStyle(color: AppColors.coolGray)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.coolGray),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.deepSlateGray,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.mutedTeal.withAlpha(100),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Product Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ImageUtils.base64ToImage(
                          widget.product.imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Product Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.name,
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
                              'RM ${widget.product.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: AppColors.mutedTeal,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isLoading ? 'Loading seller info...' : 'Seller: $_sellerUsername',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.coolGray.withAlpha(179),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Reason Field
                Text(
                  'Reason for Report',
                  style: TextStyle(fontSize: 16, color: AppColors.coolGray),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _subjectController,
                  style: TextStyle(color: AppColors.coolGray),
                  decoration: InputDecoration(
                    hintText: 'Enter the reason for your report',
                    helperText: 'e.g. Counterfeit item, Inappropriate content, etc.',
                    hintStyle: TextStyle(
                      color: AppColors.coolGray.withAlpha(128),
                    ),
                    filled: true,
                    fillColor: AppColors.deepSlateGray,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.mutedTeal.withAlpha(100),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.mutedTeal.withAlpha(100),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.mutedTeal),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a subject';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Description Field
                Text(
                  'Description',
                  style: TextStyle(fontSize: 16, color: AppColors.coolGray),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  style: TextStyle(color: AppColors.coolGray),
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Provide details about the issue',
                    hintStyle: TextStyle(
                      color: AppColors.coolGray.withAlpha(128),
                    ),
                    filled: true,
                    fillColor: AppColors.deepSlateGray,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.mutedTeal.withAlpha(100),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.mutedTeal.withAlpha(100),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.mutedTeal),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warmCoral,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Submit Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
