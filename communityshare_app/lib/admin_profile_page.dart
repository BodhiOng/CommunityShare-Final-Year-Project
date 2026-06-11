import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'constants.dart';
import 'admin_user_management_page.dart';
import 'admin_product_moderation_page.dart';
import 'admin_order_management_page.dart';
import 'admin_customer_support_page.dart';
import 'utils/image_utils.dart';
import 'utils/image_converter.dart';
import 'utils/page_transitions.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  int _selectedIndex = 4; // 0 for User Management, 1 for Products, 2 for Orders, 3 for Customer Support, 4 for Profile
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // User data
  String _profileImageUrl = '';
  String _uid = '';
  String _role = 'admin';
  DateTime? _joinDate;
  bool _isLoading = true;
  bool _isEditing = false;
  File? _profileImageFile;

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
          _role = userData['role'] ?? 'admin';

          if (userData['joinDate'] != null) {
            _joinDate = (userData['joinDate'] as Timestamp).toDate();
          }
          _isLoading = false;
        });
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

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        // Navigate to User Management page
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminUserManagementPage()),
        );
        break;
      case 1:
        // Navigate to Product Moderation page
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminProductModerationPage()),
        );
        break;
      case 2:
        // Navigate to Order Moderation page
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminOrderModerationPage()),
        );
        break;
      case 3:
        // Navigate to Customer Support page
        Navigator.pushReplacement(
          context,
          DarkPageReplaceRoute(page: const AdminCustomerSupportPage()),
        );
        break;
      case 4:
        // Already on Profile page
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
        // Handle both plain base64 and data URI formats
        final String base64String =
            _profileImageUrl.startsWith('data:image')
                ? _profileImageUrl
                    .split(',')
                    .last // Extract base64 part from data URI
                : _profileImageUrl; // Already just the base64 string
        return MemoryImage(base64Decode(base64String));
      } else {
        return NetworkImage(_profileImageUrl);
      }
    } else {
      return const AssetImage('assets/images/default_profile.png');
    }
  }

  Future<void> _uploadProfileImage({bool useBase64 = true}) async {
    try {
      if (_profileImageFile == null) return;

      if (useBase64) {
        // Convert image to base64 string
        final String base64String = await ImageConverter.fileToBase64(
          _profileImageFile!,
        );
        setState(() {
          _profileImageUrl = base64String;
        });
      } else {
        // Upload to Firebase Storage
        final String fileName = 'profile_$_uid.jpg';
        final Reference storageRef = _storage
            .ref()
            .child('profile_images')
            .child(fileName);

        await storageRef.putFile(_profileImageFile!);
        final String downloadUrl = await storageRef.getDownloadURL();

        setState(() {
          _profileImageUrl = downloadUrl;
        });
      }
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: AppColors.warmCoral,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Upload profile image if changed
      if (_profileImageFile != null) {
        await _uploadProfileImage();
      }

      // Update user data in Firestore
      await _firestore.collection('users').doc(_uid).update({
        'username': _usernameController.text,
        'address': _addressController.text,
        'profileImageUrl': _profileImageUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.mutedTeal,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: AppColors.warmCoral,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: AppColors.deepSlateGray,
        title: Text(
          'My Profile',
          style: TextStyle(color: AppColors.coolGray),
        ),
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

              // Profile Information Section
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
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.coolGray,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Username Field
                      if (_isEditing) ...[
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
        backgroundColor: AppColors.deepSlateGray,
        selectedItemColor: AppColors.softLemonYellow,
        unselectedItemColor: AppColors.coolGray,
        currentIndex: 4, // Profile tab is selected
        onTap: _onItemTapped,
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
