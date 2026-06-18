import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'widgets/app_forms.dart';
import 'widgets/state_widgets.dart';

class AdminUserCrudPage extends StatefulWidget {
  const AdminUserCrudPage({super.key});

  @override
  State<AdminUserCrudPage> createState() => _AdminUserCrudPageState();
}

class _AdminUserCrudPageState extends State<AdminUserCrudPage> {
  static const List<String> _roles = [
    'donor',
    'recipient',
    'hub',
    'admin',
  ];

  static const List<String> _statuses = [
    'active',
    'inactive',
    'suspended',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  List<_ManagedUserRecord> _users = const [];
  List<_ManagedUserRecord> _filteredUsers = const [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _roleFilter = 'all';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final snapshot = await _firestore.collection('USER').get();
      final users = snapshot.docs
          .map((doc) => _ManagedUserRecord.fromSnapshot(doc))
          .toList()
        ..sort((a, b) {
          final byName = a.fullName.toLowerCase().compareTo(
                b.fullName.toLowerCase(),
              );
          if (byName != 0) {
            return byName;
          }
          return a.userId.compareTo(b.userId);
        });

      if (!mounted) {
        return;
      }

      setState(() {
        _users = users;
        _isLoading = false;
      });
      _applyFilters();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load users: $error';
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesQuery = query.isEmpty ||
            user.userId.toLowerCase().contains(query) ||
            user.fullName.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            user.phoneNumber.toLowerCase().contains(query);

        final matchesRole =
            _roleFilter == 'all' || user.role.toLowerCase() == _roleFilter;
        final matchesStatus =
            _statusFilter == 'all' || user.status.toLowerCase() == _statusFilter;

        return matchesQuery && matchesRole && matchesStatus;
      }).toList(growable: false);
    });
  }

  Future<_RoleSpecificDetails> _loadRoleSpecificDetails(
    String userId,
    String role,
  ) async {
    switch (role) {
      case 'recipient':
        final snapshot = await _firestore
            .collection('RECIPIENT')
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();
        if (snapshot.docs.isEmpty) {
          return const _RoleSpecificDetails();
        }
        final doc = snapshot.docs.first;
        final data = doc.data();
        return _RoleSpecificDetails(
          docId: doc.id,
          recipientId: _stringValue(data['recipientId'], fallback: doc.id),
          recipientType: _stringValue(data['recipientType']),
        );
      case 'hub':
        final snapshot = await _firestore
            .collection('COMMUNITY_HUB')
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();
        if (snapshot.docs.isEmpty) {
          return const _RoleSpecificDetails();
        }
        final doc = snapshot.docs.first;
        final data = doc.data();
        return _RoleSpecificDetails(
          docId: doc.id,
          hubId: _stringValue(data['hubId'], fallback: doc.id),
          hubName: _stringValue(data['hubName']),
          address: _stringValue(data['address']),
          operatingHours: _stringValue(data['operatingHours']),
          contactNumber: _stringValue(data['contactNumber']),
          status: _stringValue(data['status']),
        );
      case 'donor':
        final snapshot = await _firestore
            .collection('DONOR')
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();
        if (snapshot.docs.isEmpty) {
          return const _RoleSpecificDetails();
        }
        final doc = snapshot.docs.first;
        final data = doc.data();
        return _RoleSpecificDetails(
          docId: doc.id,
          donorId: _stringValue(data['donorId'], fallback: doc.id),
        );
      case 'admin':
        final snapshot = await _firestore
            .collection('ADMIN')
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();
        if (snapshot.docs.isEmpty) {
          return const _RoleSpecificDetails();
        }
        final doc = snapshot.docs.first;
        final data = doc.data();
        return _RoleSpecificDetails(
          docId: doc.id,
          adminId: _stringValue(data['adminId'], fallback: doc.id),
        );
      default:
        return const _RoleSpecificDetails();
    }
  }

  Future<void> _openUserEditor({_ManagedUserRecord? user}) async {
    final details = user == null
        ? const _RoleSpecificDetails()
        : await _loadRoleSpecificDetails(user.userId, user.role);
    if (!mounted) {
      return;
    }

    final formKey = GlobalKey<FormState>();
    final userIdController = TextEditingController(text: user?.userId ?? '');
    final fullNameController =
        TextEditingController(text: user?.fullName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordHashController =
        TextEditingController(text: user?.passwordHash ?? '');
    final phoneNumberController =
        TextEditingController(text: user?.phoneNumber ?? '');
    final recipientTypeController =
        TextEditingController(text: details.recipientType);
    final hubIdController = TextEditingController(
      text: details.hubId.isNotEmpty
          ? details.hubId
          : (user?.userId ?? ''),
    );
    final hubNameController = TextEditingController(text: details.hubName);
    final addressController = TextEditingController(text: details.address);
    final operatingHoursController =
        TextEditingController(text: details.operatingHours);
    final contactNumberController =
        TextEditingController(text: details.contactNumber);

    var role = user?.role ?? 'recipient';
    var status = user?.status ?? 'active';
    var errorMessage = '';
    var isSaving = false;

    final didSave = await showDialog<bool>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              setModalState(() {
                isSaving = true;
                errorMessage = '';
              });

              try {
                await _saveUser(
                  existingUser: user,
                  userId: userIdController.text.trim(),
                  fullName: fullNameController.text.trim(),
                  email: emailController.text.trim(),
                  passwordHash: passwordHashController.text.trim(),
                  phoneNumber: phoneNumberController.text.trim(),
                  role: role,
                  status: status,
                  recipientType: recipientTypeController.text.trim(),
                  hubDetails: _RoleSpecificDetails(
                    docId: details.docId,
                    hubId: hubIdController.text.trim(),
                    hubName: hubNameController.text.trim(),
                    address: addressController.text.trim(),
                    operatingHours: operatingHoursController.text.trim(),
                    contactNumber: contactNumberController.text.trim(),
                    status: status,
                    donorId: details.donorId,
                    recipientId: details.recipientId,
                    adminId: details.adminId,
                  ),
                  existingDetails: details,
                );

                if (!mounted || !context.mounted) {
                  return;
                }
                Navigator.of(context).pop(true);
              } catch (error) {
                setModalState(() {
                  isSaving = false;
                  errorMessage = error.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.forest,
              title: Text(user == null ? 'Create User' : 'Edit User'),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This page manages USER and linked role-table documents. Use the matching auth UID as User ID when creating a new record.',
                          style: TextStyle(
                            color: AppColors.mist,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: userIdController,
                          label: 'User ID',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Enter a user ID.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: fullNameController,
                          label: 'Full Name',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Enter the full name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: emailController,
                          label: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon:
                              const Icon(Icons.alternate_email_rounded),
                          validator: (value) {
                            final normalized = (value ?? '').trim();
                            if (normalized.isEmpty) {
                              return 'Enter an email address.';
                            }
                            final valid = RegExp(
                              r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(normalized);
                            if (!valid) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: passwordHashController,
                          label: 'Password Hash',
                          prefixIcon: const Icon(Icons.password_outlined),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: phoneNumberController,
                          label: 'Phone Number',
                          keyboardType: TextInputType.phone,
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String>(
                          value: role,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            prefixIcon:
                                Icon(Icons.admin_panel_settings_outlined),
                          ),
                          items: _roles
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(_titleCase(value)),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setModalState(() {
                              role = value;
                              if (role == 'hub' &&
                                  hubIdController.text.trim().isEmpty) {
                                hubIdController.text =
                                    userIdController.text.trim();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String>(
                          value: status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            prefixIcon: Icon(Icons.toggle_on_outlined),
                          ),
                          items: _statuses
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(_titleCase(value)),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setModalState(() {
                              status = value;
                            });
                          },
                        ),
                        if (role == 'recipient') ...[
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: recipientTypeController,
                            label: 'Recipient Type',
                            prefixIcon: const Icon(Icons.groups_2_outlined),
                            validator: (value) {
                              if (role != 'recipient') {
                                return null;
                              }
                              if ((value ?? '').trim().isEmpty) {
                                return 'Enter the recipient type.';
                              }
                              return null;
                            },
                          ),
                        ],
                        if (role == 'hub') ...[
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: hubIdController,
                            label: 'Hub ID',
                            prefixIcon: const Icon(Icons.numbers_outlined),
                            validator: (value) {
                              if (role != 'hub') {
                                return null;
                              }
                              if ((value ?? '').trim().isEmpty) {
                                return 'Enter the hub ID.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: hubNameController,
                            label: 'Hub Name',
                            prefixIcon:
                                const Icon(Icons.storefront_outlined),
                            validator: (value) {
                              if (role != 'hub') {
                                return null;
                              }
                              if ((value ?? '').trim().isEmpty) {
                                return 'Enter the hub name.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: addressController,
                            label: 'Address',
                            prefixIcon: const Icon(Icons.place_outlined),
                            validator: (value) {
                              if (role != 'hub') {
                                return null;
                              }
                              if ((value ?? '').trim().isEmpty) {
                                return 'Enter the hub address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: operatingHoursController,
                            label: 'Operating Hours',
                            prefixIcon: const Icon(Icons.schedule_outlined),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: contactNumberController,
                            label: 'Contact Number',
                            keyboardType: TextInputType.phone,
                            prefixIcon: const Icon(Icons.call_outlined),
                          ),
                        ],
                        if (errorMessage.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.coral.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color:
                                    AppColors.coral.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              errorMessage,
                              style: const TextStyle(color: AppColors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: isSaving ? null : submit,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.night,
                          ),
                        )
                      : Icon(
                          user == null
                              ? Icons.person_add_alt_1_outlined
                              : Icons.save_outlined,
                        ),
                  label: Text(user == null ? 'Create User' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    userIdController.dispose();
    fullNameController.dispose();
    emailController.dispose();
    passwordHashController.dispose();
    phoneNumberController.dispose();
    recipientTypeController.dispose();
    hubIdController.dispose();
    hubNameController.dispose();
    addressController.dispose();
    operatingHoursController.dispose();
    contactNumberController.dispose();

    if (didSave == true) {
      await _loadUsers();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(user == null ? 'User created.' : 'User updated.'),
        ),
      );
    }
  }

  Future<void> _saveUser({
    required _ManagedUserRecord? existingUser,
    required String userId,
    required String fullName,
    required String email,
    required String passwordHash,
    required String phoneNumber,
    required String role,
    required String status,
    required String recipientType,
    required _RoleSpecificDetails hubDetails,
    required _RoleSpecificDetails existingDetails,
  }) async {
    final existingId = existingUser?.userId.trim() ?? '';
    if (existingId.isNotEmpty && existingId != userId) {
      throw Exception('User ID cannot be changed for an existing record.');
    }

    final userRef = _firestore.collection('USER').doc(userId);
    final existingDoc = await userRef.get();
    if (existingUser == null && existingDoc.exists) {
      throw Exception('A USER record with this ID already exists.');
    }

    final batch = _firestore.batch();
    final createdAt = existingUser?.createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(existingUser!.createdAt!);

    batch.set(
      userRef,
      {
        'userId': userId,
        'fullName': fullName,
        'email': email,
        'passwordHash': passwordHash,
        'phoneNumber': phoneNumber,
        'role': role,
        'status': status,
        'createdAt': createdAt,
      },
      SetOptions(merge: true),
    );

    await _syncRoleTables(
      batch: batch,
      userId: userId,
      role: role,
      status: status,
      recipientType: recipientType,
      hubDetails: hubDetails,
      existingDetails: existingDetails,
    );

    await batch.commit();
  }

  Future<void> _syncRoleTables({
    required WriteBatch batch,
    required String userId,
    required String role,
    required String status,
    required String recipientType,
    required _RoleSpecificDetails hubDetails,
    required _RoleSpecificDetails existingDetails,
  }) async {
    Future<void> deleteWhereUserId(
      String collection, {
      String? keepDocId,
    }) async {
      final snapshot = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in snapshot.docs) {
        if (keepDocId != null && doc.id == keepDocId) {
          continue;
        }
        batch.delete(doc.reference);
      }
    }

    final donorKeepDocId = role == 'donor'
        ? (existingDetails.docId.isNotEmpty ? existingDetails.docId : userId)
        : null;
    final recipientKeepDocId = role == 'recipient'
        ? (existingDetails.docId.isNotEmpty ? existingDetails.docId : userId)
        : null;
    final adminKeepDocId = role == 'admin'
        ? (existingDetails.docId.isNotEmpty ? existingDetails.docId : userId)
        : null;
    final hubKeepDocId = role == 'hub'
        ? (existingDetails.docId.isNotEmpty ? existingDetails.docId : userId)
        : null;

    await deleteWhereUserId('DONOR', keepDocId: donorKeepDocId);
    await deleteWhereUserId('RECIPIENT', keepDocId: recipientKeepDocId);
    await deleteWhereUserId('ADMIN', keepDocId: adminKeepDocId);
    await deleteWhereUserId('COMMUNITY_HUB', keepDocId: hubKeepDocId);

    switch (role) {
      case 'donor':
        batch.set(
          _firestore.collection('DONOR').doc(donorKeepDocId ?? userId),
          {
            'donorId': existingDetails.donorId.isNotEmpty
                ? existingDetails.donorId
                : userId,
            'userId': userId,
          },
          SetOptions(merge: true),
        );
        break;
      case 'recipient':
        batch.set(
          _firestore.collection('RECIPIENT').doc(recipientKeepDocId ?? userId),
          {
            'recipientId': existingDetails.recipientId.isNotEmpty
                ? existingDetails.recipientId
                : userId,
            'userId': userId,
            'recipientType': recipientType,
          },
          SetOptions(merge: true),
        );
        break;
      case 'hub':
        final hubDocId = hubKeepDocId ?? userId;
        final hubId = hubDetails.hubId.isNotEmpty
            ? hubDetails.hubId
            : (existingDetails.hubId.isNotEmpty
                ? existingDetails.hubId
                : userId);
        batch.set(
          _firestore.collection('COMMUNITY_HUB').doc(hubDocId),
          {
            'hubId': hubId,
            'userId': userId,
            'hubName': hubDetails.hubName,
            'address': hubDetails.address,
            'operatingHours': hubDetails.operatingHours,
            'contactNumber': hubDetails.contactNumber,
            'status': status,
          },
          SetOptions(merge: true),
        );
        break;
      case 'admin':
        batch.set(
          _firestore.collection('ADMIN').doc(adminKeepDocId ?? userId),
          {
            'adminId': existingDetails.adminId.isNotEmpty
                ? existingDetails.adminId
                : userId,
            'userId': userId,
          },
          SetOptions(merge: true),
        );
        break;
    }
  }

  Future<void> _confirmDelete(_ManagedUserRecord user) async {
    if (_auth.currentUser?.uid == user.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The signed-in admin cannot delete their own record.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.forest,
          title: const Text('Delete user'),
          content: Text(
            'Delete ${user.fullName} and their role-link records from USER, ${_roleTableLabel(user.role)}? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _cascadeDeleteUser(user);

      if (!mounted) {
        return;
      }
      await _loadUsers();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete user: $error')),
      );
    }
  }

  Future<void> _cascadeDeleteUser(_ManagedUserRecord user) async {
    final operations = <DocumentReference<Object?>>[];
    final updates = <MapEntry<DocumentReference<Object?>, Map<String, dynamic>>>[];

    void addDelete(DocumentReference<Object?> ref) {
      operations.add(ref);
    }

    void addUpdate(
      DocumentReference<Object?> ref,
      Map<String, dynamic> data,
    ) {
      updates.add(MapEntry(ref, data));
    }

    addUpdate(
      _firestore.collection('USER').doc(user.userId),
      {
        'status': 'deleted',
      },
    );

    Future<void> addCollectionDeletes(
      String collection,
      String field,
      String value,
    ) async {
      final snapshot = await _firestore
          .collection(collection)
          .where(field, isEqualTo: value)
          .get();
      for (final doc in snapshot.docs) {
        addDelete(doc.reference);
      }
    }

    await addCollectionDeletes('DONOR', 'userId', user.userId);
    await addCollectionDeletes('RECIPIENT', 'userId', user.userId);
    await addCollectionDeletes('ADMIN', 'userId', user.userId);

    final hubSnapshot = await _firestore
        .collection('COMMUNITY_HUB')
        .where('userId', isEqualTo: user.userId)
        .get();
    final hubIds = <String>{};
    for (final doc in hubSnapshot.docs) {
      final data = doc.data();
      hubIds.add(_stringValue(data['hubId'], fallback: doc.id));
      addDelete(doc.reference);
    }

    await addCollectionDeletes('ITEM_LISTING', 'donorId', user.userId);
    await addCollectionDeletes('REPORT', 'reporterUserId', user.userId);
    await addCollectionDeletes('REPORT', 'reportedUserId', user.userId);
    await addCollectionDeletes(
      'DONATION_STATUS_HISTORY',
      'changedByUserId',
      user.userId,
    );

    final recipientRequestSnapshot = await _firestore
        .collection('ITEM_REQUEST')
        .where('recipientId', isEqualTo: user.userId)
        .get();
    for (final doc in recipientRequestSnapshot.docs) {
      addDelete(doc.reference);
      final requestId = _stringValue(doc.data()['requestId'], fallback: doc.id);
      await addCollectionDeletes('HANDOVER', 'requestId', requestId);
      await addCollectionDeletes(
        'DONATION_STATUS_HISTORY',
        'requestId',
        requestId,
      );
    }

    for (final hubId in hubIds) {
      final requestSnapshot = await _firestore
          .collection('ITEM_REQUEST')
          .where('hubId', isEqualTo: hubId)
          .get();
      for (final doc in requestSnapshot.docs) {
        addDelete(doc.reference);
        final requestId =
            _stringValue(doc.data()['requestId'], fallback: doc.id);
        await addCollectionDeletes('HANDOVER', 'requestId', requestId);
        await addCollectionDeletes(
          'DONATION_STATUS_HISTORY',
          'requestId',
          requestId,
        );
      }

      await addCollectionDeletes('HANDOVER', 'hubId', hubId);
      await addCollectionDeletes('ITEM_REQUEST', 'hubId', hubId);
    }

    await _commitDeleteOperations(operations, updates);
  }

  Future<void> _commitDeleteOperations(
    List<DocumentReference<Object?>> operations,
    List<MapEntry<DocumentReference<Object?>, Map<String, dynamic>>> updates,
  ) async {
    const batchLimit = 450;

    if (updates.isNotEmpty) {
      final batch = _firestore.batch();
      for (final entry in updates) {
        batch.set(entry.key, entry.value, SetOptions(merge: true));
      }
      await batch.commit();
    }

    for (var i = 0; i < operations.length; i += batchLimit) {
      final batch = _firestore.batch();
      for (final ref in operations.skip(i).take(batchLimit)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  Future<void> _showUserDetails(_ManagedUserRecord user) async {
    final details = await _loadRoleSpecificDetails(user.userId, user.role);
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.forest,
          title: Text(user.fullName),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailLine('User ID', user.userId),
                _detailLine('Email', user.email),
                _detailLine('Phone', user.phoneNumber),
                _detailLine('Role', _titleCase(user.role)),
                _detailLine('Status', _titleCase(user.status)),
                _detailLine(
                  'Created',
                  user.createdAt == null
                      ? 'Not available'
                      : DateFormat('MMM d, yyyy').format(user.createdAt!),
                ),
                if (user.passwordHash.isNotEmpty)
                  _detailLine('Password Hash', user.passwordHash),
                if (user.role == 'recipient')
                  _detailLine('Recipient Type', details.recipientType),
                if (user.role == 'hub') ...[
                  _detailLine('Hub ID', details.hubId),
                  _detailLine('Hub Name', details.hubName),
                  _detailLine('Address', details.address),
                  _detailLine('Operating Hours', details.operatingHours),
                  _detailLine('Contact Number', details.contactNumber),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await _openUserEditor(user: user);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.sand,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? 'Not provided' : value,
            style: const TextStyle(color: AppColors.mist, height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingState(message: 'Loading users...');
    }

    if (_errorMessage.isNotEmpty) {
      return AppErrorState(
        message: _errorMessage,
        onRetry: _loadUsers,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUserEditor,
        backgroundColor: AppColors.mint,
        foregroundColor: AppColors.night,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add User'),
      ),
      body: RefreshIndicator(
        color: AppColors.mint,
        onRefresh: _loadUsers,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            120,
          ),
          children: [
            AppTextField(
              controller: _searchController,
              label: 'Search users',
              hint: 'Search by name, email, phone, or user ID',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => _searchController.clear(),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _roles.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _FilterChipButton(
                      label: 'All Roles',
                      selected: _roleFilter == 'all',
                      onTap: () {
                        _roleFilter = 'all';
                        _applyFilters();
                      },
                    );
                  }
                  final role = _roles[index - 1];
                  return _FilterChipButton(
                    label: _titleCase(role),
                    selected: _roleFilter == role,
                    onTap: () {
                      _roleFilter = role;
                      _applyFilters();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _statuses.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _FilterChipButton(
                      label: 'All Statuses',
                      selected: _statusFilter == 'all',
                      onTap: () {
                        _statusFilter = 'all';
                        _applyFilters();
                      },
                    );
                  }
                  final status = _statuses[index - 1];
                  return _FilterChipButton(
                    label: _titleCase(status),
                    selected: _statusFilter == status,
                    onTap: () {
                      _statusFilter = status;
                      _applyFilters();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_filteredUsers.isEmpty)
              const AppEmptyState(
                icon: Icons.group_off_outlined,
                title: 'No users found',
                message:
                    'Adjust your search or filters, or create a new USER record.',
              )
            else
              ..._filteredUsers.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () => _showUserDetails(user),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.night.withValues(alpha: 0.35),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline_rounded,
                                    color: AppColors.mint,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.fullName.isNotEmpty
                                            ? user.fullName
                                            : user.userId,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email.isNotEmpty
                                            ? user.email
                                            : 'No email provided',
                                        style: const TextStyle(
                                          color: AppColors.mist,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'User ID: ${user.userId}',
                                        style: const TextStyle(
                                          color: AppColors.sand,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  color: AppColors.forest,
                                  onSelected: (value) async {
                                    switch (value) {
                                      case 'view':
                                        await _showUserDetails(user);
                                        break;
                                      case 'edit':
                                        await _openUserEditor(user: user);
                                        break;
                                      case 'delete':
                                        await _confirmDelete(user);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem<String>(
                                      value: 'view',
                                      child: Text('View details'),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Text('Edit user'),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('Delete user'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                _InfoPill(
                                  icon: Icons.admin_panel_settings_outlined,
                                  label: _titleCase(user.role),
                                ),
                                _InfoPill(
                                  icon: Icons.toggle_on_outlined,
                                  label: _titleCase(user.status),
                                ),
                                if (user.phoneNumber.isNotEmpty)
                                  _InfoPill(
                                    icon: Icons.phone_outlined,
                                    label: user.phoneNumber,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ManagedUserRecord {
  const _ManagedUserRecord({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.passwordHash,
    required this.phoneNumber,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  factory _ManagedUserRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _ManagedUserRecord(
      userId: _stringValue(data['userId'], fallback: doc.id),
      fullName: _stringValue(data['fullName']),
      email: _stringValue(data['email']),
      passwordHash: _stringValue(data['passwordHash']),
      phoneNumber: _stringValue(data['phoneNumber']),
      role: _stringValue(data['role'], fallback: 'recipient'),
      status: _stringValue(data['status'], fallback: 'active'),
      createdAt: _readDateTime(data['createdAt']),
    );
  }

  final String userId;
  final String fullName;
  final String email;
  final String passwordHash;
  final String phoneNumber;
  final String role;
  final String status;
  final DateTime? createdAt;
}

class _RoleSpecificDetails {
  const _RoleSpecificDetails({
    this.docId = '',
    this.donorId = '',
    this.recipientId = '',
    this.recipientType = '',
    this.hubId = '',
    this.hubName = '',
    this.address = '',
    this.operatingHours = '',
    this.contactNumber = '',
    this.status = '',
    this.adminId = '',
  });

  final String docId;
  final String donorId;
  final String recipientId;
  final String recipientType;
  final String hubId;
  final String hubName;
  final String address;
  final String operatingHours;
  final String contactNumber;
  final String status;
  final String adminId;
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      label: Text(label),
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.forest,
      selectedColor: AppColors.mint.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        color: selected ? AppColors.mint : AppColors.sand,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? AppColors.mint : AppColors.pine,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.night.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.pine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.mint),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

DateTime? _readDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

String _stringValue(dynamic value, {String fallback = ''}) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

String _titleCase(String value) {
  if (value.trim().isEmpty) {
    return value;
  }

  return value
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}

String _roleTableLabel(String role) {
  switch (role) {
    case 'donor':
      return 'DONOR';
    case 'recipient':
      return 'RECIPIENT';
    case 'hub':
      return 'COMMUNITY_HUB';
    case 'admin':
      return 'ADMIN';
    default:
      return 'role table';
  }
}
