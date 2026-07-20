import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import 'donor_incoming_requests_page.dart';
import '../../widgets/state_widgets.dart';

class DonorDonationStatusTrackingPage extends StatefulWidget {
  const DonorDonationStatusTrackingPage({super.key, required this.request});

  final DonorIncomingRequestRecord request;

  @override
  State<DonorDonationStatusTrackingPage> createState() =>
      _DonorDonationStatusTrackingPageState();
}

class _DonorDonationStatusTrackingPageState
    extends State<DonorDonationStatusTrackingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _errorMessage = '';
  bool _isCancellingDelivery = false;
  _TrackingSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _loadTracking();
  }

  Future<void> _loadTracking() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final requestDoc =
          await _firestore
              .collection('ITEM_REQUEST')
              .doc(widget.request.docId)
              .get();
      if (!requestDoc.exists) {
        throw Exception('Request record not found');
      }

      final requestData = requestDoc.data() ?? const <String, dynamic>{};
      final historySnapshot =
          await _firestore
              .collection('DONATION_STATUS_HISTORY')
              .where('requestId', isEqualTo: widget.request.requestId)
              .orderBy('changedAt')
              .get();
      final handoverSnapshot =
          await _firestore
              .collection('HANDOVER')
              .where('requestId', isEqualTo: widget.request.requestId)
              .limit(1)
              .get();

      Map<String, dynamic> itemData = const <String, dynamic>{};
      if (widget.request.itemDocId.isNotEmpty) {
        final itemDoc =
            await _firestore
                .collection('ITEM_LISTING')
                .doc(widget.request.itemDocId)
                .get();
        itemData = itemDoc.data() ?? const <String, dynamic>{};
      } else {
        final itemSnapshot =
            await _firestore
                .collection('ITEM_LISTING')
                .where('itemId', isEqualTo: widget.request.itemId)
                .limit(1)
                .get();
        if (itemSnapshot.docs.isNotEmpty) {
          itemData = itemSnapshot.docs.first.data();
        }
      }

      final handoverDoc =
          handoverSnapshot.docs.isNotEmpty ? handoverSnapshot.docs.first : null;
      final handoverData = handoverDoc?.data();

      final requestedAt = _readDateTime(requestData['requestedAt']);
      final timeline = historySnapshot.docs
        .map(
          (doc) => _StatusHistoryEntry(
            status: doc.data()['status']?.toString().trim() ?? 'unknown',
            changedAt: _readDateTime(doc.data()['changedAt']),
            changedByUserId:
                doc.data()['changedByUserId']?.toString().trim() ?? '',
          ),
        )
        .toList(growable: false)..sort((a, b) {
        final left = a.changedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.changedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return left.compareTo(right);
      });
      final dedupedTimeline = _dedupeTimeline(timeline);

      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = _TrackingSnapshot(
          requestStatus:
              requestData['requestStatus']?.toString().trim() ??
              widget.request.requestStatus,
          requestNote:
              requestData['requestNote']?.toString().trim() ??
              widget.request.requestNote,
          requestedAt: requestedAt,
          updatedAt: _readDateTime(requestData['updatedAt']),
          hubId: requestData['hubId']?.toString().trim() ?? '',
          listingStatus:
              itemData['availabilityStatus']?.toString().trim() ??
              widget.request.availabilityStatus,
          itemCategory:
              itemData['category']?.toString().trim() ??
              widget.request.itemCategory,
          itemCondition:
              itemData['condition']?.toString().trim() ?? 'Condition not set',
          itemCreatedAt: _readDateTime(itemData['createdAt']),
          handoverId: handoverData?['handoverId']?.toString().trim() ?? '',
          handoverStatus:
              handoverData?['handoverStatus']?.toString().trim() ?? '',
          handoverType:
              handoverData?['handoverType']?.toString().trim() ??
              requestData['handoverType']?.toString().trim() ??
              widget.request.handoverType,
          completedAt: _readDateTime(handoverData?['completedAt']),
          timeline: dedupedTimeline,
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load donation tracking: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelDelivery(_TrackingSnapshot snapshot) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel delivery?'),
            content: const Text(
              'This will cancel the delivery, return the listing to available, and mark the request as cancelled.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep delivery'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Cancel delivery'),
              ),
            ],
          ),
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _isCancellingDelivery = true;
    });

    try {
      final requestRef = _firestore
          .collection('ITEM_REQUEST')
          .doc(widget.request.docId);
      final handoverQuery =
          await _firestore
              .collection('HANDOVER')
              .where('requestId', isEqualTo: widget.request.requestId)
              .limit(1)
              .get();
      final handoverRef =
          snapshot.handoverId.isNotEmpty
              ? _firestore.collection('HANDOVER').doc(snapshot.handoverId)
              : handoverQuery.docs.isNotEmpty
              ? handoverQuery.docs.first.reference
              : null;

      DocumentReference<Map<String, dynamic>>? itemRef;
      if (widget.request.itemDocId.isNotEmpty) {
        itemRef = _firestore
            .collection('ITEM_LISTING')
            .doc(widget.request.itemDocId);
      } else if (widget.request.itemId.isNotEmpty) {
        final itemSnapshot =
            await _firestore
                .collection('ITEM_LISTING')
                .where('itemId', isEqualTo: widget.request.itemId)
                .limit(1)
                .get();
        if (itemSnapshot.docs.isNotEmpty) {
          itemRef = itemSnapshot.docs.first.reference;
        }
      }

      final batch = _firestore.batch();
      batch.update(requestRef, {
        'requestStatus': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (itemRef != null) {
        batch.update(itemRef, {'availabilityStatus': 'available'});
      }

      if (handoverRef != null) {
        batch.set(handoverRef, {
          'handoverStatus': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final historyRef = _firestore
          .collection('DONATION_STATUS_HISTORY')
          .doc('status_${DateTime.now().millisecondsSinceEpoch}');
      batch.set(historyRef, {
        'statusHistoryId': historyRef.id,
        'requestId': widget.request.requestId,
        'status': 'cancelled',
        'changedAt': FieldValue.serverTimestamp(),
        'changedByUserId': 'donor',
      });

      await batch.commit();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Delivery canceled.')));
      await _loadTracking();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to cancel delivery: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancellingDelivery = false;
        });
      }
    }
  }

  bool _canCancelDelivery(_TrackingSnapshot snapshot) {
    final requestStatus = snapshot.requestStatus.toLowerCase();
    final handoverStatus = snapshot.handoverStatus.toLowerCase();
    final hasReachedHubOrBeyond =
        requestStatus == 'item_at_community_hub' ||
        requestStatus == 'completed' ||
        handoverStatus == 'item_at_community_hub' ||
        handoverStatus == 'completed' ||
        snapshot.timeline.any((entry) {
          final status = entry.status.toLowerCase();
          return status == 'item_at_community_hub' ||
              status == 'completed' ||
              status == 'item_handed_to_intended_recipient';
        });
    final canCancelCurrentDelivery =
        requestStatus == 'delivering_to_hub' ||
        requestStatus == 'delivering_to_recipient' ||
        handoverStatus == 'delivering_to_hub' ||
        handoverStatus == 'delivering_to_recipient';
    return canCancelCurrentDelivery &&
        !hasReachedHubOrBeyond &&
        requestStatus != 'completed' &&
        requestStatus != 'rejected' &&
        requestStatus != 'cancelled';
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: true,
      title: const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const AppLoadingState(message: 'Loading donation timeline...'),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: AppErrorState(message: _errorMessage, onRetry: _loadTracking),
      );
    }

    final snapshot = _snapshot!;
    final canCancelDelivery = _canCancelDelivery(snapshot);
    final canShowRecipientContact =
        snapshot.handoverType == 'independent_pickup' &&
        snapshot.requestStatus.toLowerCase() != 'pending' &&
        snapshot.requestStatus.toLowerCase() != 'rejected' &&
        snapshot.requestStatus.toLowerCase() != 'cancelled' &&
        snapshot.requestStatus.toLowerCase() != 'completed' &&
        snapshot.handoverStatus.toLowerCase() != 'completed';
    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: AppColors.mint,
        onRefresh: _loadTracking,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _HeroPanel(
              itemTitle: widget.request.itemTitle,
              requestId: widget.request.requestId,
              requestStatus: snapshot.requestStatus,
              listingStatus: snapshot.listingStatus,
              handoverStatus: snapshot.handoverStatus,
              nextAction: _nextActionCopy(snapshot),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'Case Snapshot',
              subtitle: 'Everything the donor needs without leaving the page.',
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Recipient',
                    value: widget.request.recipientName,
                  ),
                  if (canShowRecipientContact)
                    _InfoRow(
                      label: 'Phone',
                      value: widget.request.recipientPhone,
                    ),
                  if (canShowRecipientContact)
                    _InfoRow(
                      label: 'Address',
                      value: widget.request.recipientAddress,
                    ),
                  _InfoRow(
                    label: 'Category',
                    value: titleCaseLabel(snapshot.itemCategory),
                  ),
                  _InfoRow(label: 'Condition', value: snapshot.itemCondition),
                  _InfoRow(
                    label: 'Quantity',
                    value: '${widget.request.itemQuantity}',
                  ),
                  _InfoRow(
                    label: 'Requested',
                    value: _formatDateTime(snapshot.requestedAt),
                  ),
                  _InfoRow(
                    label: 'Listing',
                    value: _formatDateTime(snapshot.itemCreatedAt),
                  ),
                  _InfoRow(
                    label: 'Updated',
                    value: _formatDateTime(snapshot.updatedAt),
                  ),
                  if (snapshot.requestNote.isNotEmpty)
                    _InfoRow(label: 'Note', value: snapshot.requestNote),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'Timeline',
              subtitle:
                  'Status history from request creation through handover.',
              child:
                  snapshot.timeline.isEmpty
                      ? const Text(
                        'No donation history recorded yet.',
                        style: TextStyle(color: AppColors.mist),
                      )
                      : Column(
                        children: [
                          for (
                            var index = 0;
                            index < snapshot.timeline.length;
                            index++
                          ) ...[
                            _TimelineTile(
                              entry: snapshot.timeline[index],
                              isFirst: index == 0,
                              isLast: index == snapshot.timeline.length - 1,
                              isCurrent: index == snapshot.timeline.length - 1,
                            ),
                            if (index != snapshot.timeline.length - 1)
                              const SizedBox(height: AppSpacing.md),
                          ],
                        ],
                      ),
            ),
            if (canCancelDelivery) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _isCancellingDelivery
                          ? null
                          : () => _cancelDelivery(snapshot),
                  icon:
                      _isCancellingDelivery
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.cancel_outlined),
                  label: Text(
                    _isCancellingDelivery
                        ? 'Canceling delivery...'
                        : 'Cancel Delivery',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: AppColors.coral,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _nextActionCopy(_TrackingSnapshot snapshot) {
    final requestStatus = snapshot.requestStatus.toLowerCase();
    final handoverStatus =
        snapshot.handoverStatus.toLowerCase() == 'delivering'
            ? (snapshot.hubId.isEmpty
                ? 'delivering_to_recipient'
                : 'delivering_to_hub')
            : snapshot.handoverStatus.toLowerCase();
    if (requestStatus == 'completed' || handoverStatus == 'completed') {
      return 'Donation lifecycle is complete.';
    }
    if (requestStatus == 'cancelled' || handoverStatus == 'cancelled') {
      return 'Delivery was canceled.';
    }
    if (snapshot.handoverId.isEmpty) {
      return 'Confirm the recipient-selected handover method and continue the flow.';
    }
    if (handoverStatus == 'delivering_to_hub') {
      return 'Move the item to the community hub, then confirm hub receipt.';
    }
    if (handoverStatus == 'item_at_community_hub') {
      return 'Hand the item over from the hub to the recipient.';
    }
    if (handoverStatus == 'delivering_to_recipient') {
      return 'Deliver the item directly to the recipient and confirm receipt.';
    }
    if (requestStatus == 'approved') {
      return 'Move this approved request into delivery.';
    }
    return 'Review the current state and continue the handover flow.';
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

  static String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Not set';
    }
    return DateFormat('MMM d, yyyy h:mm a').format(value);
  }

  static List<_StatusHistoryEntry> _dedupeTimeline(
    List<_StatusHistoryEntry> timeline,
  ) {
    final deduped = <_StatusHistoryEntry>[];
    for (final entry in timeline) {
      final normalizedStatus = entry.status.toLowerCase();
      if (deduped.isNotEmpty &&
          deduped.last.status.toLowerCase() == normalizedStatus) {
        continue;
      }
      deduped.add(entry);
    }
    return deduped;
  }
}

