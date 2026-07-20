import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../widgets/state_widgets.dart';
import '../hub/hub_operating_schedule.dart';
import 'donor_incoming_requests_page.dart';

class DonorSelectHandoverPointPage extends StatefulWidget {
  const DonorSelectHandoverPointPage({super.key, required this.request});

  final DonorIncomingRequestRecord request;

  @override
  State<DonorSelectHandoverPointPage> createState() =>
      _DonorSelectHandoverPointPageState();
}

class _DonorSelectHandoverPointPageState
    extends State<DonorSelectHandoverPointPage> {
  final Random _random = Random();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  String _errorMessage = '';
  String? _selectedHubId;
  String _handoverType = 'community_hub_pickup';
  String _requestStatus = '';
  String _handoverStatus = '';
  String? _handoverDocId;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final requestSnapshot =
          await _firestore
              .collection('ITEM_REQUEST')
              .doc(widget.request.docId)
              .get();
      final handoverSnapshot =
          await _firestore
              .collection('HANDOVER')
              .where('requestId', isEqualTo: widget.request.requestId)
              .limit(1)
              .get();
      final hubSnapshot = await _firestore.collection('COMMUNITY_HUB').get();

      final requestData = requestSnapshot.data() ?? const <String, dynamic>{};
      final handoverDoc =
          handoverSnapshot.docs.isNotEmpty ? handoverSnapshot.docs.first : null;
      final handoverData = handoverDoc?.data() ?? const <String, dynamic>{};
      final hubsById = <String, _CommunityHubRecord>{};
      for (final doc in hubSnapshot.docs) {
        final hub = _CommunityHubRecord.fromFirestore(doc.id, doc.data());
        hubsById.putIfAbsent(hub.hubId, () => hub);
      }

      final existingHubId =
          handoverData['hubId']?.toString().trim().isNotEmpty == true
              ? handoverData['hubId'].toString().trim()
              : requestData['hubId']?.toString().trim().isNotEmpty == true
              ? requestData['hubId'].toString().trim()
              : widget.request.hubId;
      final requestedHandoverType =
          handoverData['handoverType']?.toString().trim().isNotEmpty == true
              ? handoverData['handoverType'].toString().trim()
              : requestData['handoverType']?.toString().trim().isNotEmpty ==
                  true
              ? requestData['handoverType'].toString().trim()
              : widget.request.handoverType;
      final resolvedHandoverType =
          requestedHandoverType.isNotEmpty
              ? requestedHandoverType
              : (existingHubId.isNotEmpty
                  ? 'community_hub_pickup'
                  : 'independent_pickup');

      if (!mounted) {
        return;
      }

      setState(() {
        _requestStatus =
            requestData['requestStatus']?.toString().trim() ??
            widget.request.requestStatus;
        _handoverStatus =
            handoverData['handoverStatus']?.toString().trim() ?? '';
        _handoverDocId = handoverDoc?.id;
        _handoverType = resolvedHandoverType;
        _selectedHubId =
            resolvedHandoverType == 'community_hub_pickup' &&
                    hubsById.containsKey(existingHubId)
                ? existingHubId
                : null;
        _isEditing = handoverDoc != null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load handover options: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveHandover() async {
    final donorId = _auth.currentUser?.uid;
    if (donorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to sign in before saving a handover.'),
        ),
      );
      return;
    }

    if (!_canSaveHandover()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This handover can no longer be changed.'),
        ),
      );
      return;
    }

    if (_requestStatus.toLowerCase() == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Approve the request before scheduling handover.'),
        ),
      );
      return;
    }

    final requiresHub = _handoverType == 'community_hub_pickup';
    if (requiresHub && (_selectedHubId == null || _selectedHubId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No preferred community hub is set. Reject the request if you do not want to continue.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final deliveryStatus =
          _handoverType == 'community_hub_pickup'
              ? 'delivering_to_hub'
              : 'delivering_to_recipient';
      final batch = _firestore.batch();
      final requestRef = _firestore
          .collection('ITEM_REQUEST')
          .doc(widget.request.docId);
      batch.update(requestRef, {
        'handoverType': _handoverType,
        'hubId': requiresHub ? _selectedHubId : null,
        'hubName': requiresHub ? widget.request.hubName : null,
        'requestStatus': deliveryStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (widget.request.itemDocId.isNotEmpty) {
        final itemRef = _firestore
            .collection('ITEM_LISTING')
            .doc(widget.request.itemDocId);
        batch.update(itemRef, {'availabilityStatus': 'reserved'});
      }

      final handoverId = _handoverDocId ?? _generateHandoverId();
      final handoverRef = _firestore.collection('HANDOVER').doc(handoverId);
      batch.set(handoverRef, {
        'handoverId': handoverId,
        'requestId': widget.request.requestId,
        'hubId': requiresHub ? _selectedHubId : null,
        'handoverType': _handoverType,
        'handoverStatus': deliveryStatus,
        'completedAt': null,
      }, SetOptions(merge: true));

      final latestHistorySnapshot =
          await _firestore
              .collection('DONATION_STATUS_HISTORY')
              .where('requestId', isEqualTo: widget.request.requestId)
              .orderBy('changedAt', descending: true)
              .limit(1)
              .get();
      final latestStatus =
          latestHistorySnapshot.docs.isNotEmpty
              ? latestHistorySnapshot.docs.first
                  .data()['status']
                  ?.toString()
                  .trim()
                  .toLowerCase()
              : '';
      if (latestStatus != deliveryStatus.toLowerCase()) {
        final historyId = _generateHistoryId();
        final historyRef = _firestore
            .collection('DONATION_STATUS_HISTORY')
            .doc(historyId);
        batch.set(historyRef, {
          'statusHistoryId': historyId,
          'requestId': widget.request.requestId,
          'status': deliveryStatus,
          'changedAt': FieldValue.serverTimestamp(),
          'changedByUserId': donorId,
        });
      }

      await batch.commit();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Handover confirmed.')));
      setState(() {
        _handoverDocId = handoverId;
        _isEditing = true;
        _handoverStatus = deliveryStatus;
        _requestStatus = deliveryStatus;
        _isSaving = false;
      });
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to confirm handover: $error')),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _cancelHandover() async {
    final donorId = _auth.currentUser?.uid;
    if (donorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to sign in before canceling a handover.'),
        ),
      );
      return;
    }

    if (!_canCancelHandover()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This handover can no longer be canceled.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_isEditing ? 'Cancel handover?' : 'Reject request?'),
            content: const Text(
              'This will reject the request and delete the handover tracking records.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(_isEditing ? 'Keep' : 'Keep request'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(_isEditing ? 'Cancel handover' : 'Reject request'),
              ),
            ],
          ),
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final batch = _firestore.batch();
      final requestRef = _firestore
          .collection('ITEM_REQUEST')
          .doc(widget.request.docId);
      final nextRequestStatus = _isEditing ? 'cancelled' : 'rejected';
      batch.update(requestRef, {
        'requestStatus': nextRequestStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final itemRef = await _resolveItemRef();
      if (itemRef != null) {
        batch.update(itemRef, {'availabilityStatus': 'available'});
      }

      final handoverSnapshot =
          await _firestore
              .collection('HANDOVER')
              .where('requestId', isEqualTo: widget.request.requestId)
              .get();
      for (final doc in handoverSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final historySnapshot =
          await _firestore
              .collection('DONATION_STATUS_HISTORY')
              .where('requestId', isEqualTo: widget.request.requestId)
              .get();
      for (final doc in historySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Handover canceled.' : 'Request rejected.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to cancel handover: $error')),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          title: const SizedBox.shrink(),
        ),
        body: const AppLoadingState(message: 'Loading handover setup...'),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          title: const SizedBox.shrink(),
        ),
        body: AppErrorState(message: _errorMessage, onRetry: _loadPage),
      );
    }

    final canCancelHandover = _canCancelHandover();
    final canSaveHandover =
        _canSaveHandover() &&
        !(_handoverType == 'community_hub_pickup' &&
            (_selectedHubId == null || _selectedHubId!.isEmpty));
    final isDeliveryLocked = _isDeliveryLocked();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _PlannerHero(
            request: widget.request,
            requestStatus: _requestStatus,
            handoverType: _handoverType,
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Handover Setup',
            subtitle:
                _handoverType == 'community_hub_pickup'
                    ? 'The recipient selected community hub pickup for this request.'
                    : 'The recipient selected independent pickup for this request.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LockedMethodCard(
                  handoverType: _handoverType,
                  hubName: widget.request.hubName,
                  hubId: widget.request.hubId,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isSaving || !canCancelHandover ? null : _cancelHandover,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.coral,
                    side: const BorderSide(color: AppColors.coral),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    _isEditing ? 'Cancel Handover' : 'Reject Request',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _isSaving || !canSaveHandover ? null : _saveHandover,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  child:
                      _isSaving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.night,
                            ),
                          )
                          : Text(
                            isDeliveryLocked || _isEditing
                                ? 'Handover Confirmed'
                                : 'Confirm Handover',
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateHandoverId() {
    final digits = List.generate(13, (_) => _random.nextInt(10)).join();
    return 'handover_$digits';
  }

  String _generateHistoryId() {
    final digits = List.generate(13, (_) => _random.nextInt(10)).join();
    return 'history_$digits';
  }

  Future<DocumentReference<Map<String, dynamic>>?> _resolveItemRef() async {
    if (widget.request.itemDocId.isNotEmpty) {
      return _firestore
          .collection('ITEM_LISTING')
          .doc(widget.request.itemDocId);
    }

    if (widget.request.itemId.isEmpty) {
      return null;
    }

    final snapshot =
        await _firestore
            .collection('ITEM_LISTING')
            .where('itemId', isEqualTo: widget.request.itemId)
            .limit(1)
            .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return snapshot.docs.first.reference;
  }

  bool _isIndependentClaimed() {
    return _handoverType == 'independent_pickup' &&
        (_requestStatus.toLowerCase() == 'completed' ||
            _handoverStatus.toLowerCase() == 'completed');
  }

  bool _hasHubReceivedItem() {
    return _handoverType == 'community_hub_pickup' &&
        (_handoverStatus.toLowerCase() == 'item_at_community_hub' ||
            _handoverStatus.toLowerCase() == 'completed' ||
            _requestStatus.toLowerCase() == 'completed');
  }

  bool _canCancelHandover() {
    if (_isIndependentClaimed()) {
      return false;
    }
    if (_hasHubReceivedItem()) {
      return false;
    }
    return true;
  }

  bool _canSaveHandover() {
    if (_isEditing) {
      return false;
    }
    if (_isDeliveryLocked()) {
      return false;
    }
    if (_isIndependentClaimed()) {
      return false;
    }
    if (_hasHubReceivedItem()) {
      return false;
    }
    return true;
  }

  bool _isDeliveryLocked() {
    final requestStatus = _requestStatus.toLowerCase();
    final handoverStatus = _handoverStatus.toLowerCase();
    return _isEditing &&
        ((_handoverType == 'independent_pickup' &&
                (requestStatus == 'delivering_to_recipient' ||
                    handoverStatus == 'delivering_to_recipient')) ||
            (_handoverType == 'community_hub_pickup' &&
                (requestStatus == 'delivering_to_hub' ||
                    handoverStatus == 'delivering_to_hub')));
  }
}

