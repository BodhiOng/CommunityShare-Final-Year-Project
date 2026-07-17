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
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _errorMessage = '';
  String _hubDocId = '';
  String _hubId = '';
  String _hubName = '';
  bool _showFilters = false;
  List<HubHandoverRecord> _requests = const [];
  List<HubHandoverRecord> _filteredRequests = const [];
  int _currentPage = 0;
  String _selectedStatus = 'All';
  String _selectedCategory = 'All';

  static const int _requestsPerPage = 8;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterRequests);
    _loadRequests();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterRequests);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
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
        _filteredRequests = _applyFilters(records);
        _currentPage = 0;
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

  Future<bool> _confirmReceived(HubHandoverRecord record) async {
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
      return false;
    }

    return _updateHandoverStatus(
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

  Future<bool> _confirmClaimed(HubHandoverRecord record) async {
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
      return false;
    }

    return _updateHandoverStatus(
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

  Future<bool> _updateHandoverStatus(
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
      return false;
    }

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
        return false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      await _loadRequests();
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update handover status: $error')),
      );
      return false;
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

  void _filterRequests() {
    setState(() {
      _filteredRequests = _applyFilters(_requests);
      _currentPage = 0;
    });
  }

  List<HubHandoverRecord> _applyFilters(List<HubHandoverRecord> source) {
    final normalizedQuery = _searchController.text.trim().toLowerCase();

    return source.where((request) {
      final haystack = <String>[
        request.itemTitle,
        request.itemCategory,
        request.requestId,
        request.recipientName,
        request.donorName,
        request.requestNote,
        request.requestStatus,
        request.handoverStatus,
        request.availabilityStatus,
      ].join(' ').toLowerCase();

      final matchesSearch =
          normalizedQuery.isEmpty || haystack.contains(normalizedQuery);
      final matchesStatus = _selectedStatus == 'All' ||
          _effectiveStatus(request) == _selectedStatus.toLowerCase();
      final matchesCategory = _selectedCategory == 'All' ||
          request.itemCategory.toLowerCase() == _selectedCategory.toLowerCase();

      return matchesSearch && matchesStatus && matchesCategory;
    }).toList(growable: false);
  }

  List<String> get _statusOptions {
    final values = _requests
        .map(_effectiveStatus)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  List<String> get _categoryOptions {
    final values = _requests
        .map((request) => request.itemCategory)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  List<HubHandoverRecord> get _paginatedRequests {
    if (_filteredRequests.isEmpty) {
      return const [];
    }

    final start = _currentPage * _requestsPerPage;
    if (start >= _filteredRequests.length) {
      return const [];
    }

    final end = (start + _requestsPerPage) > _filteredRequests.length
        ? _filteredRequests.length
        : start + _requestsPerPage;
    return _filteredRequests.sublist(start, end);
  }

  int get _totalPages {
    if (_filteredRequests.isEmpty) {
      return 1;
    }
    return (_filteredRequests.length / _requestsPerPage).ceil();
  }

  void _goToPage(int page) {
    final clamped = page.clamp(0, _totalPages - 1);
    if (clamped == _currentPage) {
      return;
    }

    setState(() {
      _currentPage = clamped;
    });
  }

  Future<void> _openHandoverDetails(HubHandoverRecord request) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _HubHandoverDetailsPage(
          request: request,
          hubName: _hubName,
          onConfirmReceived: _confirmReceived,
          onConfirmClaimed: _confirmClaimed,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _loadRequests();
    }
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
          else ...[
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by item, donor, recipient, or status',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _HeaderPill(
                    icon: Icons.inventory_2_outlined,
                    label: '${_filteredRequests.length} shown',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _HeaderPill(
                    icon: Icons.account_tree_outlined,
                    label: 'Page ${_currentPage + 1} of $_totalPages',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                        _currentPage = 0;
                      });
                    },
                    icon: Icon(
                      _showFilters
                          ? Icons.filter_alt_off_rounded
                          : Icons.tune_rounded,
                    ),
                    label: Text(_showFilters ? 'Hide filters' : 'Filters'),
                  ),
                ],
              ),
            ),
            if (_showFilters) ...[
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                        ),
                        items: _statusOptions
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option,
                                child: Text(
                                  option == 'All'
                                      ? option
                                      : titleCaseLabel(option),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedStatus = value;
                            _filteredRequests = _applyFilters(_requests);
                            _currentPage = 0;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: _categoryOptions
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option,
                                child: Text(
                                  option == 'All'
                                      ? option
                                      : formatCategoryLabel(option),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedCategory = value;
                            _filteredRequests = _applyFilters(_requests);
                            _currentPage = 0;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (_filteredRequests.isEmpty)
              const AppEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matching handovers',
                message: 'Try a different search term to find the handover you need.',
              )
            else ...[
              for (final request in _paginatedRequests) ...[
                _HandoverCard(
                  request: request,
                  onTap: () => _openHandoverDetails(request),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _PaginationBar(
                currentPage: _currentPage,
                totalPages: _totalPages,
                onPrevious: _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
                onNext: (_currentPage + 1) < _totalPages
                    ? () => _goToPage(_currentPage + 1)
                    : null,
              ),
            ],
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

String formatCategoryLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'Others';
  }

  return trimmed
      .split('_')
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
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

  HubHandoverRecord copyWith({
    String? availabilityStatus,
    String? requestStatus,
    DateTime? updatedAt,
    String? handoverStatus,
  }) {
    return HubHandoverRecord(
      requestId: requestId,
      docId: docId,
      itemId: itemId,
      itemDocId: itemDocId,
      itemTitle: itemTitle,
      itemPhotoUrl: itemPhotoUrl,
      itemCategory: itemCategory,
      itemQuantity: itemQuantity,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      donorId: donorId,
      donorName: donorName,
      donorPhone: donorPhone,
      recipientId: recipientId,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      hubId: hubId,
      requestStatus: requestStatus ?? this.requestStatus,
      requestNote: requestNote,
      requestedAt: requestedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      handoverId: handoverId,
      handoverStatus: handoverStatus ?? this.handoverStatus,
      handoverType: handoverType,
    );
  }
}

class _HandoverCard extends StatelessWidget {
  const _HandoverCard({
    required this.request,
    required this.onTap,
  });

  final HubHandoverRecord request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveStatus =
        _HubHandoverConfirmationPageState._effectiveStatus(request);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
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
                          label: formatCategoryLabel(request.itemCategory),
                          color: AppColors.mint,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${request.recipientName} • ${request.donorName}',
                      style: const TextStyle(
                        color: AppColors.mist,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Updated ${formatRequestDateTime(request.updatedAt)}',
                      style: const TextStyle(color: AppColors.slate),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubHandoverDetailsPage extends StatefulWidget {
  const _HubHandoverDetailsPage({
    required this.request,
    required this.hubName,
    required this.onConfirmReceived,
    required this.onConfirmClaimed,
  });

  final HubHandoverRecord request;
  final String hubName;
  final Future<bool> Function(HubHandoverRecord record) onConfirmReceived;
  final Future<bool> Function(HubHandoverRecord record) onConfirmClaimed;

  @override
  State<_HubHandoverDetailsPage> createState() => _HubHandoverDetailsPageState();
}

class _HubHandoverDetailsPageState extends State<_HubHandoverDetailsPage> {
  late HubHandoverRecord _request = widget.request;
  bool _isSaving = false;

  Future<void> _handleConfirmReceived() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final changed = await widget.onConfirmReceived(_request);
      if (!mounted) {
        return;
      }
      if (changed) {
        setState(() {
          _request = _request.copyWith(
            requestStatus: 'item_at_community_hub',
            handoverStatus: 'item_at_community_hub',
            availabilityStatus: 'reserved',
            updatedAt: DateTime.now(),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _handleConfirmClaimed() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final changed = await widget.onConfirmClaimed(_request);
      if (!mounted) {
        return;
      }
      if (changed) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final effectiveStatus =
        _HubHandoverConfirmationPageState._effectiveStatus(request);
    final canConfirmReceived = effectiveStatus == 'delivering_to_hub';
    final canConfirmClaimed = effectiveStatus == 'item_at_community_hub';

    return Scaffold(
      appBar: AppBar(title: const Text('Handover Details')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: SizedBox(
                          width: 88,
                          height: 88,
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
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.sm),
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
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Request ID: ${request.requestId}',
                              style: const TextStyle(color: AppColors.slate),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _InfoLine(
                    label: 'Hub',
                    value: widget.hubName.isNotEmpty
                        ? widget.hubName
                        : 'Community Hub',
                  ),
                  _InfoLine(label: 'Recipient', value: request.recipientName),
                  _InfoLine(label: 'Recipient Phone', value: request.recipientPhone),
                  _InfoLine(label: 'Donor', value: request.donorName),
                  _InfoLine(label: 'Donor Phone', value: request.donorPhone),
                  _InfoLine(label: 'Category', value: formatCategoryLabel(request.itemCategory)),
                  _InfoLine(label: 'Quantity', value: '${request.itemQuantity}'),
                  _InfoLine(label: 'Requested', value: formatRequestDateTime(request.requestedAt)),
                  _InfoLine(label: 'Updated', value: formatRequestDateTime(request.updatedAt)),
                  if (request.requestNote.isNotEmpty)
                    _InfoLine(label: 'Note', value: request.requestNote),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_isSaving)
            const AppLoadingState(message: 'Updating handover...')
          else if (canConfirmReceived)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleConfirmReceived,
                icon: const Icon(Icons.inventory_rounded),
                label: const Text('Mark Received by Hub'),
              ),
            )
          else if (canConfirmClaimed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleConfirmClaimed,
                icon: const Icon(Icons.assignment_turned_in_outlined),
                label: const Text('Mark Claimed by Recipient'),
              ),
            ),
        ],
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

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
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
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.mint.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.mint),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.sand,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Page ${currentPage + 1} of $totalPages',
          style: const TextStyle(
            color: AppColors.sand,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          color: onPrevious == null ? AppColors.slate : AppColors.mint,
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          color: onNext == null ? AppColors.slate : AppColors.mint,
        ),
      ],
    );
  }
}
