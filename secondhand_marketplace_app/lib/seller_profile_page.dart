import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:secondhand_marketplace_app/seller_messages_page.dart';
import 'constants.dart';
import 'seller_listing_page.dart';
import 'seller_reviews_page.dart';
import 'seller_wallet_page.dart';
import 'utils/page_transitions.dart';
import 'utils/image_utils.dart';
import 'utils/image_converter.dart';

class SellerProfilePage extends StatefulWidget {
  const SellerProfilePage({super.key});

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage> {
  int _selectedIndex = 4; // Set to 4 for Profile tab
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _helpSubjectController = TextEditingController();
  final TextEditingController _helpMessageController = TextEditingController();

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // User data
  String _profileImageUrl = '';
  String _uid = '';
  String _role = 'seller';
  DateTime? _joinDate;
  bool _isLoading = true;

  File? _profileImageFile;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _helpSubjectController.dispose();
    _helpMessageController.dispose();
    super.dispose();
  }

  // Fetch user data from Firestore
  Future<void> _fetchUserData() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      _uid = currentUser.uid;
      final DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;

        setState(() {
          _usernameController.text = userData['username'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _addressController.text = userData['address'] ?? '';
          _profileImageUrl = userData['profileImageUrl'] ?? '';
          _role = userData['role'] ?? 'seller';

          if (userData['joinDate'] != null) {
            _joinDate = (userData['joinDate'] as Timestamp).toDate();
          }

          _isLoading = false;
        });

        // Ensure user has seller role
        if (_role != 'seller') {
          await _firestore.collection('users').doc(_uid).update({
            'role': 'seller',
          });
          _role = 'seller';
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0: // Navigate to My Listings
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const SellerListingPage()),
        );
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
      case 3: // Navigate to Messages
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const SellerMessagesPage()),
        );
        break;
      case 4: // Already on Profile page, just update index
        setState(() {
          _selectedIndex = index;
        });
        break;
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null && mounted) {
        setState(() {
          _profileImageFile = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppColors.warmCoral,
          ),
        );
      }
    }
  }

  ImageProvider _getImageProvider() {
    if (_profileImageFile != null) {
      return FileImage(_profileImageFile!);
    } else if (_profileImageUrl.isNotEmpty) {
      if (ImageUtils.isBase64Image(_profileImageUrl)) {
        return MemoryImage(ImageConverter.base64ToBytes(_profileImageUrl));
      } else {
        return NetworkImage(_profileImageUrl);
      }
    } else {
      return const AssetImage('assets/images/default_profile.png');
    }
  }

  Future<String?> _uploadProfileImage({bool useBase64 = true}) async {
    if (_profileImageFile == null) return null;

    try {
      if (useBase64) {
        // Convert image to base64
        final bytes = await _profileImageFile!.readAsBytes();
        final base64Image = base64Encode(bytes);

        // Return as data URI
        return 'data:image/jpeg;base64,$base64Image';
      } else {
        // Upload to Firebase Storage
        final fileName =
            'profile_${_uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = _storage.ref().child('profile_images/$fileName');

        final uploadTask = ref.putFile(_profileImageFile!);
        final taskSnapshot = await uploadTask;

        return await taskSnapshot.ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (_usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _addressController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all required fields'),
            backgroundColor: AppColors.warmCoral,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if username is already taken (if username was changed)
      final usernameCheck =
          await _firestore
              .collection('users')
              .where('username', isEqualTo: _usernameController.text)
              .where(FieldPath.documentId, isNotEqualTo: _uid)
              .get();

      if (usernameCheck.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Username already taken. Please choose another one.',
              ),
              backgroundColor: AppColors.warmCoral,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Upload new profile image if selected
      String? newImageUrl;
      if (_profileImageFile != null) {
        // Use base64 encoding for the profile image
        newImageUrl = await _uploadProfileImage(useBase64: true);
      }

      // Update user data in Firestore
      final updatedData = <String, dynamic>{
        'username': _usernameController.text,
        'address': _addressController.text,
        'role': 'seller',
      };

      // Add new profile image URL if available
      if (newImageUrl != null) {
        updatedData['profileImageUrl'] = newImageUrl;
        _profileImageUrl = newImageUrl;
      }

      await _firestore.collection('users').doc(_uid).update(updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.mutedTeal,
          ),
        );

        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${e.toString()}'),
            backgroundColor: AppColors.warmCoral,
          ),
        );

        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitHelpRequest() async {
    if (_helpSubjectController.text.isEmpty ||
        _helpMessageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in both subject and message'),
          backgroundColor: AppColors.warmCoral,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save help request to Firestore
      await _firestore.collection('helpCenterRequests').add({
        'userId': _uid,
        'username': _usernameController.text,
        'email': _emailController.text,
        'subject': _helpSubjectController.text,
        'message': _helpMessageController.text,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'userRole': 'seller',
      });

      // Clear the form
      _helpSubjectController.clear();
      _helpMessageController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Your request has been submitted. We will get back to you soon.',
            ),
            backgroundColor: AppColors.mutedTeal,
          ),
        );

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting request: $e'),
            backgroundColor: AppColors.warmCoral,
          ),
        );

        setState(() {
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
        backgroundColor: AppColors.deepSlateGray,
        title: Text('My Profile', style: TextStyle(color: AppColors.coolGray)),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              color: AppColors.coolGray,
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              color: AppColors.mutedTeal,
              onPressed: _saveProfile,
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.cancel),
              color: AppColors.warmCoral,
              onPressed: () {
                setState(() {
                  _isEditing = false;
                });
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
              // Profile Header with Image
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        _isLoading
                            ? CircularProgressIndicator(
                              color: AppColors.mutedTeal,
                            )
                            : CircleAvatar(
                              radius: 60,
                              backgroundImage: _getImageProvider(),
                            ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.mutedTeal,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt),
                                color: Colors.white,
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!_isEditing && !_isLoading)
                      Text(
                        _usernameController.text,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.coolGray,
                        ),
                      ),
                    if (!_isEditing && !_isLoading && _role.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.softLemonYellow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.charcoalBlack,
                          ),
                        ),
                      ),
                    if (!_isEditing && !_isLoading && _joinDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Member since ${DateFormat('MMMM yyyy').format(_joinDate!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.coolGray.withAlpha(150),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Store Information Section
              Card(
                color: AppColors.deepSlateGray,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.coolGray,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Editing Mode
                      if (_isEditing) ...[
                        // Username Field
                        Text(
                          'Username',
                          style: TextStyle(color: AppColors.coolGray),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _usernameController,
                          style: TextStyle(color: AppColors.coolGray),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.charcoalBlack,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.coolGray),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppColors.mutedTeal,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Email Field (Read-only)
                        Text(
                          'Email',
                          style: TextStyle(color: AppColors.coolGray),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          style: TextStyle(color: AppColors.coolGray),
                          enabled: false, // Disable email editing
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.charcoalBlack,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppColors.coolGray.withAlpha(100),
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppColors.coolGray.withAlpha(70),
                              ),
                            ),
                            suffixIcon: Icon(
                              Icons.lock,
                              color: AppColors.coolGray.withAlpha(100),
                            ),
                            hintText: 'Email cannot be changed',
                            hintStyle: TextStyle(
                              color: AppColors.coolGray.withAlpha(100),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Address Field
                        Text(
                          'Address',
                          style: TextStyle(color: AppColors.coolGray),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _addressController,
                          style: TextStyle(color: AppColors.coolGray),
                          maxLines: 2,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.charcoalBlack,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.coolGray),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppColors.mutedTeal,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Display mode (non-editing)
                        ListTile(
                          leading: Icon(
                            Icons.location_on,
                            color: AppColors.mutedTeal,
                          ),
                          title: Text(
                            'Address',
                            style: TextStyle(
                              color: AppColors.coolGray.withAlpha(200),
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            _addressController.text,
                            style: TextStyle(color: AppColors.coolGray),
                          ),
                        ),
                        Divider(color: AppColors.coolGray.withAlpha(50)),
                        ListTile(
                          leading: Icon(
                            Icons.email,
                            color: AppColors.mutedTeal,
                          ),
                          title: Text(
                            'Email',
                            style: TextStyle(
                              color: AppColors.coolGray.withAlpha(200),
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            _emailController.text,
                            style: TextStyle(color: AppColors.coolGray),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Help Center Section
              Card(
                color: AppColors.deepSlateGray,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Help Center',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.coolGray,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Do you have any feedbacks, complaints, and enquiries?',
                        style: TextStyle(color: AppColors.coolGray),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Subject',
                        style: TextStyle(color: AppColors.coolGray),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _helpSubjectController,
                        style: TextStyle(color: AppColors.coolGray),
                        decoration: InputDecoration(
                          hintText: 'Enter subject',
                          hintStyle: TextStyle(
                            color: AppColors.coolGray.withAlpha(150),
                          ),
                          filled: true,
                          fillColor: AppColors.charcoalBlack,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.coolGray),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.mutedTeal),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Message',
                        style: TextStyle(color: AppColors.coolGray),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _helpMessageController,
                        style: TextStyle(color: AppColors.coolGray),
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Type your message here...',
                          hintStyle: TextStyle(
                            color: AppColors.coolGray.withAlpha(150),
                          ),
                          filled: true,
                          fillColor: AppColors.charcoalBlack,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.coolGray),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.mutedTeal),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitHelpRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mutedTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Logout option
              Card(
                color: AppColors.deepSlateGray,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(Icons.logout, color: AppColors.warmCoral),
                  title: Text(
                    'Logout',
                    style: TextStyle(color: AppColors.coolGray),
                  ),
                  onTap: () async {
                    // Handle logout
                    try {
                      await _auth.signOut();
                      if (!mounted) return;

                      // Use a post-frame callback to ensure the widget is still in the tree
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/',
                          (route) => false,
                        );
                      });
                    } catch (e) {
                      if (!mounted) return;

                      // Use a post-frame callback for error handling too
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error logging out: $e'),
                            backgroundColor: AppColors.warmCoral,
                          ),
                        );
                      });
                    }
                  },
                ),
              ),

              // Bottom padding
              const SizedBox(height: 32),
            ],
          ),
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
}