class _CommunityHubRecord {
  const _CommunityHubRecord({
    required this.hubId,
    required this.hubName,
    required this.address,
    required this.operatingHours,
    required this.contactNumber,
    required this.status,
  });

  final String hubId;
  final String hubName;
  final String address;
  final String operatingHours;
  final String contactNumber;
  final String status;

  factory _CommunityHubRecord.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    return _CommunityHubRecord(
      hubId:
          data['hubId']?.toString().trim().isNotEmpty == true
              ? data['hubId'].toString().trim()
              : docId,
      hubName:
          data['hubName']?.toString().trim().isNotEmpty == true
              ? data['hubName'].toString().trim()
              : 'Community Hub',
      address: data['address']?.toString().trim() ?? 'Address not provided',
      operatingHours: _resolveOperatingHours(data),
      contactNumber:
          data['contactNumber']?.toString().trim() ?? 'Contact not provided',
      status: data['status']?.toString().trim() ?? 'inactive',
    );
  }

  static String _resolveOperatingHours(Map<String, dynamic> data) {
    final operatingHours = formatCommunityHubOperatingHours(data);
    return operatingHours.isNotEmpty ? operatingHours : 'Hours not provided';
  }
}

class _PlannerHero extends StatelessWidget {
  const _PlannerHero({
    required this.request,
    required this.requestStatus,
    required this.handoverType,
  });

