import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'donor_incoming_requests_page.dart';
import 'donor_select_handover_point_page.dart';
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
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  bool _isCompleting = false;
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
      _CommunityHubSummary? hub;
      final hubId =
          handoverData?['hubId']?.toString().trim() ??
              requestData['hubId']?.toString().trim() ??
              '';
      if (hubId.isNotEmpty) {
        final directHubDoc =
            await _firestore.collection('COMMUNITY_HUB').doc(hubId).get();
        if (directHubDoc.exists) {
          hub = _CommunityHubSummary.fromFirestore(
            directHubDoc.id,
            directHubDoc.data()!,
          );
        } else {
          final hubSnapshot = await _firestore
              .collection('COMMUNITY_HUB')
              .where('hubId', isEqualTo: hubId)
              .limit(1)
              .get();
          if (hubSnapshot.docs.isNotEmpty) {
            hub = _CommunityHubSummary.fromFirestore(
              hubSnapshot.docs.first.id,
              hubSnapshot.docs.first.data(),
            );
          }
        }
      }

      final requestedAt = _readDateTime(requestData['requestedAt']);
      final timeline = <_StatusHistoryEntry>[
        if (requestedAt != null)
          _StatusHistoryEntry(
            status: 'pending',
            changedAt: requestedAt,
            changedByUserId:
                requestData['recipientId']?.toString().trim() ?? '',
            isSystemSeed: true,
          ),
        ...historySnapshot.docs.map(
          (doc) => _StatusHistoryEntry(
            status: doc.data()['status']?.toString().trim() ?? 'unknown',
            changedAt: _readDateTime(doc.data()['changedAt']),
            changedByUserId:
                doc.data()['changedByUserId']?.toString().trim() ?? '',
          ),
        ),
      ]..sort((a, b) {
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
          scheduledAt: _readDateTime(handoverData?['scheduledAt']),
          completedAt: _readDateTime(handoverData?['completedAt']),
          hub: hub,
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

  Future<void> _openHandoverSelection() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DonorSelectHandoverPointPage(request: widget.request),
      ),
    );
    if (updated == true && mounted) {
      await _loadTracking();
    }
  }

  Future<void> _markCompleted() async {
    final donorId = _auth.currentUser?.uid;
    final snapshot = _snapshot;
    if (donorId == null || snapshot == null) {
      return;
    }
    if (snapshot.handoverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set a handover point before completing the donation.'),
        ),
      );
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('ITEM_REQUEST').doc(widget.request.docId), {
        'requestStatus': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(_firestore.collection('HANDOVER').doc(snapshot.handoverId), {
        'handoverStatus': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      if (widget.request.itemDocId.isNotEmpty) {
        batch.update(_firestore.collection('ITEM_LISTING').doc(widget.request.itemDocId), {
          'availabilityStatus': 'completed',
        });
      }
      final historyRef = _firestore.collection('DONATION_STATUS_HISTORY').doc();
      batch.set(historyRef, {
        'statusHistoryId': historyRef.id,
        'requestId': widget.request.requestId,
        'status': 'completed',
        'changedAt': FieldValue.serverTimestamp(),
        'changedByUserId': donorId,
      });

      await batch.commit();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation marked as completed.')),
      );
      await _loadTracking();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to complete donation: $error')),
      );
      setState(() {
        _isCompleting = false;
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
    final canSelectHandover = _canSelectHandover(snapshot.requestStatus);
    final canComplete = snapshot.handoverId.isNotEmpty &&
        snapshot.handoverStatus.toLowerCase() == 'scheduled' &&
        snapshot.requestStatus.toLowerCase() != 'completed';
    final statusJourney = _buildJourney(snapshot);
    final readiness = _buildReadiness(snapshot);
    final openDays = snapshot.requestedAt == null
        ? '0'
        : DateTime.now()
            .difference(snapshot.requestedAt!)
            .inDays
            .toString();

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
              title: 'Progress Journey',
              subtitle:
                  'Track how this request is moving from approval to completed handover.',
              child: Column(
                children: [
                  for (var index = 0; index < statusJourney.length; index++) ...[
                    _JourneyStep(
                      step: statusJourney[index],
                      isLast: index == statusJourney.length - 1,
                    ),
                    if (index != statusJourney.length - 1)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Open Days',
                    value: openDays,
                    caption: 'Since request',
                    color: AppColors.sun,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MetricCard(
                    label: 'Timeline',
                    value: '${snapshot.timeline.length}',
                    caption: 'Recorded events',
                    color: AppColors.mint,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MetricCard(
                    label: 'Hub',
                    value: snapshot.hub == null ? 'Pending' : 'Ready',
                    caption: snapshot.hub?.hubName ?? 'Choose point',
                    color: snapshot.hub == null ? AppColors.coral : AppColors.pine,
                  ),
                ),
              ],
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
              title: 'Handover Readiness',
              subtitle:
                  'Readiness is derived only from your current request, hub, and handover records.',
              child: Column(
                children: [
                  for (final item in readiness) ...[
                    _ChecklistTile(item: item),
                    if (item != readiness.last) const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'Handover Brief',
              subtitle: 'Selected hub, schedule, and execution status.',
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Hub',
                    value: snapshot.hub?.hubName ??
                        (snapshot.hubId.isEmpty ? 'Not selected' : snapshot.hubId),
                  ),
                  if (snapshot.hub != null) ...[
                    _InfoRow(label: 'Address', value: snapshot.hub!.address),
                    _InfoRow(
                      label: 'Hours',
                      value: snapshot.hub!.operatingHours,
                    ),
                    _InfoRow(
                      label: 'Contact',
                      value: snapshot.hub!.contactNumber,
                    ),
                    _InfoRow(label: 'Hub Status', value: snapshot.hub!.statusLabel),
                  ],
                  _InfoRow(
                    label: 'Type',
                    value: snapshot.handoverType.isEmpty
                        ? 'Not set'
                        : titleCaseLabel(snapshot.handoverType),
                  ),
                  _InfoRow(
                    label: 'Status',
                    value: snapshot.handoverStatus.isEmpty
                        ? 'Not set'
                        : titleCaseLabel(snapshot.handoverStatus),
                  ),
                  _InfoRow(
                    label: 'Scheduled',
                    value: _formatDateTime(snapshot.scheduledAt),
                  ),
                  _InfoRow(
                    label: 'Completed',
                    value: _formatDateTime(snapshot.completedAt),
                  ),
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
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'Actions',
              subtitle: 'Only actions supported by the current stored state are shown.',
              child: Column(
                children: [
                  if (canSelectHandover)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openHandoverSelection,
                        icon: const Icon(Icons.location_on_outlined),
                        label: Text(
                          snapshot.handoverId.isEmpty
                              ? 'Select Handover Point'
                              : 'Update Handover Point',
                        ),
                      ),
                    )
                  else
                    const _ActionHint(
                      message:
                          'Approve the request first before assigning a handover point.',
                    ),
                  if (canComplete) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isCompleting ? null : _markCompleted,
                        icon: _isCompleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.mint,
                                ),
                              )
                            : const Icon(Icons.task_alt_outlined),
                        label: const Text('Mark Donation Completed'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_JourneyStepState> _buildJourney(_TrackingSnapshot snapshot) {
    final stage = _stageIndex(snapshot);
    return [
      _JourneyStepState(
        title: 'Request Approved',
        caption: 'Donor accepted the recipient request.',
        state: stage >= 1 ? _StepVisual.complete : _StepVisual.current,
      ),
      _JourneyStepState(
        title: 'Handover Planned',
        caption: 'Hub and schedule confirmed.',
        state: stage >= 2
            ? _StepVisual.complete
            : stage == 1
                ? _StepVisual.current
                : _StepVisual.upcoming,
      ),
      _JourneyStepState(
        title: 'Donation Closed',
        caption: 'Handover completed and request closed.',
        state: stage >= 3
            ? _StepVisual.complete
            : stage == 2
                ? _StepVisual.current
                : _StepVisual.upcoming,
      ),
    ];
  }

  List<_ChecklistItem> _buildReadiness(_TrackingSnapshot snapshot) {
    return [
      _ChecklistItem(
        title: 'Request accepted',
        description: 'Current request status is ${titleCaseLabel(snapshot.requestStatus)}.',
        isReady: snapshot.requestStatus.toLowerCase() != 'pending' &&
            snapshot.requestStatus.toLowerCase() != 'rejected',
      ),
      _ChecklistItem(
        title: 'Community hub selected',
        description: snapshot.hub?.hubName ?? 'No hub linked yet.',
        isReady: snapshot.hub != null || snapshot.hubId.isNotEmpty,
      ),
      _ChecklistItem(
        title: 'Schedule confirmed',
        description: snapshot.scheduledAt == null
            ? 'No handover date is stored.'
            : 'Scheduled for ${_formatDateTime(snapshot.scheduledAt)}.',
        isReady: snapshot.scheduledAt != null,
      ),
      _ChecklistItem(
        title: 'Handover closed',
        description: snapshot.completedAt == null
            ? 'Completion is still pending.'
            : 'Completed on ${_formatDateTime(snapshot.completedAt)}.',
        isReady: snapshot.completedAt != null,
      ),
    ];
  }

  int _stageIndex(_TrackingSnapshot snapshot) {
    final requestStatus = snapshot.requestStatus.toLowerCase();
    final handoverStatus = snapshot.handoverStatus.toLowerCase();
    if (requestStatus == 'completed' || handoverStatus == 'completed') {
      return 3;
    }
    if (requestStatus == 'handover_scheduled' || handoverStatus == 'scheduled') {
      return 2;
    }
    if (requestStatus == 'approved' || requestStatus == 'reserved') {
      return 1;
    }
    return 0;
  }

  String _nextActionCopy(_TrackingSnapshot snapshot) {
    final requestStatus = snapshot.requestStatus.toLowerCase();
    final handoverStatus = snapshot.handoverStatus.toLowerCase();
    if (requestStatus == 'completed' || handoverStatus == 'completed') {
      return 'Donation lifecycle is complete.';
    }
    if (snapshot.handoverId.isEmpty || snapshot.hub == null) {
      return 'Choose a community hub and lock the handover plan.';
    }
    if (handoverStatus == 'scheduled') {
      return 'Carry out the handover and mark the donation completed.';
    }
    if (requestStatus == 'approved') {
      return 'Move this approved request into a scheduled handover.';
    }
    return 'Review the current state and continue the handover flow.';
  }

  static bool _canSelectHandover(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'handover_scheduled':
      case 'reserved':
        return true;
      default:
        return false;
    }
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
    required this.scheduledAt,
    required this.completedAt,
    required this.hub,
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
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final _CommunityHubSummary? hub;
  final List<_StatusHistoryEntry> timeline;
}

class _CommunityHubSummary {
  const _CommunityHubSummary({
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

  String get statusLabel => titleCaseLabel(status);

  factory _CommunityHubSummary.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    return _CommunityHubSummary(
      hubId: data['hubId']?.toString().trim().isNotEmpty == true
          ? data['hubId'].toString().trim()
          : docId,
      hubName: data['hubName']?.toString().trim().isNotEmpty == true
          ? data['hubName'].toString().trim()
          : 'Community Hub',
      address: data['address']?.toString().trim() ?? 'Address not provided',
      operatingHours:
          data['operatingHours']?.toString().trim() ?? 'Hours not provided',
      contactNumber:
          data['contactNumber']?.toString().trim() ?? 'Contact not provided',
      status: data['status']?.toString().trim() ?? 'inactive',
    );
  }
}

class _StatusHistoryEntry {
  const _StatusHistoryEntry({
    required this.status,
    required this.changedAt,
    required this.changedByUserId,
    this.isSystemSeed = false,
  });

  final String status;
  final DateTime? changedAt;
  final String changedByUserId;
  final bool isSystemSeed;
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

enum _StepVisual { current, complete, upcoming }

class _JourneyStepState {
  const _JourneyStepState({
    required this.title,
    required this.caption,
    required this.state,
  });

  final String title;
  final String caption;
  final _StepVisual state;
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.step,
    required this.isLast,
  });

  final _JourneyStepState step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = switch (step.state) {
      _StepVisual.complete => AppColors.mint,
      _StepVisual.current => AppColors.sun,
      _StepVisual.upcoming => AppColors.slate,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 44,
                color: color.withValues(alpha: 0.45),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  step.caption,
                  style: const TextStyle(color: AppColors.mist, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            caption,
            style: const TextStyle(color: AppColors.mist, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem {
  const _ChecklistItem({
    required this.title,
    required this.description,
    required this.isReady,
  });

  final String title;
  final String description;
  final bool isReady;
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.item,
  });

  final _ChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.isReady ? AppColors.mint : AppColors.sun;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        color: AppColors.forest.withValues(alpha: 0.6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isReady
                ? Icons.check_circle_outline_rounded
                : Icons.schedule_outlined,
            color: color,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.description,
                  style: const TextStyle(color: AppColors.mist, height: 1.45),
                ),
              ],
            ),
          ),
        ],
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
                  entry.isSystemSeed
                      ? 'Initial request submitted'
                      : entry.changedByUserId.isEmpty
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

class _ActionHint extends StatelessWidget {
  const _ActionHint({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.sun.withValues(alpha: 0.35)),
        color: AppColors.forest.withValues(alpha: 0.7),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.mist, height: 1.5),
      ),
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
