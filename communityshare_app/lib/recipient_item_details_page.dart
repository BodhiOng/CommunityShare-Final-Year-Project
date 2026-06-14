// ignore_for_file: use_build_context_synchronously

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'models/item_listing.dart';
import 'utils/image_utils.dart';
import 'widgets/state_widgets.dart';

class RecipientItemDetailsPage extends StatefulWidget {
  const RecipientItemDetailsPage({
    super.key,
    required this.item,
  });

  final ItemListing item;

  @override
  State<RecipientItemDetailsPage> createState() =>
      _RecipientItemDetailsPageState();
}

class _RecipientItemDetailsPageState extends State<RecipientItemDetailsPage> {
  static final Random _random = Random.secure();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _requestNoteController = TextEditingController();
  final TextEditingController _manualHubController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingDonor = true;
  bool _isLoadingHubs = true;
  Map<String, dynamic>? _donorData;
  List<_HubOption> _hubOptions = const [];
  String? _selectedHubId;

  @override
  void initState() {
    super.initState();
    _loadDonor();
    _loadHubOptions();
  }

  @override
  void dispose() {
    _requestNoteController.dispose();
    _manualHubController.dispose();
    super.dispose();
  }

  Future<void> _loadDonor() async {
    try {
      final userDoc = await _firestore.collection('USER').doc(widget.item.donorId).get();
      final legacyDoc =
          await _firestore.collection('users').doc(widget.item.donorId).get();
      final data = <String, dynamic>{
        ...?legacyDoc.data(),
        ...?userDoc.data(),
      };

      if (!mounted) {
        return;
      }

      setState(() {
        _donorData = data;
        _isLoadingDonor = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingDonor = false;
      });
    }
  }