  final DonorIncomingRequestRecord request;
  final String requestStatus;
  final String handoverType;

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
            'HANDOVER PLANNING',
            style: TextStyle(
              color: AppColors.sand,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            request.itemTitle,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Recipient: ${request.recipientName}',
            style: const TextStyle(color: AppColors.sand),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _StatusChip(
                label: titleCaseLabel(requestStatus),
                color: requestStatusColor(requestStatus),
              ),
              _StatusChip(
                label: titleCaseLabel(handoverType),
                color: AppColors.sun,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Review the selected handover method and continue the delivery flow.',
            style: TextStyle(color: AppColors.white, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.mist, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _LockedMethodCard extends StatelessWidget {
  const _LockedMethodCard({
    required this.handoverType,
    required this.hubName,
    required this.hubId,
  });

  final String handoverType;
  final String hubName;
  final String hubId;

  @override
  Widget build(BuildContext context) {
    final isCommunityHub = handoverType == 'community_hub_pickup';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.pine.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.mint.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCommunityHub ? 'Selected Community Hub' : 'Selected Method',
            style: const TextStyle(
              color: AppColors.sand,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isCommunityHub
                ? (hubName.isNotEmpty ? hubName : 'Community Hub')
                : 'Independent Pickup',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isCommunityHub
                ? (hubId.isNotEmpty
                    ? 'Hub ID: $hubId'
                    : 'The donor-configured hub will be used for this handover.')
                : 'The donor and recipient will handle the handover on their own using the provided phone number and address, outside of the platform.',
            style: const TextStyle(color: AppColors.mist, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

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
