// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app/user_role.dart';
import 'constants.dart';
import 'widgets/app_forms.dart';
import 'widgets/state_widgets.dart';

class SharedProfilePage extends StatefulWidget {
  const SharedProfilePage({
    super.key,
    required this.role,
  });

  final UserRole role;

  @override
  State<SharedProfilePage> createState() => _SharedProfilePageState();
}

class _SharedProfilePageState extends State<SharedProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isSavingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  String? _errorMessage;
  String _status = 'active';
  DateTime? _createdAt;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'You need to sign in to view this profile.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userDoc = await _firestore.collection('USER').doc(user.uid).get();
      final legacyDoc = await _firestore.collection('users').doc(user.uid).get();

      final data = (userDoc.data()?.isNotEmpty == true)
          ? userDoc.data()!
          : (legacyDoc.data() ?? <String, dynamic>{});

      _fullNameController.text = _stringValue(
        data['fullName'],
        fallback: _stringValue(data['username'], fallback: user.displayName ?? ''),
      );
      _emailController.text = _stringValue(
        data['email'],
        fallback: user.email ?? '',
      );
      _phoneController.text = _stringValue(
        data['phoneNumber'],
        fallback: _stringValue(data['phone']),
      );
      _status = _stringValue(data['status'], fallback: 'active');
      _createdAt = _readDateTime(data['createdAt']);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to load your profile right now.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    setState(() {
      _isSavingProfile = true;
    });

    try {
      final updatedEmail = _emailController.text.trim();
      if (updatedEmail != (user.email ?? '')) {
        await user.verifyBeforeUpdateEmail(updatedEmail);
      }

      if (_fullNameController.text.trim().isNotEmpty &&
          _fullNameController.text.trim() != (user.displayName ?? '')) {
        await user.updateDisplayName(_fullNameController.text.trim());
      }

      final payload = <String, dynamic>{
        'userId': user.uid,
        'fullName': _fullNameController.text.trim(),
        'email': updatedEmail,
        'phoneNumber': _phoneController.text.trim(),
        'role': widget.role.key,
        'status': _status,
        'createdAt': _createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(_createdAt!),
      };

      await _firestore
          .collection('USER')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      await _firestore.collection('users').doc(user.uid).set({
        'fullName': _fullNameController.text.trim(),
        'username': _fullNameController.text.trim(),
        'email': updatedEmail,
        'phoneNumber': _phoneController.text.trim(),
        'role': widget.role.key,
        'status': _status,
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingProfile = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedEmail == (user.email ?? '')
                ? 'Profile updated.'
                : 'Profile updated. Check your inbox to confirm the email change.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      setState(() {
        _isSavingProfile = false;
      });

      final message = switch (error.code) {
        'requires-recent-login' =>
          'Re-authenticate before changing your email address.',
        'invalid-email' => 'Enter a valid email address.',
        'email-already-in-use' => 'That email address is already in use.',
        _ => 'Unable to update profile right now.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      setState(() {
        _isSavingProfile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update profile right now.')),
      );
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return;
    }

    setState(() {
      _isSavingPassword = true;
    });

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingPassword = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated.')),
      );
    } on FirebaseAuthException catch (error) {
      setState(() {
        _isSavingPassword = false;
      });

      final message = switch (error.code) {
        'wrong-password' => 'Your current password is incorrect.',
        'invalid-credential' => 'Your current password is incorrect.',
        'weak-password' => 'Use a stronger password.',
        'requires-recent-login' =>
          'Re-authentication is required before changing your password.',
        _ => 'Unable to update password right now.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      setState(() {
        _isSavingPassword = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update password right now.')),
      );
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (_isLoading) {
      return const AppLoadingState(message: 'Loading profile...');
    }

    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        onRetry: _loadProfile,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _ProfileHero(
          userId: user?.uid ?? 'Not available',
          fullName: _fullNameController.text.trim().isNotEmpty
              ? _fullNameController.text.trim()
              : (user?.displayName ?? user?.email ?? 'CommunityShare user'),
          roleLabel: widget.role.label,
          status: _status,
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _profileFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _fullNameController,
                    label: 'Full Name',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your full name.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your email.';
                      }
                      if (!RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value.trim())) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone_outlined),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your phone number.';
                      }
                      if (value.trim().length < 7) {
                        return 'Enter a valid phone number.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPrimaryButton(
                    label: 'Save profile',
                    isLoading: _isSavingProfile,
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.save_outlined),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _passwordFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Security',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'The USER table includes password storage, but this app never exposes the stored hash. Use this section to rotate your password safely through Firebase Auth.',
                    style: TextStyle(color: AppColors.mist, height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _currentPasswordController,
                    label: 'Current Password',
                    obscureText: _obscureCurrentPassword,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureCurrentPassword = !_obscureCurrentPassword;
                        });
                      },
                      icon: Icon(
                        _obscureCurrentPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your current password.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _newPasswordController,
                    label: 'New Password',
                    obscureText: _obscureNewPassword,
                    prefixIcon: const Icon(Icons.enhanced_encryption_outlined),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter a new password.';
                      }
                      if (value.length < 6) {
                        return 'Use at least 6 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm New Password',
                    obscureText: _obscureConfirmPassword,
                    prefixIcon: const Icon(Icons.verified_user_outlined),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirm the new password.';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPrimaryButton(
                    label: 'Update password',
                    isLoading: _isSavingPassword,
                    onPressed: _changePassword,
                    icon: const Icon(Icons.shield_outlined),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(
          label: 'Sign out',
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    );
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    return fallback;
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.userId,
    required this.fullName,
    required this.roleLabel,
    required this.status,
  });

  final String userId;
  final String fullName;
  final String roleLabel;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(
          colors: [AppColors.forest, AppColors.pine],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACCOUNT',
            style: TextStyle(
              color: AppColors.sand,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            fullName,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'User ID: $userId',
            style: const TextStyle(
              color: AppColors.sand,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _HeroChip(label: roleLabel),
              _HeroChip(label: 'Status: $status'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.sand,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
