import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../donor/donor_incoming_requests_page.dart';
import '../../utils/image_utils.dart';
import '../../widgets/state_widgets.dart';

class HubHandoverConfirmationPage extends StatefulWidget {
  const HubHandoverConfirmationPage({super.key});

  @override
  State<HubHandoverConfirmationPage> createState() =>
      _HubHandoverConfirmationPageState();
}

class _HubHandoverConfirmationPageState
    extends State<HubHandoverConfirmationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _errorMessage = '';
  String _hubDocId = '';
  String _hubId = '';
  String _hubName = '';
  String? _savingRequestId;
  List<HubHandoverRecord> _requests = const [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _savingRequestId = null;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final hubSnapshot = await _firestore
          .collection('COMMUNITY_HUB')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      final hubDoc = hubSnapshot.docs.isNotEmpty ? hubSnapshot.docs.first : null;
      final hubData = hubDoc?.data() ?? const <String, dynamic>{};
      final hubDocId = hubDoc?.id ?? '';
      final hubId = hubData['hubId']?.toString().trim().isNotEmpty == true
          ? hubData['hubId'].toString().trim()
          : hubDocId;
      final hubName = hubData['hubName']?.toString().trim().isNotEmpty == true
          ? hubData['hubName'].toString().trim()
          : 'Community Hub';

      if (hubId.isEmpty && hubDocId.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _hubDocId = '';
          _hubId = '';
          _hubName = '';
          _requests = const [];
          _savingRequestId = null;
          _isLoading = false;
        });
        return;
      }

      final requestDocsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final lookupId in {hubId, hubDocId}.where((value) => value.isNotEmpty)) {
        final snapshot = await _firestore
            .collection('ITEM_REQUEST')
            .where('hubId', isEqualTo: lookupId)
            .get();
        for (final doc in snapshot.docs) {
          requestDocsById[doc.id] = doc;
        }
      }

      final activeRequestDocs = requestDocsById.values.where((doc) {
        final status = doc.data()['requestStatus']?.toString().trim().toLowerCase() ?? '';
        return status == 'delivering_to_hub' || status == 'item_at_community_hub';
      }).toList(growable: false);

      final itemIds = activeRequestDocs
          .map((doc) => doc.data()['itemId']?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final listingsByItemId = <String, Map<String, dynamic>>{};
      for (final chunk in _chunkStrings(itemIds, 10)) {
        final snapshot = await _firestore
            .collection('ITEM_LISTING')
            .where('itemId', whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          final itemId = doc.data()['itemId']?.toString().trim().isNotEmpty == true
              ? doc.data()['itemId'].toString().trim()
              : doc.id;
          listingsByItemId[itemId] = {
            ...doc.data(),
            '_docId': doc.id,
          };
        }
      }

      final donorIds = activeRequestDocs
          .map((doc) => listingsByItemId[doc.data()['itemId']?.toString().trim() ?? '']?['donorId']?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final recipientIds = activeRequestDocs
          .map((doc) => doc.data()['recipientId']?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final requestIds = activeRequestDocs
          .map((doc) => doc.data()['requestId']?.toString().trim().isNotEmpty == true
              ? doc.data()['requestId'].toString().trim()
              : doc.id)
          .toList(growable: false);

      final usersById = await _loadUsersByIds({...donorIds, ...recipientIds}.toList(growable: false));
      final handoversByRequestId = await _loadHandoversByRequestIds(requestIds);

      final records = activeRequestDocs.map((doc) {
        final data = doc.data();
        final itemId = data['itemId']?.toString().trim() ?? '';
        final itemData = listingsByItemId[itemId] ?? const <String, dynamic>{};
        final donorId = itemData['donorId']?.toString().trim() ?? '';
        final recipientId = data['recipientId']?.toString().trim() ?? '';
        final requestId = data['requestId']?.toString().trim().isNotEmpty == true
            ? data['requestId'].toString().trim()
            : doc.id;
        final handoverData =
            handoversByRequestId[requestId] ?? const <String, dynamic>{};

        return HubHandoverRecord(
          requestId: requestId,
          docId: doc.id,
          itemId: itemId,
          itemDocId: itemData['_docId']?.toString() ?? '',
          itemTitle: itemData['title']?.toString().trim().isNotEmpty == true
              ? itemData['title'].toString().trim()
              : 'Community item',
          itemPhotoUrl: itemData['photoUrl']?.toString().trim() ?? '',
          itemCategory: itemData['category']?.toString().trim() ?? 'others',
          itemQuantity: _readInt(itemData['quantity']),
          availabilityStatus:
              itemData['availabilityStatus']?.toString().trim() ?? 'available',
          donorId: donorId,
          donorName: _displayNameForUser(usersById[donorId], fallback: donorId, emptyLabel: 'Donor'),
          donorPhone: _phoneForUser(usersById[donorId]),
          recipientId: recipientId,
          recipientName: _displayNameForUser(
            usersById[recipientId],
            fallback: recipientId,
            emptyLabel: 'Recipient',
          ),
          recipientPhone: _phoneForUser(usersById[recipientId]),
          hubId: data['hubId']?.toString().trim() ?? hubId,
          requestStatus: data['requestStatus']?.toString().trim() ?? 'pending',
          requestNote: data['requestNote']?.toString().trim() ?? '',
          requestedAt: _readDateTime(data['requestedAt']),
          updatedAt: _readDateTime(data['updatedAt']),
          handoverId: handoverData['handoverId']?.toString().trim() ?? '',
          handoverStatus: handoverData['handoverStatus']?.toString().trim() ?? '',
          handoverType: handoverData['handoverType']?.toString().trim() ?? '',
        );
      }).toList(growable: false)
        ..sort((a, b) {
          final left = a.updatedAt ?? a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.updatedAt ?? b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });

      if (!mounted) {
        return;
      }

      setState(() {
        _hubDocId = hubDocId;
        _hubId = hubId;
        _hubName = hubName;
        _requests = records;
        _savingRequestId = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load hub handovers: $error';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, Map<String, dynamic>>> _loadUsersByIds(
    List<String> ids,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    for (final id in ids) {
      final usersDoc = await _firestore.collection('users').doc(id).get();
      final userDoc = await _firestore.collection('USER').doc(id).get();
      result[id] = {
        ...?usersDoc.data(),
        ...?userDoc.data(),
      };
    }
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _loadHandoversByRequestIds(
    List<String> requestIds,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    for (final chunk in _chunkStrings(requestIds, 10)) {
      final snapshot = await _firestore
          .collection('HANDOVER')
          .where('requestId', whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        final requestId = doc.data()['requestId']?.toString().trim() ?? '';
        if (requestId.isNotEmpty) {
          result[requestId] = {
            ...doc.data(),
            '_docId': doc.id,
          };
        }
      }
    }
    return result;
  }

  Future<void> _confirmReceived(HubHandoverRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm hub receipt?'),
        content: Text(
          'Mark "${record.itemTitle}" as received by $_hubName and ready for recipient collection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm received'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    await _updateHandoverStatus(
      record,
      nextRequestStatus: 'item_at_community_hub',
      nextHandoverStatus: 'item_at_community_hub',
      nextAvailabilityStatus: 'reserved',
      handoverFields: {
        'receivedAtHubAt': FieldValue.serverTimestamp(),
        'completedAt': null,
      },
      successMessage: 'Item marked as received by the hub.',
    );
  }

  Future<void> _confirmClaimed(HubHandoverRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm recipient claim?'),
        content: Text(
          'Mark "${record.itemTitle}" as claimed by ${record.recipientName}. This completes the handover.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm claim'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    await _updateHandoverStatus(
      record,
      nextRequestStatus: 'completed',
      nextHandoverStatus: 'completed',
      nextAvailabilityStatus: 'claimed',
      handoverFields: {
        'claimedByRecipientAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      },
      successMessage: 'Item marked as claimed by the recipient.',
    );
  }

  Future<void> _updateHandoverStatus(
    HubHandoverRecord record, {
    required String nextRequestStatus,
    required String nextHandoverStatus,
    required String nextAvailabilityStatus,
    required Map<String, dynamic> handoverFields,
    required String successMessage,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to sign in before updating handover status.')),
      );
      return;
    }

    setState(() {
      _savingRequestId = record.requestId;
    });

    try {
      final batch = _firestore.batch();

      final requestRef = _firestore.collection('ITEM_REQUEST').doc(record.docId);
      batch.update(requestRef, {
        'requestStatus': nextRequestStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final itemRef = await _resolveItemRef(record);
      if (itemRef != null) {
        batch.update(itemRef, {
          'availabilityStatus': nextAvailabilityStatus,
        });
      }

      final handoverRef = await _resolveHandoverRef(record);
      batch.set(
        handoverRef,
        {
          'handoverId': handoverRef.id,
          'requestId': record.requestId,
          'hubId': record.hubId.isNotEmpty ? record.hubId : _hubId,
          'handoverType': record.handoverType.isNotEmpty
              ? record.handoverType
              : 'community_hub_pickup',
          'handoverStatus': nextHandoverStatus,
          ...handoverFields,
        },
        SetOptions(merge: true),
      );

      final historyRef =
          _firestore.collection('DONATION_STATUS_HISTORY').doc(_historyId());
      batch.set(historyRef, {
        'statusHistoryId': historyRef.id,
        'requestId': record.requestId,
        'status': nextHandoverStatus,
        'changedAt': FieldValue.serverTimestamp(),
        'changedByUserId': userId,
      });

      await batch.commit();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      await _loadRequests();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update handover status: $error')),
      );
      setState(() {
        _savingRequestId = null;
      });
    }
  }

  Future<DocumentReference<Map<String, dynamic>>?> _resolveItemRef(
    HubHandoverRecord record,
  ) async {
    if (record.itemDocId.isNotEmpty) {
      return _firestore.collection('ITEM_LISTING').doc(record.itemDocId);
    }

    if (record.itemId.isEmpty) {
      return null;
    }

    final snapshot = await _firestore
        .collection('ITEM_LISTING')
        .where('itemId', isEqualTo: record.itemId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return snapshot.docs.first.reference;
  }

  Future<DocumentReference<Map<String, dynamic>>> _resolveHandoverRef(
    HubHandoverRecord record,
  ) async {
    if (record.handoverId.isNotEmpty) {
      return _firestore.collection('HANDOVER').doc(record.handoverId);
    }

    final snapshot = await _firestore
        .collection('HANDOVER')
        .where('requestId', isEqualTo: record.requestId)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.reference;
    }

    return _firestore.collection('HANDOVER').doc('handover_${DateTime.now().millisecondsSinceEpoch}');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingState(message: 'Loading hub handovers...');
    }

    if (_errorMessage.isNotEmpty) {
      return AppErrorState(
        message: _errorMessage,
        onRetry: _loadRequests,
      );
    }

    if (_hubId.isEmpty && _hubDocId.isEmpty) {
      return const AppEmptyState(
        icon: Icons.storefront_outlined,
        title: 'Create your hub profile first',
        message:
            'Add your COMMUNITY_HUB record before confirming donor deliveries and recipient collections.',
      );
    }

    return RefreshIndicator(
      color: AppColors.mint,
      onRefresh: _loadRequests,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (_requests.isEmpty)
            const AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No hub handovers waiting',
              message:
                  'Requests assigned to this hub will appear here once a donor starts the delivery.',
            )
          else
            for (final request in _requests) ...[
              _HandoverCard(
                request: request,
                isSaving: _savingRequestId == request.requestId,
                onConfirmReceived: () => _confirmReceived(request),
                onConfirmClaimed: () => _confirmClaimed(request),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }

  static List<List<String>> _chunkStrings(List<String> values, int size) {
    final chunks = <List<String>>[];
    for (var index = 0; index < values.length; index += size) {
      final end = (index + size) > values.length ? values.length : index + size;
      chunks.add(values.sublist(index, end));
    }
    return chunks;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 1;
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

  static String _displayNameForUser(
    Map<String, dynamic>? data, {
    required String fallback,
    required String emptyLabel,
  }) {
    if (data == null || data.isEmpty) {
      return fallback.isNotEmpty ? fallback : emptyLabel;
    }

    final fullName = data['fullName']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) {
      return fullName;
    }

    final displayName = data['displayName']?.toString().trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final username = data['username']?.toString().trim() ?? '';
    if (username.isNotEmpty) {
      return username;
    }

    return fallback.isNotEmpty ? fallback : emptyLabel;
  }

  static String _phoneForUser(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return 'Phone not provided';
    }

    final phone = data['phoneNumber']?.toString().trim() ?? '';
    if (phone.isNotEmpty) {
      return phone;
    }

    final phoneCode = data['phoneCountryCode']?.toString().trim() ?? '';
    final localPhone = data['phoneLocalNumber']?.toString().trim() ?? '';
    final combined = [phoneCode, localPhone]
        .where((value) => value.isNotEmpty)
        .join(' ')
        .trim();
    return combined.isNotEmpty ? combined : 'Phone not provided';
  }

  static String _effectiveStatus(HubHandoverRecord record) {
    final handoverStatus = record.handoverStatus.toLowerCase();
    if (handoverStatus == 'delivering') {
      return record.hubId.isEmpty ? 'delivering_to_recipient' : 'delivering_to_hub';
    }
    if (handoverStatus.isNotEmpty) {
      return handoverStatus;
    }
    return record.requestStatus.toLowerCase();
  }

  String _historyId() {
    return 'status_${DateTime.now().millisecondsSinceEpoch}';
  }
}

class HubHandoverRecord {
  const HubHandoverRecord({
    required this.requestId,
    required this.docId,
    required this.itemId,
    required this.itemDocId,
    required this.itemTitle,
    required this.itemPhotoUrl,
    required this.itemCategory,
    required this.itemQuantity,
    required this.availabilityStatus,
    required this.donorId,
    required this.donorName,
    required this.donorPhone,
    required this.recipientId,
    required this.recipientName,
    required this.recipientPhone,
    required this.hubId,
    required this.requestStatus,
    required this.requestNote,
    required this.requestedAt,
    required this.updatedAt,
    required this.handoverId,
    required this.handoverStatus,
    required this.handoverType,
  });

  final String requestId;
  final String docId;
  final String itemId;
  final String itemDocId;
  final String itemTitle;
  final String itemPhotoUrl;
  final String itemCategory;
  final int itemQuantity;
  final String availabilityStatus;
  final String donorId;
  final String donorName;
  final String donorPhone;
  final String recipientId;
  final String recipientName;
  final String recipientPhone;
  final String hubId;
  final String requestStatus;
  final String requestNote;
  final DateTime? requestedAt;
  final DateTime? updatedAt;
  final String handoverId;
  final String handoverStatus;
  final String handoverType;
}

class _HandoverCard extends StatelessWidget {
  const _HandoverCard({
    required this.request,
    required this.isSaving,
    required this.onConfirmReceived,
    required this.onConfirmClaimed,
  });

  final HubHandoverRecord request;
  final bool isSaving;
  final VoidCallback onConfirmReceived;
  final VoidCallback onConfirmClaimed;

  @override
  Widget build(BuildContext context) {
    final effectiveStatus =
        _HubHandoverConfirmationPageState._effectiveStatus(request);
    final canConfirmReceived = effectiveStatus == 'delivering_to_hub';
    final canConfirmClaimed = effectiveStatus == 'item_at_community_hub';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: request.itemPhotoUrl.isNotEmpty
                        ? ImageUtils.base64ToImage(
                            request.itemPhotoUrl,
                            fit: BoxFit.cover,
                            errorWidget: itemImageFallback(),
                          )
                        : itemImageFallback(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.itemTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _StatusPill(
                            label: titleCaseLabel(effectiveStatus),
                            color: requestStatusColor(effectiveStatus),
                          ),
                          _StatusPill(
                            label: titleCaseLabel(request.availabilityStatus),
                            color: requestStatusColor(request.availabilityStatus),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _InfoLine(label: 'Recipient', value: request.recipientName),
            _InfoLine(label: 'Recipient Phone', value: request.recipientPhone),
            _InfoLine(label: 'Donor', value: request.donorName),
            _InfoLine(label: 'Donor Phone', value: request.donorPhone),
            _InfoLine(label: 'Category', value: titleCaseLabel(request.itemCategory)),
            _InfoLine(label: 'Quantity', value: '${request.itemQuantity}'),
            _InfoLine(label: 'Requested', value: formatRequestDateTime(request.requestedAt)),
            _InfoLine(label: 'Updated', value: formatRequestDateTime(request.updatedAt)),
            if (request.requestNote.isNotEmpty)
              _InfoLine(label: 'Note', value: request.requestNote),
            const SizedBox(height: AppSpacing.md),
            if (isSaving)
              const AppLoadingState(message: 'Updating handover...')
            else if (canConfirmReceived)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onConfirmReceived,
                  icon: const Icon(Icons.inventory_rounded),
                  label: const Text('Mark Received by Hub'),
                ),
              )
            else if (canConfirmClaimed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onConfirmClaimed,
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('Mark Claimed by Recipient'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.slate,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not set',
              style: const TextStyle(color: AppColors.mist),
            ),
          ),
        ],
      ),
    );
  }
}
