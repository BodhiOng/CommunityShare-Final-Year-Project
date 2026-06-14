import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'donor_incoming_requests_page.dart';
import 'widgets/state_widgets.dart';

class DonorSelectHandoverPointPage extends StatefulWidget {
  const DonorSelectHandoverPointPage({
    super.key,
    required this.request,
  });

  final DonorIncomingRequestRecord request;

  @override
  State<DonorSelectHandoverPointPage> createState() =>
      _DonorSelectHandoverPointPageState();
}

class _DonorSelectHandoverPointPageState
    extends State<DonorSelectHandoverPointPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';
  String? _selectedHubId;
  String _handoverType = 'community_hub_pickup';
  DateTime? _scheduledAt;
  String? _handoverDocId;
  String _requestStatus = '';
  List<_CommunityHubRecord> _hubs = const [];

  @override
  void initState() {
    super.initState();
    _loadPage();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final requestSnapshot = await _firestore
          .collection('ITEM_REQUEST')
          .doc(widget.request.docId)
          .get();
      final handoverSnapshot = await _firestore
          .collection('HANDOVER')
          .where('requestId', isEqualTo: widget.request.requestId)
          .limit(1)
          .get();
      final hubSnapshot = await _firestore.collection('COMMUNITY_HUB').get();

      final requestData = requestSnapshot.data() ?? const <String, dynamic>{};
      final handoverDoc =
          handoverSnapshot.docs.isNotEmpty ? handoverSnapshot.docs.first : null;
      final handoverData = handoverDoc?.data() ?? const <String, dynamic>{};
      final hubs = hubSnapshot.docs
          .map((doc) => _CommunityHubRecord.fromFirestore(doc.id, doc.data()))
          .toList(growable: false)
        ..sort((a, b) {
          final leftScore = a.recommendationScore;
          final rightScore = b.recommendationScore;
          if (leftScore != rightScore) {
            return rightScore.compareTo(leftScore);
          }
          return a.hubName.toLowerCase().compareTo(b.hubName.toLowerCase());
        });

      final existingHubId = handoverData['hubId']?.toString().trim().isNotEmpty ==
              true
          ? handoverData['hubId'].toString().trim()
          : requestData['hubId']?.toString().trim().isNotEmpty == true
              ? requestData['hubId'].toString().trim()
              : widget.request.hubId;
      final selectedHubId = existingHubId.isNotEmpty
          ? existingHubId
          : hubs.isNotEmpty
              ? hubs.first.hubId
              : null;
      final scheduledAt = _readDateTime(handoverData['scheduledAt']) ??
          _defaultSchedule();

      if (!mounted) {
        return;
      }

      setState(() {
        _requestStatus =
            requestData['requestStatus']?.toString().trim() ?? widget.request.requestStatus;
        _handoverDocId = handoverDoc?.id;
        _selectedHubId = selectedHubId;
        _handoverType =
            handoverData['handoverType']?.toString().trim().isNotEmpty == true
                ? handoverData['handoverType'].toString().trim()
                : 'community_hub_pickup';
        _scheduledAt = scheduledAt;
        _hubs = hubs;
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

  Future<void> _pickSchedule() async {
    final initialDate = _scheduledAt ?? _defaultSchedule();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? initialDate),
    );
    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _scheduledAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _applyQuickSchedule(DateTime value) {
    setState(() {
      _scheduledAt = value;
    });
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

    if (_requestStatus.toLowerCase() == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Approve the request before scheduling handover.'),
        ),
      );
      return;
    }

    if (_selectedHubId == null || _selectedHubId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a handover point first.')),
      );
      return;
    }

    if (_scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a scheduled handover date and time.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final batch = _firestore.batch();
      final requestRef =
          _firestore.collection('ITEM_REQUEST').doc(widget.request.docId);
      batch.update(requestRef, {
        'hubId': _selectedHubId,
        'requestStatus': 'handover_scheduled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (widget.request.itemDocId.isNotEmpty) {
        final itemRef =
            _firestore.collection('ITEM_LISTING').doc(widget.request.itemDocId);
        batch.update(itemRef, {
          'availabilityStatus': 'reserved',
        });
      }

      final handoverRef = _handoverDocId != null
          ? _firestore.collection('HANDOVER').doc(_handoverDocId)
          : _firestore.collection('HANDOVER').doc();
      batch.set(handoverRef, {
        'handoverId': handoverRef.id,
        'requestId': widget.request.requestId,
        'hubId': _selectedHubId,
        'handoverType': _handoverType,
        'handoverStatus': 'scheduled',
        'scheduledAt': Timestamp.fromDate(_scheduledAt!),
        'completedAt': null,
      }, SetOptions(merge: true));

      final historyRef = _firestore.collection('DONATION_STATUS_HISTORY').doc();
      batch.set(historyRef, {
        'statusHistoryId': historyRef.id,
        'requestId': widget.request.requestId,
        'status': 'handover_scheduled',
        'changedAt': FieldValue.serverTimestamp(),
        'changedByUserId': donorId,
      });

      await batch.commit();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Handover point saved.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save handover point: $error')),
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
        appBar: AppBar(title: const Text('Select Handover Point')),
        body: const AppLoadingState(message: 'Loading handover points...'),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Handover Point')),
        body: AppErrorState(
          message: _errorMessage,
          onRetry: _loadPage,
        ),
      );
    }

    final filteredHubs = _filteredHubs;
    final selectedHub = _selectedHub;
    final quickSlots = _quickSlots();
    final readiness = <_PlannerFact>[
      _PlannerFact(
        label: 'Request Ready',
        value: _requestStatus.toLowerCase() == 'pending' ? 'No' : 'Yes',
        tone: _requestStatus.toLowerCase() == 'pending'
            ? AppColors.coral
            : AppColors.mint,
      ),
      _PlannerFact(
        label: 'Hub Selected',
        value: selectedHub == null ? 'Pending' : selectedHub.hubName,
        tone: selectedHub == null ? AppColors.sun : AppColors.mint,
      ),
      _PlannerFact(
        label: 'Schedule',
        value: _scheduledAt == null
            ? 'Pending'
            : DateFormat('MMM d, h:mm a').format(_scheduledAt!),
        tone: _scheduledAt == null ? AppColors.sun : AppColors.mint,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Handover Point'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _PlannerHero(
            request: widget.request,
            requestStatus: _requestStatus,
            handoverType: _handoverType,
            schedule: _scheduledAt,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (var index = 0; index < readiness.length; index++) ...[
                Expanded(child: _PlannerFactCard(fact: readiness[index])),
                if (index != readiness.length - 1)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Handover Setup',
            subtitle:
                'Plan the hub, handover type, and schedule using only the data already stored in the app.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _handoverType,
                  decoration: const InputDecoration(
                    labelText: 'Handover Type',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'community_hub_pickup',
                      child: Text('Community Hub Pickup'),
                    ),
                    DropdownMenuItem(
                      value: 'hub_dropoff',
                      child: Text('Hub Dropoff'),
                    ),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _handoverType = value;
                          });
                        },
                ),
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: _isSaving ? null : _pickSchedule,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppColors.mint.withValues(alpha: 0.35),
                      ),
                      color: AppColors.forest,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scheduled At',
                          style: TextStyle(
                            color: AppColors.mist,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _scheduledAt == null
                              ? 'Choose date and time'
                              : DateFormat('MMM d, yyyy h:mm a')
                                  .format(_scheduledAt!),
                          style: const TextStyle(color: AppColors.sand),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final slot in quickSlots)
                      ActionChip(
                        backgroundColor: AppColors.forest,
                        side: BorderSide(
                          color: AppColors.mint.withValues(alpha: 0.35),
                        ),
                        label: Text(
                          DateFormat('EEE h:mm a').format(slot),
                          style: const TextStyle(color: AppColors.mist),
                        ),
                        onPressed: _isSaving ? null : () => _applyQuickSchedule(slot),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Selected Hub',
            subtitle:
                'Review the handover point before saving it to ITEM_REQUEST and HANDOVER.',
            child: selectedHub == null
                ? const Text(
                    'Select a hub from the list below.',
                    style: TextStyle(color: AppColors.mist),
                  )
                : _SelectedHubSummary(hub: selectedHub),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Find Community Hub',
            subtitle:
                'Filter by name, address, operating hours, contact number, or status.',
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search hubs',
                    hintText: 'Name, address, hours, contact, status',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_hubs.isEmpty)
                  const AppEmptyState(
                    icon: Icons.location_off_outlined,
                    title: 'No community hubs found',
                    message:
                        'Add records to the COMMUNITY_HUB collection so donors can assign a handover point.',
                  )
                else if (filteredHubs.isEmpty)
                  const AppEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No hubs match this filter',
                    message: 'Try a broader search phrase.',
                  )
                else
                  Column(
                    children: [
                      for (var index = 0; index < filteredHubs.length; index++) ...[
                        _HubTile(
                          hub: filteredHubs[index],
                          isSelected: filteredHubs[index].hubId == _selectedHubId,
                          isRecommended: filteredHubs[index].hubId == _recommendedHubId,
                          onTap: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    _selectedHubId = filteredHubs[index].hubId;
                                  });
                                },
                        ),
                        if (index != filteredHubs.length - 1)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
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
          child: ElevatedButton(
            onPressed: _isSaving || _hubs.isEmpty ? null : _saveHandover,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.night,
                    ),
                  )
                : Text(
                    selectedHub == null
                        ? 'Save Handover Point'
                        : 'Save ${selectedHub.hubName}',
                  ),
          ),
        ),
      ),
    );
  }

  List<_CommunityHubRecord> get _filteredHubs {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _hubs;
    }
    return _hubs.where((hub) {
      return hub.hubName.toLowerCase().contains(query) ||
          hub.address.toLowerCase().contains(query) ||
          hub.operatingHours.toLowerCase().contains(query) ||
          hub.contactNumber.toLowerCase().contains(query) ||
          hub.status.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  _CommunityHubRecord? get _selectedHub {
    for (final hub in _hubs) {
      if (hub.hubId == _selectedHubId) {
        return hub;
      }
    }
    return null;
  }

  String? get _recommendedHubId {
    for (final hub in _hubs) {
      if (hub.status.toLowerCase() == 'active') {
        return hub.hubId;
      }
    }
    return _hubs.isNotEmpty ? _hubs.first.hubId : null;
  }

  List<DateTime> _quickSlots() {
    final now = DateTime.now();
    return [
      DateTime(now.year, now.month, now.day + 1, 10),
      DateTime(now.year, now.month, now.day + 1, 14),
      DateTime(now.year, now.month, now.day + 2, 10),
      DateTime(now.year, now.month, now.day + 2, 16),
    ];
  }

  static DateTime _defaultSchedule() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 10);
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

  int get recommendationScore {
    var score = 0;
    if (status.toLowerCase() == 'active') {
      score += 2;
    }
    if (address.trim().isNotEmpty && address != 'Address not provided') {
      score += 1;
    }
    if (contactNumber.trim().isNotEmpty && contactNumber != 'Contact not provided') {
      score += 1;
    }
    return score;
  }

  factory _CommunityHubRecord.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    return _CommunityHubRecord(
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

class _PlannerHero extends StatelessWidget {
  const _PlannerHero({
    required this.request,
    required this.requestStatus,
    required this.handoverType,
    required this.schedule,
  });

  final DonorIncomingRequestRecord request;
  final String requestStatus;
  final String handoverType;
  final DateTime? schedule;

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
          Text(
            schedule == null
                ? 'Choose the best hub and lock a time the recipient can work with.'
                : 'Current target schedule: ${DateFormat('MMM d, yyyy h:mm a').format(schedule!)}',
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

class _PlannerFact {
  const _PlannerFact({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;
}

class _PlannerFactCard extends StatelessWidget {
  const _PlannerFactCard({
    required this.fact,
  });

  final _PlannerFact fact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: fact.tone.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fact.label,
            style: TextStyle(
              color: fact.tone,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            fact.value,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
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

class _SelectedHubSummary extends StatelessWidget {
  const _SelectedHubSummary({
    required this.hub,
  });

  final _CommunityHubRecord hub;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.mint.withValues(alpha: 0.35)),
        color: AppColors.forest.withValues(alpha: 0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.mint,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  hub.hubName,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusChip(
                label: titleCaseLabel(hub.status),
                color: hub.status.toLowerCase() == 'active'
                    ? AppColors.mint
                    : AppColors.sun,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hub.address,
            style: const TextStyle(color: AppColors.mist, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Hours: ${hub.operatingHours}',
            style: const TextStyle(color: AppColors.sand),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Contact: ${hub.contactNumber}',
            style: const TextStyle(color: AppColors.sand),
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.hub,
    required this.isSelected,
    required this.isRecommended,
    required this.onTap,
  });

  final _CommunityHubRecord hub;
  final bool isSelected;
  final bool isRecommended;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected ? AppColors.mint : AppColors.pine,
            width: isSelected ? 1.4 : 1,
          ),
          color: isSelected
              ? AppColors.pine.withValues(alpha: 0.16)
              : AppColors.forest.withValues(alpha: 0.45),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.mint : AppColors.slate,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hub.hubName,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isRecommended)
                        const _StatusChip(
                          label: 'Recommended',
                          color: AppColors.sun,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    hub.address,
                    style: const TextStyle(color: AppColors.mist, height: 1.4),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Hours: ${hub.operatingHours}',
                    style: const TextStyle(color: AppColors.sand),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Contact: ${hub.contactNumber}',
                    style: const TextStyle(color: AppColors.sand),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _StatusChip(
                        label: titleCaseLabel(hub.status),
                        color: hub.status.toLowerCase() == 'active'
                            ? AppColors.mint
                            : AppColors.sun,
                      ),
                      _StatusChip(
                        label: 'Score ${hub.recommendationScore}',
                        color: AppColors.pine,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
