import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'constants.dart';
import 'buyer_home_page.dart';
import 'buyer_purchases_page.dart';
import 'buyer_wallet_page.dart';
import 'utils/page_transitions.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  int _selectedIndex = 3; // Set to 3 for Profile tab
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
  String _role = '';
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
          _role = userData['role'] ?? 'user';

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
    if (index == 0) {
      // Navigate directly to HomePage
      Navigator.pushReplacement(
        context,
        DarkPageReplaceRoute(
          page: const MyHomePage(title: 'Secondhand Marketplace'),
        ),
      );
    } else if (index == 1) {
      // Navigate to My Purchases page
      Navigator.pushReplacement(
        context,
        DarkPageReplaceRoute(page: const MyPurchasesPage()),
      );
    } else if (index == 2) {
      // Navigate to Wallet page
      Navigator.pushReplacement(
        context,
        DarkPageReplaceRoute(page: const MyWalletPage()),
      );
    } else if (index == 3) {
      // Already on Profile page, just update index
      setState(() {
        _selectedIndex = index;
      });
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

  // Helper method to check if a string is a base64 image
  bool _isBase64Image(String source) {
    try {
      // Check if the string starts with a base64 image prefix
      if (source.startsWith('data:image')) {
        return true;
      }

      // Check if it's a raw base64 string (without data URI scheme)
      // This is a simple check - in production you might want more validation
      final RegExp base64Regex = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
      return base64Regex.hasMatch(source) && source.length % 4 == 0;
    } catch (e) {
      return false;
    }
  }

  // Get image provider based on source (file, network URL, or base64)
  ImageProvider _getImageProvider() {
    if (_profileImageFile != null) {
      return FileImage(_profileImageFile!) as ImageProvider;
    } else if (_profileImageUrl.isNotEmpty) {
      // Check if the URL is actually a base64 image
      if (_isBase64Image(_profileImageUrl)) {
        // If it's a data URI with prefix
        if (_profileImageUrl.startsWith('data:image')) {
          // Extract the base64 part from data URI
          final String base64String = _profileImageUrl.split(',')[1];
          return MemoryImage(base64Decode(base64String));
        } else {
          // If it's a raw base64 string
          return MemoryImage(base64Decode(_profileImageUrl));
        }
      } else {
        // Regular network image URL
        return NetworkImage(_profileImageUrl) as ImageProvider;
      }
    } else {
      // Default profile image
      return const AssetImage('assets/default_profile.png') as ImageProvider;
    }
  }

  // Convert image to base64 or upload to Firebase Storage
  Future<String?> _uploadProfileImage({bool useBase64 = true}) async {
    if (_profileImageFile == null) return null;

    try {
      if (useBase64) {
        // Convert image to base64
        final List<int> imageBytes = await _profileImageFile!.readAsBytes();
        final String base64Image = base64Encode(imageBytes);

        // Return as data URI
        return 'data:image/jpeg;base64,$base64Image';
      } else {
        // Upload to Firebase Storage (original implementation)
        final String fileName =
            'profile_${_uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference storageRef = _storage.ref().child(
          'profile_images/$fileName',
        );

        final UploadTask uploadTask = storageRef.putFile(_profileImageFile!);
        final TaskSnapshot taskSnapshot = await uploadTask;

        final String downloadUrl = await taskSnapshot.ref.getDownloadURL();
        return downloadUrl;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in all fields'),
          backgroundColor: AppColors.warmCoral,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if username is already taken (if username was changed)
      final QuerySnapshot usernameCheck =
          await _firestore
              .collection('users')
              .where('username', isEqualTo: _usernameController.text)
              .where(FieldPath.documentId, isNotEqualTo: _uid)
              .get();

      if (usernameCheck.docs.isNotEmpty) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Username already taken. Please choose another one.',
              ),
              backgroundColor: AppColors.warmCoral,
            ),
          );
        }
        return;
      }

      // Upload new profile image if selected
      String? newImageUrl;
      if (_profileImageFile != null) {
        // Use base64 encoding for the profile image
        newImageUrl = await _uploadProfileImage(useBase64: true);
      }

      // Update user data in Firestore
      final Map<String, dynamic> updatedData = {
        'username': _usernameController.text,
        'address': _addressController.text,
      };

      // Add new profile image URL if available
      if (newImageUrl != null) {
        updatedData['profileImageUrl'] = newImageUrl;
        _profileImageUrl = newImageUrl;
      }

      await _firestore.collection('users').doc(_uid).update(updatedData);

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: AppColors.mutedTeal,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: AppColors.warmCoral,
          ),
        );
      }
    }
  }

  Future<void> _submitHelpRequest() async {
    if (_helpSubjectController.text.isEmpty ||
        _helpMessageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter both subject and message'),
          backgroundColor: AppColors.warmCoral,
        ),
      );
      return;
    }

    // Store form data locally before async operation
    final String subject = _helpSubjectController.text;
    final String message = _helpMessageController.text;
    final String username = _usernameController.text;
    final String email = _emailController.text;
    final String userId = _uid;

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate a unique ID for the help request
      final Timestamp currentTimestamp = Timestamp.now();

      // Save help request to Firestore helpCenterRequests collection
      await _firestore.collection('helpCenterRequests').add({
        'userId': userId,
        'username': username,
        'email': email,
        'subject': subject,
        'message': message,
        'status': 'Pending',
        'createdAt': currentTimestamp,
        'userRole': 'buyer',
      });

      // Clear form fields and update loading state
      if (mounted) {
        setState(() {
          _helpSubjectController.clear();
          _helpMessageController.clear();
          _isLoading = false;
        });

        // Show success message only if widget is still mounted
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Your request has been submitted. We will get back to you soon.',
              ),
              backgroundColor: AppColors.mutedTeal,
            ),
          );
        }
      }
    } catch (e) {
      // Update loading state if widget is still mounted
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show error message only if widget is still mounted
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting help request: $e'),
              backgroundColor: AppColors.warmCoral,
            ),
          );
        }
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
                          color:
                              _role == 'buyer'
                                  ? AppColors.mutedTeal
                                  : AppColors.softLemonYellow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color:
                                _role == 'buyer'
                                    ? Colors.white
                                    : AppColors.charcoalBlack,
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

              // Removed account stats section

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