class _TrackingSnapshot {
  const _TrackingSnapshot({
    required this.requestStatus,
    required this.requestNote,
    required this.requestedAt,
    required this.updatedAt,
    required this.hubId,
    required this.listingStatus,
    required this.itemCategory,
    required this.itemCondition,
    required this.itemCreatedAt,
    required this.handoverId,
    required this.handoverStatus,
    required this.handoverType,
    required this.completedAt,
    required this.timeline,
  });

  final String requestStatus;
  final String requestNote;
  final DateTime? requestedAt;
  final DateTime? updatedAt;
  final String hubId;
  final String listingStatus;
  final String itemCategory;
  final String itemCondition;
  final DateTime? itemCreatedAt;
  final String handoverId;
  final String handoverStatus;
  final String handoverType;
  final DateTime? completedAt;
  final List<_StatusHistoryEntry> timeline;
}

class _StatusHistoryEntry {
  const _StatusHistoryEntry({
    required this.status,
    required this.changedAt,
    required this.changedByUserId,
  });

  final String status;
  final DateTime? changedAt;
  final String changedByUserId;
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.itemTitle,
    required this.requestId,
    required this.requestStatus,
    required this.listingStatus,
    required this.handoverStatus,
    required this.nextAction,
  });

  final String itemTitle;
  final String requestId;
  final String requestStatus;
  final String listingStatus;
  final String handoverStatus;
  final String nextAction;

  @override
  Widget build(BuildContext context) {
    final normalizedRequestStatus = requestStatus.toLowerCase();
    final normalizedHandoverStatus = handoverStatus.toLowerCase();
    final showHandoverStatus =
        normalizedHandoverStatus.isNotEmpty &&
        normalizedHandoverStatus != normalizedRequestStatus;
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
            'DONATION CASE',
            style: TextStyle(
              color: AppColors.sand,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            itemTitle,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Request ID: $requestId',
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
                label: 'Listing ${titleCaseLabel(listingStatus)}',
                color: AppColors.sun,
              ),
              if (showHandoverStatus)
                _StatusChip(
                  label: 'Handover ${titleCaseLabel(handoverStatus)}',
                  color:
                      normalizedHandoverStatus == 'completed'
                          ? AppColors.mint
                          : AppColors.sand,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            nextAction,
            style: const TextStyle(color: AppColors.white, height: 1.5),
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

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.isCurrent,
  });

  final _StatusHistoryEntry entry;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color:
                    isCurrent
                        ? AppColors.white
                        : AppColors.slate.withValues(alpha: 0.5),
                width: isCurrent ? 1.8 : 1,
              ),
              color:
                  isCurrent
                      ? AppColors.pine
                      : AppColors.slate.withValues(alpha: 0.18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleCaseLabel(entry.status),
                  style: TextStyle(
                    color: isCurrent ? AppColors.white : AppColors.sand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.changedAt == null
                      ? 'Time not available'
                      : DateFormat(
                        'MMM d, yyyy h:mm a',
                      ).format(entry.changedAt!),
                  style: TextStyle(
                    color: isCurrent ? AppColors.sand : AppColors.slate,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.changedByUserId.isEmpty
                      ? 'Updated by system'
                      : 'Updated by ${entry.changedByUserId}',
                  style: TextStyle(
                    color: isCurrent ? AppColors.mist : AppColors.slate,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
