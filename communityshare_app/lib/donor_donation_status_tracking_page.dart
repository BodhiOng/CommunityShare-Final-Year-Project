import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'donor_incoming_requests_page.dart';
import 'widgets/state_widgets.dart';

class DonorDonationStatusTrackingPage extends StatefulWidget {
  const DonorDonationStatusTrackingPage({
    super.key,
    required this.request,
  });

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
      final requestDoc = await _firestore
          .collection('ITEM_REQUEST')
          .doc(widget.request.docId)
          .get();
      if (!requestDoc.exists) {
        throw Exception('Request record not found');
      }

      final requestData = requestDoc.data() ?? const <String, dynamic>{};
      final historySnapshot = await _firestore
          .collection('DONATION_STATUS_HISTORY')
          .where('requestId', isEqualTo: widget.request.requestId)
          .orderBy('changedAt')
          .get();
      final handoverSnapshot = await _firestore
          .collection('HANDOVER')
          .where('requestId', isEqualTo: widget.request.requestId)
          .limit(1)
          .get();

      Map<String, dynamic> itemData = const <String, dynamic>{};
      if (widget.request.itemDocId.isNotEmpty) {
        final itemDoc = await _firestore
            .collection('ITEM_LISTING')
            .doc(widget.request.itemDocId)
            .get();
        itemData = itemDoc.data() ?? const <String, dynamic>{};
      } else {
        final itemSnapshot = await _firestore
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
          .toList(growable: false)
        ..sort((a, b) {
          final left = a.changedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.changedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return left.compareTo(right);
        });

      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = _TrackingSnapshot(
          requestStatus: requestData['requestStatus']?.toString().trim() ??
              widget.request.requestStatus,
          requestNote: requestData['requestNote']?.toString().trim() ??
              widget.request.requestNote,
          requestedAt: requestedAt,
          updatedAt: _readDateTime(requestData['updatedAt']),
          hubId: requestData['hubId']?.toString().trim() ?? '',
          listingStatus: itemData['availabilityStatus']?.toString().trim() ??
              widget.request.availabilityStatus,
          itemCategory:
              itemData['category']?.toString().trim() ?? widget.request.itemCategory,
          itemCondition:
              itemData['condition']?.toString().trim() ?? 'Condition not set',
          itemCreatedAt: _readDateTime(itemData['createdAt']),
          handoverId: handoverData?['handoverId']?.toString().trim() ?? '',
          handoverStatus:
              handoverData?['handoverStatus']?.toString().trim() ?? '',
          handoverType: handoverData?['handoverType']?.toString().trim() ?? '',
          completedAt: _readDateTime(handoverData?['completedAt']),
          timeline: timeline,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Donation Status Tracking')),
        body: const AppLoadingState(message: 'Loading donation timeline...'),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Donation Status Tracking')),
        body: AppErrorState(
          message: _errorMessage,
          onRetry: _loadTracking,
        ),
      );
    }

    final snapshot = _snapshot!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation Status Tracking'),
      ),
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
                  _InfoRow(label: 'Recipient', value: widget.request.recipientName),
                  _InfoRow(label: 'Phone', value: widget.request.recipientPhone),
                  _InfoRow(label: 'Location', value: widget.request.recipientLocation),
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
              subtitle: 'Status history from request creation through handover.',
              child: snapshot.timeline.isEmpty
                  ? const Text(
                      'No donation history recorded yet.',
                      style: TextStyle(color: AppColors.mist),
                    )
                  : Column(
                      children: [
                        for (var index = 0; index < snapshot.timeline.length; index++) ...[
                          _TimelineTile(
                            entry: snapshot.timeline[index],
                            isLast: index == snapshot.timeline.length - 1,
                          ),
                          if (index != snapshot.timeline.length - 1)
                            const SizedBox(height: AppSpacing.md),
                        ],
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _nextActionCopy(_TrackingSnapshot snapshot) {
    final requestStatus = snapshot.requestStatus.toLowerCase();
    final handoverStatus = snapshot.handoverStatus.toLowerCase() == 'delivering'
        ? (snapshot.hubId.isEmpty
            ? 'delivering_to_recipient'
            : 'delivering_to_hub')
        : snapshot.handoverStatus.toLowerCase();
    if (requestStatus == 'completed' || handoverStatus == 'completed') {
      return 'Donation lifecycle is complete.';
    }
    if (snapshot.handoverId.isEmpty) {
      return 'Choose a handover point and continue the flow.';
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
              if (handoverStatus.isNotEmpty)
                _StatusChip(
                  label: 'Handover ${titleCaseLabel(handoverStatus)}',
                  color: handoverStatus.toLowerCase() == 'completed'
                      ? AppColors.mint
                      : AppColors.sand,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            nextAction,
            style: const TextStyle(
              color: AppColors.white,
              height: 1.5,
            ),
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
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
    required this.isLast,
  });

  final _StatusHistoryEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = requestStatusColor(entry.status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 54,
                color: color.withValues(alpha: 0.35),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: color.withValues(alpha: 0.28)),
              color: AppColors.forest.withValues(alpha: 0.55),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleCaseLabel(entry.status),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.changedAt == null
                      ? 'Time not available'
                      : DateFormat('MMM d, yyyy h:mm a').format(entry.changedAt!),
                  style: const TextStyle(color: AppColors.mist),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.changedByUserId.isEmpty
                      ? 'Updated by system'
                      : 'Updated by ${entry.changedByUserId}',
                  style: const TextStyle(color: AppColors.slate),
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
  const _InfoRow({
    required this.label,
    required this.value,
  });

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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
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
