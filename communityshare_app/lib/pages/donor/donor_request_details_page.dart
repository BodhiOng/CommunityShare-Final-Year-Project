import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import 'donor_donation_status_tracking_page.dart';
import 'donor_incoming_requests_page.dart';
import 'donor_select_handover_point_page.dart';
import '../../utils/image_utils.dart';

class DonorRequestDetailsPage extends StatefulWidget {
  const DonorRequestDetailsPage({super.key, required this.request});

  final DonorIncomingRequestRecord request;

  @override
  State<DonorRequestDetailsPage> createState() =>
      _DonorRequestDetailsPageState();
}

class _DonorRequestDetailsPageState extends State<DonorRequestDetailsPage> {
  static final Random _random = Random.secure();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isUpdating = false;
  late String _requestStatus;
  late String _availabilityStatus;

  @override
  void initState() {
    super.initState();
    _requestStatus = widget.request.requestStatus;
    _availabilityStatus = widget.request.availabilityStatus;
  }

  Future<void> _updateRequestStatus(String nextStatus) async {
    final donorId = _auth.currentUser?.uid;
    if (donorId == null) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final request = widget.request;
      final batch = _firestore.batch();
      final requestRef = _firestore
          .collection('ITEM_REQUEST')
          .doc(request.docId);

      batch.update(requestRef, {
        'requestStatus': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (request.itemDocId.isNotEmpty) {
        final itemRef = _firestore
            .collection('ITEM_LISTING')
            .doc(request.itemDocId);
        batch.update(itemRef, {
          'availabilityStatus':
              nextStatus == 'approved' ? 'reserved' : 'available',
        });
      }

      if (nextStatus == 'approved') {
        final historyId = _newHistoryId();
        final historyRef = _firestore
            .collection('DONATION_STATUS_HISTORY')
            .doc(historyId);
        batch.set(historyRef, {
          'statusHistoryId': historyId,
          'requestId': request.requestId,
          'status': 'approved',
          'changedAt': FieldValue.serverTimestamp(),
          'changedByUserId': donorId,
        });
      }

      if (nextStatus == 'approved') {
        final relatedSnapshot =
            await _firestore
                .collection('ITEM_REQUEST')
                .where('itemId', isEqualTo: request.itemId)
                .where('requestStatus', isEqualTo: 'pending')
                .get();

        for (final doc in relatedSnapshot.docs) {
          if (doc.id == request.docId) {
            continue;
          }

          batch.update(doc.reference, {
            'requestStatus': 'rejected',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      if (!mounted) {
        return;
      }

      setState(() {
        _requestStatus = nextStatus;
        _availabilityStatus =
            nextStatus == 'approved' ? 'reserved' : 'available';
        _isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextStatus == 'approved'
                ? 'Request approved.'
                : 'Request rejected.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update request: $error')),
      );
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final canDecide = _requestStatus.toLowerCase() == 'pending';
    final canSelectHandover = _canSelectHandover(_requestStatus);
    final canShowRecipientContact =
        request.handoverType == 'independent_pickup' &&
        _requestStatus.toLowerCase() != 'pending' &&
        _requestStatus.toLowerCase() != 'rejected' &&
        _requestStatus.toLowerCase() != 'cancelled' &&
        _requestStatus.toLowerCase() != 'completed';

    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child:
                          request.itemPhotoUrl.isNotEmpty
                              ? ImageUtils.base64ToImage(
                                request.itemPhotoUrl,
                                fit: BoxFit.cover,
                                errorWidget: _itemImageFallback(),
                              )
                              : _itemImageFallback(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.itemTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Request ID: ${request.requestId}',
                          style: const TextStyle(color: AppColors.mist),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _RequestChip(
                              label: titleCaseLabel(request.itemCategory),
                              color: AppColors.pine,
                            ),
                            _RequestChip(
                              label: titleCaseLabel(_requestStatus),
                              color: requestStatusColor(_requestStatus),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _InfoRow(label: 'Recipient', value: request.recipientName),
                  if (canShowRecipientContact)
                    _InfoRow(
                      label: 'Recipient Phone',
                      value: request.recipientPhone,
                    ),
                  if (canShowRecipientContact)
                    _InfoRow(label: 'Address', value: request.recipientAddress),
                  _InfoRow(
                    label: 'Selected Method',
                    value:
                        request.handoverType.isNotEmpty
                            ? titleCaseLabel(request.handoverType)
                            : 'Not selected',
                  ),
                  if (request.handoverType == 'community_hub_pickup')
                    _InfoRow(label: 'Community Hub', value: request.hubName),
                  _InfoRow(
                    label: 'Requested',
                    value: _formatDateTime(request.requestedAt),
                  ),
                  _InfoRow(
                    label: 'Updated',
                    value: _formatDateTime(request.updatedAt),
                  ),
                  _InfoRow(label: 'Quantity', value: '${request.itemQuantity}'),
                  _InfoRow(
                    label: 'Listing status',
                    value: titleCaseLabel(_availabilityStatus),
                  ),
                ],
              ),
            ),
          ),
          if (request.requestNote.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request Note',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      request.requestNote,
                      style: const TextStyle(
                        color: AppColors.mist,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => DonorDonationStatusTrackingPage(
                                    request: request,
                                  ),
                            ),
                          ),
                      icon: const Icon(Icons.timeline_outlined),
                      label: const Text('Open Donation Status Tracking'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          canSelectHandover
                              ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => DonorSelectHandoverPointPage(
                                        request: request,
                                      ),
                                ),
                              )
                              : null,
                      icon: const Icon(Icons.location_on_outlined),
                      label: const Text('Confirm Handover Method'),
                    ),
                  ),
                  if (!canSelectHandover) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Approve the request first before confirming the selected handover method.',
                      style: TextStyle(color: AppColors.mist),
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      request.handoverType == 'community_hub_pickup'
                          ? 'Approve, or reject if you do not want to use the donor-configured community hub.'
                          : 'Approve, or reject if you do not want to continue with independent pickup.',
                      style: const TextStyle(
                        color: AppColors.mist,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          canDecide
              ? SafeArea(
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
                              _isUpdating
                                  ? null
                                  : () => _updateRequestStatus('rejected'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.coral,
                            side: const BorderSide(color: AppColors.coral),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _isUpdating
                                  ? null
                                  : () => _updateRequestStatus('approved'),
                          child:
                              _isUpdating
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.night,
                                    ),
                                  )
                                  : const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : null,
    );
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Not set';
    }
    return DateFormat('MMM d, yyyy h:mm a').format(value);
  }

  static Widget _itemImageFallback() {
    return Container(
      color: AppColors.forest,
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppColors.mint,
        size: 30,
      ),
    );
  }

  static bool _canSelectHandover(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'delivering':
      case 'delivering_to_hub':
      case 'delivering_to_recipient':
      case 'item_at_community_hub':
      case 'reserved':
        return true;
      default:
        return false;
    }
  }

  static String _newHistoryId() {
    final digits = List.generate(13, (_) => _random.nextInt(10)).join();
    return 'history_$digits';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.sand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.mist)),
          ),
        ],
      ),
    );
  }
}

class _RequestChip extends StatelessWidget {
  const _RequestChip({required this.label, required this.color});

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