  Future<void> _loadHubOptions() async {
    try {
      final legacySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'hub')
          .limit(25)
          .get();
      final userSnapshot = await _firestore
          .collection('USER')
          .where('role', isEqualTo: 'hub')
          .limit(25)
          .get();

      final hubs = {
        for (final doc in legacySnapshot.docs) doc.id: _HubOption(
          id: doc.id,
          name: _displayNameForHub(doc.data()),
        ),
        for (final doc in userSnapshot.docs) doc.id: _HubOption(
          id: doc.id,
          name: _displayNameForHub(doc.data()),
        ),
      }.values
          .map(
            (hub) => hub,
          )
          .toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _hubOptions = hubs;
        _selectedHubId = hubs.isNotEmpty ? hubs.first.id : null;
        _isLoadingHubs = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingHubs = false;
      });
    }
  }

  Future<bool> _submitRequest() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to sign in before requesting an item.')),
      );
      return false;
    }

    if (!widget.item.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This listing is not available for requests.')),
      );
      return false;
    }

    final hubId = _selectedHubId?.trim().isNotEmpty == true
        ? _selectedHubId!.trim()
        : _manualHubController.text.trim();
    final requestNote = _requestNoteController.text.trim();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final existing = await _firestore
          .collection('ITEM_REQUEST')
          .where('itemId', isEqualTo: widget.item.itemId)
          .where('recipientId', isEqualTo: user.uid)
          .limit(10)
          .get();

      final hasActiveRequest = existing.docs.any((doc) {
        final data = doc.data();
        final status = (data['requestStatus'] as String? ?? '').toLowerCase();
        return status != 'cancelled' &&
            status != 'rejected' &&
            status != 'completed';
      });

      if (hasActiveRequest) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You already have an active request for this item.'),
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return false;
      }

      final requestId = _newRequestId();
      final payload = <String, dynamic>{
        'requestId': requestId,
        'itemId': widget.item.itemId,
        'recipientId': user.uid,
        'requestStatus': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (hubId.isNotEmpty) {
        payload['hubId'] = hubId;
      }

      if (requestNote.isNotEmpty) {
        payload['requestNote'] = requestNote;
      }

      await _firestore.collection('ITEM_REQUEST').doc(requestId).set(payload);

      if (!mounted) {
        return false;
      }

      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted. The donor can review it now.')),
      );
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit request: $e')),
      );
      setState(() {
        _isSubmitting = false;
      });
      return false;
    }
  }

  String _newRequestId() {
    final digits = 100000000 + _random.nextInt(900000000);
    return 'req_$digits';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ImageUtils.base64ToImage(
              item.photoUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: Container(
                color: AppColors.forest,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 54,
                    color: AppColors.mint,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _DetailPill(
                      label: item.category,
                      color: AppColors.pine,
                    ),
                    _DetailPill(
                      label: item.isAvailable
                          ? 'Available'
                          : item.availabilityStatus,
                      color: item.isAvailable ? AppColors.mint : AppColors.coral,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        _DetailRow(
                          label: 'Condition',
                          value: item.condition,
                        ),
                        _DetailRow(
                          label: 'Quantity',
                          value: '${item.quantity}',
                        ),
                        _DetailRow(
                          label: 'Listed',
                          value: _formatDate(item.createdAt),
                        ),
                        if (item.category.toLowerCase() == 'consumables')
                          _DetailRow(
                            label: 'Expiry',
                            value: _formatDate(item.expiryDate),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: AppColors.mist,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Donor',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_isLoadingDonor)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: AppLoadingState(message: 'Loading donor details...'),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipOval(
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: _donorProfileImage(),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _donorDisplayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      _donorLocation,
                                      style: const TextStyle(color: AppColors.mist),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_donorBio.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _donorBio,
                              style: const TextStyle(
                                color: AppColors.mist,
                                height: 1.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              _DetailPill(label: _donorRoleLabel, color: AppColors.pine),
                              _DetailPill(label: _donorPhoneLabel, color: AppColors.forest),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (item.category.toLowerCase() == 'consumables' &&
                    item.isExpired) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const AppErrorState(
                    message: 'This item is past its expiry date and cannot be requested.',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        color: AppColors.night,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: item.isAvailable ? _showRequestSheet : null,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.volunteer_activism_outlined),
              label: Text(item.isAvailable ? 'Request Item' : 'Not Requestable'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRequestSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.forest,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request ${widget.item.title}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Send a request, tied to a pickup hub or independent. You can also add a note on why you wanted the item',
                      style: TextStyle(color: AppColors.mist, height: 1.5),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_isLoadingHubs)
                      const AppLoadingState(message: 'Loading pickup hubs...')
                    else if (_hubOptions.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedHubId,
                        decoration: const InputDecoration(
                          labelText: 'Pickup hub',
                        ),
                        items: _hubOptions
                            .map(
                              (hub) => DropdownMenuItem<String>(
                                value: hub.id,
                                child: Text(hub.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setSheetState(() {
                            _selectedHubId = value;
                            _manualHubController.clear();
                          });
                        },
                      ),
                    ] else ...[
                      TextField(
                        controller: _manualHubController,
                        decoration: const InputDecoration(
                          labelText: 'Hub ID (optional)',
                          helperText:
                              'Optional. Leave blank if you do not want to link a hub.',
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _requestNoteController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Request note (optional)',
                        hintText: 'Add a note, or leave this blank.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                final success = await _submitRequest();
                                if (success && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                        child: Text(
                          _isSubmitting ? 'Submitting...' : 'Submit request',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Not set';
    }
    return DateFormat('MMM d, yyyy').format(value);
  }

  String get _donorDisplayName {
    final fullName = (_donorData?['fullName'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final displayName = (_donorData?['displayName'] as String?)?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final username = (_donorData?['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) {
      return username;
    }

    return widget.item.donorId;
  }

  String get _donorBio {
    final bio = (_donorData?['bio'] as String?)?.trim();
    if (bio != null && bio.isNotEmpty) {
      return bio;
    }

    return '';
  }

  String get _donorLocation {
    final city = (_donorData?['city'] as String?)?.trim();
    final state = (_donorData?['state'] as String?)?.trim();
    final country = (_donorData?['country'] as String?)?.trim();
    final parts = <String>[
      if (city != null && city.isNotEmpty) city,
      if (state != null && state.isNotEmpty) state,
      if (country != null && country.isNotEmpty) country,
    ];

    if (parts.isEmpty) {
      return 'Location not provided';
    }

    return parts.join(', ');
  }

  String get _donorPhoneLabel {
    final phone = (_donorData?['phoneNumber'] as String?)?.trim();
    final phoneCode = (_donorData?['phoneCountryCode'] as String?)?.trim();
    final localPhone = (_donorData?['phoneLocalNumber'] as String?)?.trim();

    if (phone != null && phone.isNotEmpty) {
      return phone;
    }

    final combined = [
      if (phoneCode != null && phoneCode.isNotEmpty) phoneCode,
      if (localPhone != null && localPhone.isNotEmpty) localPhone,
    ].join(' ').trim();

    if (combined.isNotEmpty) {
      return combined;
    }

    return 'Phone not provided';
  }

  String get _donorRoleLabel {
    final role = (_donorData?['role'] as String?)?.trim();
    if (role != null && role.isNotEmpty) {
      return role.toUpperCase();
    }

    return 'DONOR';
  }

  Widget _donorProfileImage() {
    final source = (_donorData?['profileImageUrl'] as String?)?.trim() ?? '';
    if (source.isNotEmpty) {
      return ImageUtils.base64ToImage(
        source,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: Container(
          color: AppColors.forest,
          alignment: Alignment.center,
          child: const Icon(
            Icons.person_outline_rounded,
            color: AppColors.sand,
            size: 28,
          ),
        ),
      );
    }

    return Container(
      color: AppColors.forest,
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_outline_rounded,
        color: AppColors.sand,
        size: 28,
      ),
    );
  }

  String _displayNameForHub(Map<String, dynamic> data) {
    final displayName = (data['displayName'] as String?)?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final username = (data['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) {
      return username;
    }

    final name = (data['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    return 'Community hub';
  }
}

class _HubOption {
  const _HubOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == AppColors.pine ? AppColors.sand : color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.mint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.mist),
            ),
          ),
        ],
      ),
    );
  }
}
