import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import 'donor_request_details_page.dart';
import '../../utils/image_utils.dart';
import '../../widgets/state_widgets.dart';

class DonorIncomingRequestsPage extends StatefulWidget {
  const DonorIncomingRequestsPage({super.key});

  @override
  State<DonorIncomingRequestsPage> createState() =>
      _DonorIncomingRequestsPageState();
}

class _DonorIncomingRequestsPageState extends State<DonorIncomingRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  static const int _requestsPerPage = 8;
  bool _isLoading = true;
  String _errorMessage = '';
  List<DonorIncomingRequestRecord> _requests = const [];
  List<DonorIncomingRequestRecord> _filteredRequests = const [];
  int _currentPage = 0;

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
      final donorId = _auth.currentUser?.uid;
      if (donorId == null) {
        throw Exception('User not authenticated');
      }

      final listingSnapshot = await _firestore
          .collection('ITEM_LISTING')
          .where('donorId', isEqualTo: donorId)
          .get();

      final listingsByItemId = <String, Map<String, dynamic>>{
        for (final doc in listingSnapshot.docs)
          (doc.data()['itemId']?.toString().trim().isNotEmpty ?? false)
              ? doc.data()['itemId'].toString().trim()
              : doc.id: {
            ...doc.data(),
            '_docId': doc.id,
          },
      };

      if (listingsByItemId.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _requests = const [];
          _isLoading = false;
        });
        return;
      }

      final requestDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final itemIds = listingsByItemId.keys.toList(growable: false);
      for (final chunk in _chunkStrings(itemIds, 10)) {
        final snapshot = await _firestore
            .collection('ITEM_REQUEST')
            .where('itemId', whereIn: chunk)
            .get();
        requestDocs.addAll(snapshot.docs);
      }

      final recipientIds = requestDocs
          .map((doc) => doc.data()['recipientId']?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final hubIds = requestDocs
          .map((doc) => doc.data()['hubId']?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final usersById = await _loadUsersByIds(recipientIds);
      final hubsById = await _loadUsersByIds(hubIds);

      final requests = requestDocs.map((doc) {
        final data = doc.data();
        final itemId = data['itemId']?.toString().trim() ?? '';
        final itemData = listingsByItemId[itemId] ?? const <String, dynamic>{};
        final recipientId = data['recipientId']?.toString().trim() ?? '';
        final hubId = data['hubId']?.toString().trim() ?? '';

        return DonorIncomingRequestRecord(
          requestId: data['requestId']?.toString().trim().isNotEmpty == true
              ? data['requestId'].toString().trim()
              : doc.id,
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
          recipientId: recipientId,
          recipientName: _displayNameForUser(usersById[recipientId]),
          recipientPhone: _phoneForUser(usersById[recipientId]),
          recipientLocation: _locationForUser(usersById[recipientId]),
          hubId: hubId,
          hubName: _displayNameForHub(hubsById[hubId], hubId),
          requestNote: data['requestNote']?.toString().trim() ?? '',
          requestStatus: data['requestStatus']?.toString().trim() ?? 'pending',
          handoverStatus: '',
          requestedAt: _readDateTime(data['requestedAt']),
          updatedAt: _readDateTime(data['updatedAt']),
        );
      }).toList(growable: false)
        ..sort((a, b) {
          final left = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });

      if (!mounted) {
        return;
      }

      setState(() {
        _requests = requests;
        _filteredRequests = _applyFilters(requests, _searchController.text);
        _currentPage = 0;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load incoming requests: $error';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, Map<String, dynamic>>> _loadUsersByIds(
    List<String> ids,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    for (final id in ids) {
      final usersDoc = await _firestore.collection('USER').doc(id).get();
      final userDoc = await _firestore.collection('USER').doc(id).get();
      result[id] = {
        ...?usersDoc.data(),
        ...?userDoc.data(),
      };
    }
    return result;
  }

  void _filterRequests() {
    setState(() {
      _filteredRequests = _applyFilters(_requests, _searchController.text);
      _currentPage = 0;
    });
  }

  List<DonorIncomingRequestRecord> _applyFilters(
    List<DonorIncomingRequestRecord> requests,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return requests;
    }

    return requests.where((request) {
      return request.itemTitle.toLowerCase().contains(normalizedQuery) ||
          request.recipientName.toLowerCase().contains(normalizedQuery) ||
          request.requestNote.toLowerCase().contains(normalizedQuery) ||
          request.requestStatus.toLowerCase().contains(normalizedQuery) ||
          request.itemCategory.toLowerCase().contains(normalizedQuery) ||
          request.hubName.toLowerCase().contains(normalizedQuery) ||
          request.itemId.toLowerCase().contains(normalizedQuery) ||
          request.recipientId.toLowerCase().contains(normalizedQuery) ||
          request.hubId.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  int get _totalPages {
    if (_filteredRequests.isEmpty) {
      return 1;
    }
    return (_filteredRequests.length / _requestsPerPage).ceil();
  }

  List<DonorIncomingRequestRecord> get _paginatedRequests {
    final start = _currentPage * _requestsPerPage;
    if (start >= _filteredRequests.length) {
      return const [];
    }
    final end = (start + _requestsPerPage).clamp(0, _filteredRequests.length);
    return _filteredRequests.sublist(start, end);
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) {
      return;
    }
    setState(() => _currentPage = page);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingState(message: 'Loading incoming requests...');
    }

    if (_errorMessage.isNotEmpty) {
      return AppErrorState(
        message: _errorMessage,
        onRetry: _loadRequests,
      );
    }

    if (_requests.isEmpty) {
      return const AppEmptyState(
        icon: Icons.inbox_outlined,
        title: 'No incoming requests yet',
        message:
            'Requests from recipients will appear here once someone asks for one of your listings.',
      );
    }

    if (_filteredRequests.isEmpty) {
      return RefreshIndicator(
        color: AppColors.mint,
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => _searchController.clear(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                hintText: 'Search incoming requests',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching requests',
              message: 'Try a different search term.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.mint,
      onRefresh: _loadRequests,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => _searchController.clear(),
                      icon: const Icon(Icons.close_rounded),
                    ),
              hintText: 'Search incoming requests',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ..._paginatedRequests.map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () async {
                  final updated = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => DonorRequestDetailsPage(request: request),
                    ),
                  );
                  if (updated == true && mounted) {
                    await _loadRequests();
                  }
                },
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: SizedBox(
                            width: 68,
                            height: 68,
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                request.recipientName,
                                style: const TextStyle(color: AppColors.mist),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                formatRequestDateTime(request.requestedAt),
                                style: const TextStyle(
                                  color: AppColors.slate,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  _RequestChip(
                                    label: titleCaseLabel(request.requestStatus),
                                    color: requestStatusColor(request.requestStatus),
                                  ),
                                  if (request.hubId.isNotEmpty)
                                    _RequestChip(
                                      label: 'Hub linked',
                                      color: AppColors.pine,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.mist,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_requests.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _PaginationBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPrevious:
                  _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
              onNext: _currentPage + 1 < _totalPages
                  ? () => _goToPage(_currentPage + 1)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  static List<List<String>> _chunkStrings(List<String> values, int size) {
    final chunks = <List<String>>[];
    for (var i = 0; i < values.length; i += size) {
      final end = (i + size) > values.length ? values.length : i + size;
      chunks.add(values.sublist(i, end));
    }
    return chunks;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
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

  static String _displayNameForUser(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return 'Recipient';
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

    return 'Recipient';
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

  static String _locationForUser(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return 'Location not provided';
    }

    final parts = [
      data['city']?.toString().trim() ?? '',
      data['state']?.toString().trim() ?? '',
      data['country']?.toString().trim() ?? '',
    ].where((value) => value.isNotEmpty).toList(growable: false);

    return parts.isNotEmpty ? parts.join(', ') : 'Location not provided';
  }

  static String _displayNameForHub(
    Map<String, dynamic>? data,
    String hubId,
  ) {
    if (hubId.isEmpty) {
      return 'No hub selected';
    }

    if (data == null || data.isEmpty) {
      return hubId;
    }

    final hubName = data['hubName']?.toString().trim() ?? '';
    if (hubName.isNotEmpty) {
      return hubName;
    }

    final displayName = data['displayName']?.toString().trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final fullName = data['fullName']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) {
      return fullName;
    }

    return hubId;
  }

}

class DonorIncomingRequestRecord {
  const DonorIncomingRequestRecord({
    required this.requestId,
    required this.docId,
    required this.itemId,
    required this.itemDocId,
    required this.itemTitle,
    required this.itemPhotoUrl,
    required this.itemCategory,
    required this.itemQuantity,
    required this.availabilityStatus,
    required this.recipientId,
    required this.recipientName,
    required this.recipientPhone,
    required this.recipientLocation,
    required this.hubId,
    required this.hubName,
    required this.requestNote,
    required this.requestStatus,
    required this.handoverStatus,
    required this.requestedAt,
    required this.updatedAt,
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
  final String recipientId;
  final String recipientName;
  final String recipientPhone;
  final String recipientLocation;
  final String hubId;
  final String hubName;
  final String requestNote;
  final String requestStatus;
  final String handoverStatus;
  final DateTime? requestedAt;
  final DateTime? updatedAt;
}

class _RequestChip extends StatelessWidget {
  const _RequestChip({
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

String formatRequestDateTime(DateTime? value) {
  if (value == null) {
    return 'Not set';
  }
  return DateFormat('MMM d, yyyy h:mm a').format(value);
}

String titleCaseLabel(String value) {
  if (value.trim().isEmpty) {
    return 'Unknown';
  }
  if (value.toLowerCase() == 'completed') {
    return 'Item Handed To Intended Recipient';
  }
  return value
      .split('_')
      .map((part) {
        if (part.isEmpty) {
          return part;
        }
        return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
      })
      .join(' ');
}

Color requestStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return AppColors.mint;
    case 'reserved':
      return AppColors.sun;
    case 'delivering':
    case 'delivering_to_hub':
    case 'delivering_to_recipient':
      return AppColors.sun;
    case 'item_at_community_hub':
    case 'claimed':
      return AppColors.pine;
    case 'handover_scheduled':
      return AppColors.sun;
    case 'completed':
      return AppColors.pine;
    case 'rejected':
    case 'cancelled':
      return AppColors.coral;
    default:
      return AppColors.sun;
  }
}

Widget itemImageFallback() {
  return Container(
    color: AppColors.forest,
    alignment: Alignment.center,
    child: const Icon(
      Icons.inventory_2_outlined,
      color: AppColors.mint,
      size: 28,
    ),
  );
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
