import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/state_widgets.dart';

class ManageHubProfilePage extends StatefulWidget {
  const ManageHubProfilePage({super.key});

  @override
  State<ManageHubProfilePage> createState() => _ManageHubProfilePageState();
}

class _ManageHubProfilePageState extends State<ManageHubProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _hubNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _operatingHoursController =
      TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';
  String _status = 'active';
  String _hubDocId = '';
  String _hubId = '';

  @override
  void initState() {
    super.initState();
    _loadHubProfile();
  }

  @override
  void dispose() {
    _hubNameController.dispose();
    _addressController.dispose();
    _operatingHoursController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadHubProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection('COMMUNITY_HUB')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      final doc = snapshot.docs.isNotEmpty ? snapshot.docs.first : null;
      final data = doc?.data() ?? const <String, dynamic>{};

      _hubNameController.text = _stringValue(data['hubName']);
      _addressController.text = _stringValue(data['address']);
      _operatingHoursController.text = _stringValue(data['operatingHours']);
      _contactNumberController.text = _stringValue(data['contactNumber']);

      if (!mounted) {
        return;
      }

      setState(() {
        _hubDocId = doc?.id ?? userId;
        _hubId = _stringValue(data['hubId'], fallback: doc?.id ?? userId);
        _status = _stringValue(data['status'], fallback: 'active');
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load hub profile: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveHubProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final docId = _hubDocId.isNotEmpty ? _hubDocId : userId;
      final hubId = _hubId.isNotEmpty ? _hubId : docId;
      final operatingHours = _operatingHoursController.text.trim();

      await _firestore.collection('COMMUNITY_HUB').doc(docId).set({
        'hubId': hubId,
        'userId': userId,
        'hubName': _hubNameController.text.trim(),
        'address': _addressController.text.trim(),
        'operatingHours': operatingHours,
        'contactNumber': _contactNumberController.text.trim(),
        'status': _status,
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      setState(() {
        _hubDocId = docId;
        _hubId = hubId;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hub profile updated.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save hub profile: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingState(message: 'Loading hub profile...');
    }

    if (_errorMessage.isNotEmpty) {
      return AppErrorState(
        message: _errorMessage,
        onRetry: _loadHubProfile,
      );
    }

    final hubLabel = _hubNameController.text.trim().isNotEmpty
        ? _hubNameController.text.trim()
        : 'Community Hub';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _HubProfileHero(
          hubName: hubLabel,
          hubId: _hubId.isNotEmpty ? _hubId : _hubDocId,
          status: _status,
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Hub Details',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Update the community hub information that donors and recipients rely on during handover.',
                    style: TextStyle(color: AppColors.mist, height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _hubNameController,
                    label: 'Hub Name',
                    hint: 'Enter your hub name',
                    prefixIcon: const Icon(Icons.holiday_village_outlined),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Enter a hub name.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _addressController,
                    label: 'Address',
                    hint: 'Enter the hub address',
                    prefixIcon: const Icon(Icons.place_outlined),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Enter the hub address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _operatingHoursController,
                    label: 'Operating Hours',
                    hint: 'e.g. Mon-Fri, 9 AM - 6 PM',
                    prefixIcon: const Icon(Icons.schedule_outlined),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Enter operating hours.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _contactNumberController,
                    label: 'Contact Number',
                    hint: 'Enter the hub contact number',
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone_outlined),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Enter a contact number.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Hub Status',
                      prefixIcon: Icon(Icons.verified_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Active'),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _status = value;
                            });
                          },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPrimaryButton(
                    label: 'Save Hub Profile',
                    isLoading: _isSaving,
                    onPressed: _saveHubProfile,
                    icon: const Icon(Icons.save_outlined),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    return fallback;
  }
}

class _HubProfileHero extends StatelessWidget {
  const _HubProfileHero({
    required this.hubName,
    required this.hubId,
    required this.status,
  });

  final String hubName;
  final String hubId;
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
            'COMMUNITY HUB',
            style: TextStyle(
              color: AppColors.sand,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hubName,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Hub ID: ${hubId.isEmpty ? 'Not created yet' : hubId}',
            style: const TextStyle(color: AppColors.sand),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              'Status: ${status[0].toUpperCase()}${status.substring(1)}',
              style: const TextStyle(
                color: AppColors.sand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
