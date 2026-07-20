import 'dart:math';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants.dart';
import '../recipient/recipient_browse_community_hubs_page.dart';
import '../../services/image_storage_service.dart';
import '../../utils/image_utils.dart';

final Random _idRandom = Random.secure();

String _newThirteenDigitId(String prefix) {
  final digits = List.generate(13, (_) => _idRandom.nextInt(10)).join();
  return '${prefix}_$digits';
}

class DonorListingPage extends StatefulWidget {
  const DonorListingPage({super.key});

  @override
  State<DonorListingPage> createState() => _DonorListingPageState();
}

class _DonorListingPageState extends State<DonorListingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  List<DonorListingItem> _items = [];
  List<DonorListingItem> _filteredItems = [];
  int _currentPage = 0;
  static const int _itemsPerPage = 8;
  final Set<String> _selectedForDelete = <String>{};
  bool _deleteMode = false;
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedAvailabilityFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    _fetchDonations();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDonations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final donorId = _auth.currentUser?.uid;
      if (donorId == null) {
        throw Exception('User not authenticated');
      }

      final snapshot =
          await _firestore
              .collection('ITEM_LISTING')
              .where('donorId', isEqualTo: donorId)
              .get();

      final items =
          snapshot.docs
              .map((doc) => DonorListingItem.fromFirestore(doc.data(), doc.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _filteredItems = _applyFilters(items, _searchController.text);
        _currentPage = 0;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load donations: $error';
      });
    }
  }

  void _filterItems() {
    setState(() {
      _filteredItems = _applyFilters(_items, _searchController.text);
      _currentPage = 0;
      _selectedForDelete.removeWhere(
        (docId) => !_filteredItems.any((item) => item.docId == docId),
      );
    });
  }

  void _setAvailabilityFilter(String value) {
    if (_selectedAvailabilityFilter == value) {
      return;
    }

    setState(() {
      _selectedAvailabilityFilter = value;
      _filteredItems = _applyFilters(_items, _searchController.text);
      _currentPage = 0;
      _selectedForDelete.removeWhere(
        (docId) => !_filteredItems.any((item) => item.docId == docId),
      );
    });
  }

  List<DonorListingItem> _applyFilters(
    List<DonorListingItem> items,
    String query,
  ) {
    final normalizedAvailability =
        _selectedAvailabilityFilter.trim().toLowerCase();
    final normalizedQuery = query.trim().toLowerCase();
    return items.where((item) {
      final matchesAvailability =
          normalizedAvailability == 'all' ||
          item.availabilityStatus.toLowerCase() == normalizedAvailability;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          item.title.toLowerCase().contains(normalizedQuery) ||
          item.description.toLowerCase().contains(normalizedQuery) ||
          item.category.toLowerCase().contains(normalizedQuery) ||
          item.condition.toLowerCase().contains(normalizedQuery) ||
          item.availabilityStatus.toLowerCase().contains(normalizedQuery) ||
          item.itemId.toLowerCase().contains(normalizedQuery);
      return matchesAvailability && matchesQuery;
    }).toList();
  }

  int get _totalPages {
    if (_filteredItems.isEmpty) {
      return 1;
    }
    return (_filteredItems.length / _itemsPerPage).ceil();
  }

  List<DonorListingItem> get _paginatedItems {
    final start = _currentPage * _itemsPerPage;
    if (start >= _filteredItems.length) {
      return const [];
    }
    final end = (start + _itemsPerPage).clamp(0, _filteredItems.length);
    return _filteredItems.sublist(start, end);
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) {
      return;
    }
    setState(() => _currentPage = page);
  }

  Future<void> _openDonationForm({DonorListingItem? item}) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Material(
            color: Colors.transparent,
            child: _DonationFormSheet(item: item),
          ),
    );

    if (updated == true) {
      await _fetchDonations();
    }
  }

  void _toggleDeleteMode() {
    setState(() {
      _deleteMode = !_deleteMode;
      if (!_deleteMode) {
        _selectedForDelete.clear();
      }
    });
  }

  Widget _buildAvailabilityFilterChip({
    required String label,
    required String value,
  }) {
    final selected = _selectedAvailabilityFilter == value;
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      label: Text(label),
      onSelected: (_) => _setAvailabilityFilter(value),
      backgroundColor: AppColors.forest,
      selectedColor: AppColors.mint.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        color: selected ? AppColors.mint : AppColors.sand,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: selected ? AppColors.mint : AppColors.pine),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  void _toggleSelectedForDelete(String docId) {
    setState(() {
      if (_selectedForDelete.contains(docId)) {
        _selectedForDelete.remove(docId);
      } else {
        _selectedForDelete.add(docId);
      }
    });
  }

  Future<void> _deleteSelectedDonations() async {
    if (_selectedForDelete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select one or more donations to delete.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.forest,
          title: const Text('Delete donations'),
          content: Text(
            'Remove ${_selectedForDelete.length} selected donation${_selectedForDelete.length == 1 ? '' : 's'} from your listings?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      final selectedCount = _selectedForDelete.length;
      final deletedRelatedCount =
          await _deleteSelectedListingsAndRelatedRecords(_selectedForDelete);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted $selectedCount donation${selectedCount == 1 ? '' : 's'} and $deletedRelatedCount related record${deletedRelatedCount == 1 ? '' : 's'}.',
          ),
        ),
      );
      setState(() {
        _selectedForDelete.clear();
        _deleteMode = false;
      });
      await _fetchDonations();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete donation: $error')),
      );
    }
  }

  Future<int> _deleteSelectedListingsAndRelatedRecords(
    Iterable<String> listingDocIds,
  ) async {
    final listingRefsByPath =
        <String, DocumentReference<Map<String, dynamic>>>{};
    final relatedRefsByPath =
        <String, DocumentReference<Map<String, dynamic>>>{};
    final knownItemsByDocId = {for (final item in _items) item.docId: item};

    void addListingRef(DocumentReference<Map<String, dynamic>> ref) {
      listingRefsByPath[ref.path] = ref;
    }

    void addRelatedRef(DocumentReference<Map<String, dynamic>> ref) {
      relatedRefsByPath[ref.path] = ref;
    }

    for (final listingDocId in listingDocIds) {
      final listingRef = _firestore
          .collection('ITEM_LISTING')
          .doc(listingDocId);
      addListingRef(listingRef);

      final knownItem = knownItemsByDocId[listingDocId];
      var itemId = knownItem?.itemId.trim() ?? '';

      if (itemId.isEmpty) {
        final listingSnapshot = await listingRef.get();
        final listingData = listingSnapshot.data();
        itemId = listingData?['itemId']?.toString().trim() ?? listingDocId;
      }

      if (itemId.isEmpty) {
        itemId = listingDocId;
      }

      final requestSnapshot =
          await _firestore
              .collection('ITEM_REQUEST')
              .where('itemId', isEqualTo: itemId)
              .get();

      final requestIds = <String>{};
      for (final requestDoc in requestSnapshot.docs) {
        addRelatedRef(requestDoc.reference);
        final storedRequestId =
            requestDoc.data()['requestId']?.toString().trim() ?? '';
        final requestId =
            storedRequestId.isNotEmpty ? storedRequestId : requestDoc.id;
        if (requestId.isNotEmpty) {
          requestIds.add(requestId);
        }
      }

      for (final requestId in requestIds) {
        final handoverSnapshot =
            await _firestore
                .collection('HANDOVER')
                .where('requestId', isEqualTo: requestId)
                .get();
        for (final handoverDoc in handoverSnapshot.docs) {
          addRelatedRef(handoverDoc.reference);
        }

        final historySnapshot =
            await _firestore
                .collection('DONATION_STATUS_HISTORY')
                .where('requestId', isEqualTo: requestId)
                .get();
        for (final historyDoc in historySnapshot.docs) {
          addRelatedRef(historyDoc.reference);
        }
      }
    }

    await _deleteDocumentRefs([
      ...relatedRefsByPath.values,
      ...listingRefsByPath.values,
    ]);

    return relatedRefsByPath.length;
  }

  Future<void> _deleteDocumentRefs(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    const batchSize = 450;
    for (var index = 0; index < refs.length; index += batchSize) {
      final batch = _firestore.batch();
      final end =
          index + batchSize > refs.length ? refs.length : index + batchSize;
      for (final ref in refs.sublist(index, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.night,
        appBar: AppBar(
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          title: const SizedBox.shrink(),
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              color: AppColors.mint,
              onRefresh: _fetchDonations,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  112,
                ),
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon:
                          _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                onPressed: () => _searchController.clear(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                      hintText: 'Search your donations',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: 6,
                      separatorBuilder:
                          (_, __) => const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        switch (index) {
                          case 0:
                            return _buildAvailabilityFilterChip(
                              label: 'All',
                              value: 'all',
                            );
                          case 1:
                            return _buildAvailabilityFilterChip(
                              label: 'Available',
                              value: 'available',
                            );
                          case 2:
                            return _buildAvailabilityFilterChip(
                              label: 'Reserved',
                              value: 'reserved',
                            );
                          case 3:
                            return _buildAvailabilityFilterChip(
                              label: 'Claimed',
                              value: 'claimed',
                            );
                          case 4:
                            return _buildAvailabilityFilterChip(
                              label: 'Deactivated',
                              value: 'deactivated',
                            );
                          default:
                            return _buildAvailabilityFilterChip(
                              label: 'Expired',
                              value: 'expired',
                            );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _deleteMode
                                ? '${_selectedForDelete.length} selected'
                                : 'Select items to remove them in a batch',
                            style: const TextStyle(
                              color: AppColors.sand,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _toggleDeleteMode,
                          icon: Icon(
                            _deleteMode
                                ? Icons.close_rounded
                                : Icons.checklist_rounded,
                          ),
                          label: Text(_deleteMode ? 'Cancel' : 'Select'),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                _deleteMode ? AppColors.sand : AppColors.mint,
                          ),
                        ),
                        if (_deleteMode) ...[
                          const SizedBox(width: AppSpacing.sm),
                          TextButton.icon(
                            onPressed: _deleteSelectedDonations,
                            icon: const Icon(Icons.delete_forever_outlined),
                            label: Text(
                              'Delete (${_selectedForDelete.length})',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.coral,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.xl),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.mint),
                      ),
                    )
                  else if (_errorMessage.isNotEmpty)
                    _ErrorPanel(
                      message: _errorMessage,
                      onRetry: _fetchDonations,
                    )
                  else if (_filteredItems.isEmpty)
                    _EmptyDonationsPanel(
                      hasSearch: _searchController.text.trim().isNotEmpty,
                      onAddPressed: () => _openDonationForm(),
                    )
                  else
                    ..._paginatedItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _DonationCard(
                          item: item,
                          deleteMode: _deleteMode,
                          isSelected: _selectedForDelete.contains(item.docId),
                          onEdit: () => _openDonationForm(item: item),
                          onToggleSelected:
                              () => _toggleSelectedForDelete(item.docId),
                        ),
                      ),
                    ),
                  if (_filteredItems.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _PaginationBar(
                      currentPage: _currentPage,
                      totalPages: _totalPages,
                      onPrevious:
                          _currentPage > 0
                              ? () => _goToPage(_currentPage - 1)
                              : null,
                      onNext:
                          _currentPage + 1 < _totalPages
                              ? () => _goToPage(_currentPage + 1)
                              : null,
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: FloatingActionButton.extended(
                onPressed: () => _openDonationForm(),
                backgroundColor: AppColors.mint,
                foregroundColor: AppColors.night,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New Donation'),
              ),
            ),
          ],
        ),
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

class DonorListingItem {
  const DonorListingItem({
    required this.docId,
    required this.itemId,
    required this.title,
    required this.description,
    required this.donorId,
    required this.category,
    required this.condition,
    required this.photoUrl,
    required this.quantity,
    required this.availabilityStatus,
    required this.allowsIndependentPickup,
    required this.allowsCommunityHubPickup,
    required this.hubId,
    required this.hubName,
    required this.createdAt,
    this.expiryDate,
  });

  final String docId;
  final String itemId;
  final String title;
  final String description;
  final String donorId;
  final String category;
  final String condition;
  final String photoUrl;
  final int quantity;
  final String availabilityStatus;
  final bool allowsIndependentPickup;
  final bool allowsCommunityHubPickup;
  final String hubId;
  final String hubName;
  final DateTime createdAt;
  final DateTime? expiryDate;

  factory DonorListingItem.fromFirestore(
    Map<String, dynamic> data,
    String docId,
  ) {
    return DonorListingItem(
      docId: docId,
      itemId: data['itemId']?.toString() ?? docId,
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      donorId: data['donorId']?.toString() ?? '',
      category:
          data['category']?.toString() ?? data['categoryId']?.toString() ?? '',
      condition: data['condition']?.toString() ?? '',
      photoUrl: data['photoUrl']?.toString() ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      availabilityStatus: data['availabilityStatus']?.toString() ?? 'available',
      allowsIndependentPickup:
          data['allowsIndependentPickup'] as bool? ??
          ((data['allowsCommunityHubPickup'] as bool? ?? false) == false ||
              (data['hubId']?.toString().trim().isEmpty ?? true)),
      allowsCommunityHubPickup:
          data['allowsCommunityHubPickup'] as bool? ??
          (data['hubId']?.toString().trim().isNotEmpty ?? false),
      hubId: data['hubId']?.toString().trim() ?? '',
      hubName: data['hubName']?.toString().trim() ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
    );
  }
}

class _DonationCard extends StatelessWidget {
  const _DonationCard({
    required this.item,
    required this.onEdit,
    required this.deleteMode,
    required this.isSelected,
    required this.onToggleSelected,
  });

  final DonorListingItem item;
  final VoidCallback onEdit;
  final bool deleteMode;
  final bool isSelected;
  final VoidCallback onToggleSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: SizedBox(
                        width: 84,
                        height: 84,
                        child:
                            item.photoUrl.isNotEmpty
                                ? ImageUtils.base64ToImage(
                                  item.photoUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: Container(
                                    color: AppColors.night,
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      color: AppColors.mint,
                                    ),
                                  ),
                                )
                                : Container(
                                  color: AppColors.night,
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    color: AppColors.mint,
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _categoryLabel(item.category),
                            style: const TextStyle(
                              color: AppColors.sand,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            item.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.mist,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (deleteMode)
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => onToggleSelected(),
                        activeColor: AppColors.coral,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final chipWidth =
                        (constraints.maxWidth - AppSpacing.sm) / 2;
                    return Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        SizedBox(
                          width: chipWidth,
                          child: _MetaChip(
                            icon: Icons.scale_outlined,
                            label: item.condition,
                          ),
                        ),
                        SizedBox(
                          width: chipWidth,
                          child: _MetaChip(
                            icon: Icons.toggle_on_outlined,
                            label: _titleCase(item.availabilityStatus),
                          ),
                        ),
                        SizedBox(
                          width: chipWidth,
                          child: _MetaChip(
                            icon: Icons.category_outlined,
                            label: _categoryLabel(item.category),
                          ),
                        ),
                        SizedBox(
                          width: chipWidth,
                          child: _MetaChip(
                            icon: Icons.swap_horiz_outlined,
                            label: _handoverMethodsLabel(item),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  height: 1,
                  width: double.infinity,
                  color: AppColors.pine.withValues(alpha: 0.5),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Created ${_formatDate(item.createdAt)}',
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                if (!_isEditLockedStatus(item.availabilityStatus))
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: deleteMode ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                if (item.expiryDate != null &&
                    item.category != 'consumables') ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Expiry ${_formatDate(item.expiryDate!)}',
                    style: const TextStyle(color: AppColors.mist, fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.night.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.pine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.mint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _EmptyDonationsPanel extends StatelessWidget {
  const _EmptyDonationsPanel({
    required this.hasSearch,
    required this.onAddPressed,
  });

  final bool hasSearch;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.mint,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              hasSearch ? 'No matching donations' : 'No donations yet',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasSearch
                  ? 'Try a different search term.'
                  : 'Create your first donation item using the donor field layout.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mist, height: 1.5),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Donation'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.coral, size: 42),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mist),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _DonationFormSheet extends StatefulWidget {
  const _DonationFormSheet({this.item});

  final DonorListingItem? item;

  @override
  State<_DonationFormSheet> createState() => _DonationFormSheetState();
}

class _DonationFormSheetState extends State<_DonationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _picker = ImagePicker();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _imageStorageService = ImageStorageService();

  final List<String> _conditions = const [
    'New',
    'Like New',
    'Good',
    'Fair',
    'Poor',
  ];

  final List<_CategoryOption> _categories = const [
    _CategoryOption('consumables', 'Food & Consumables'),
    _CategoryOption('baby_essentials', 'Baby Essentials'),
    _CategoryOption('toiletries_hygiene', 'Toiletries & Hygiene'),
    _CategoryOption('sanitary_products', 'Sanitary Products'),
    _CategoryOption('cleaning_supplies', 'Cleaning Supplies'),
    _CategoryOption('school_supplies', 'School Supplies'),
    _CategoryOption('clothing_footwear', 'Clothing & Footwear'),
    _CategoryOption('bedding_linen', 'Bedding & Linen'),
    _CategoryOption('household_basics', 'Household Basics'),
    _CategoryOption('medical_supplies', 'Medical Supplies'),
    _CategoryOption('others', 'Others'),
  ];

  late String _selectedCondition;
  late String _selectedCategoryId;
  late bool _allowsIndependentPickup;
  late bool _allowsCommunityHubPickup;
  File? _imageFile;
  String _photoUrl = '';
  String? _selectedHubId;
  String _selectedHubName = '';
  bool _isSaving = false;
  String? _errorMessage;
  DateTime? _expiryDate;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController.text = item?.title ?? '';
    _descriptionController.text = item?.description ?? '';
    _quantityController.text = (item?.quantity ?? 1).toString();
    _selectedCondition =
        _conditions.contains(item?.condition) ? item!.condition : 'Good';
    _selectedCategoryId = _normalizeCategoryId(item?.category);
    _photoUrl = item?.photoUrl ?? '';
    _allowsIndependentPickup = item?.allowsIndependentPickup ?? true;
    _allowsCommunityHubPickup = item?.allowsCommunityHubPickup ?? false;
    _selectedHubId = item?.hubId.isNotEmpty == true ? item!.hubId : null;
    _selectedHubName = item?.hubName ?? '';
    _expiryDate = item?.expiryDate;
  }

  String _normalizeCategoryId(String? categoryId) {
    final normalized = (categoryId ?? '').trim().toLowerCase();
    if (_categories.any((category) => category.value == normalized)) {
      return normalized;
    }

    switch (normalized) {
      case 'cat_home':
      case 'home':
      case 'household_items':
      case 'furniture':
        return 'household_basics';
      case 'cat_clothing':
      case 'apparel':
      case 'clothes':
      case 'clothing':
        return 'clothing_footwear';
      case 'cat_books':
        return 'school_supplies';
      case 'cat_sports':
      case 'cat_electronics':
      case 'cat_toys':
        return 'others';
      case 'consumables':
      case 'food':
      case 'groceries':
        return 'consumables';
      case 'hygiene':
      case 'toiletries':
      case 'personal_care':
        return 'toiletries_hygiene';
      case 'sanitary':
      case 'sanitary_items':
        return 'sanitary_products';
      case 'cleaning':
      case 'cleaning_items':
        return 'cleaning_supplies';
      case 'school':
      case 'stationery':
        return 'school_supplies';
      case 'bedding':
      case 'linen':
        return 'bedding_linen';
      case 'baby':
      case 'infant':
        return 'baby_essentials';
      case 'medical':
      case 'medicine':
      case 'health':
        return 'medical_supplies';
      default:
        return 'others';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _selectCommunityHub() async {
    final selectedHub = await Navigator.of(
      context,
    ).push<CommunityHubBrowseRecord>(
      MaterialPageRoute(
        builder:
            (_) => RecipientBrowseCommunityHubsPage(
              selectedHubId: _selectedHubId,
              selectionEnabled: true,
              standaloneTitle: 'Select Community Hub',
            ),
      ),
    );

    if (selectedHub == null || !mounted) {
      return;
    }

    setState(() {
      _selectedHubId = selectedHub.hubId;
      _selectedHubName = selectedHub.hubName;
      _errorMessage = null;
    });
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) {
        return;
      }

      setState(() {
        _imageFile = File(picked.path);
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Unable to select image: $error';
      });
    }
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      initialDate: _expiryDate ?? now,
      lastDate: DateTime(now.year + 5),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _expiryDate = picked;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_allowsIndependentPickup && !_allowsCommunityHubPickup) {
      setState(() {
        _errorMessage = 'Select at least one handover method.';
      });
      return;
    }

    if (_allowsCommunityHubPickup &&
        (_selectedHubId == null || _selectedHubId!.isEmpty)) {
      setState(() {
        _errorMessage = 'Choose an approved community hub for hub pickup.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final availabilityStatus =
        _isEditing
            ? widget.item?.availabilityStatus ?? 'available'
            : 'available';

    try {
      final donorId = _auth.currentUser?.uid;
      if (donorId == null) {
        throw Exception('User not authenticated');
      }

      if (_isEditing && widget.item!.donorId != donorId) {
        throw Exception('You can only edit your own donation listings');
      }

      final docId = widget.item?.docId ?? _newThirteenDigitId('item');
      final itemId = widget.item?.itemId ?? _newThirteenDigitId('item');
      final expiryDate =
          _selectedCategoryId == 'consumables' ? _expiryDate : null;
      var photoUrl = _photoUrl;

      if (_imageFile != null) {
        photoUrl = await _imageStorageService.uploadFile(
          file: _imageFile!,
          folder: 'listing_images/$donorId',
          fileName: '${docId}_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      final payload = <String, dynamic>{
        'availabilityStatus': availabilityStatus,
        'allowsCommunityHubPickup': _allowsCommunityHubPickup,
        'allowsIndependentPickup': _allowsIndependentPickup,
        'category': _selectedCategoryId,
        'condition': _selectedCondition,
        'createdAt':
            widget.item == null
                ? Timestamp.now()
                : Timestamp.fromDate(widget.item!.createdAt),
        'description': _descriptionController.text.trim(),
        'donorId': donorId,
        'expiryDate':
            expiryDate == null ? null : Timestamp.fromDate(expiryDate),
        'hubId': _allowsCommunityHubPickup ? _selectedHubId : null,
        'hubName': _allowsCommunityHubPickup ? _selectedHubName : null,
        'itemId': itemId,
        'photoUrl': photoUrl,
        'quantity': int.parse(_quantityController.text.trim()),
        'title': _titleController.text.trim(),
      };

      await _firestore
          .collection('ITEM_LISTING')
          .doc(docId)
          .set(payload, SetOptions(merge: _isEditing));

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to save donation: $error';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Material(
        color: AppColors.night,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            bottomInset + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.slate,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _isEditing ? 'Edit Donation' : 'Add Donation',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.coral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.coral),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.white),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 188,
                          decoration: BoxDecoration(
                            color: AppColors.forest,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.pine),
                          ),
                          child:
                              _imageFile != null
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    child: Image.file(
                                      _imageFile!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  )
                                  : _photoUrl.trim().isNotEmpty
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    child: ImageUtils.base64ToImage(
                                      _photoUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                  : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 44,
                                        color: AppColors.mint,
                                      ),
                                      SizedBox(height: AppSpacing.sm),
                                      Text('Tap to add an image'),
                                    ],
                                  ),
                        ),
                        if (_imageFile != null || _photoUrl.trim().isNotEmpty)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Material(
                              color: AppColors.night.withValues(alpha: 0.72),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  setState(() {
                                    _imageFile = null;
                                    _photoUrl = '';
                                  });
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter the donation title'
                                : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter a description'
                                : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items:
                        _categories
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category.value,
                                child: Text(category.label),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedCategoryId = value;
                        if (_selectedCategoryId != 'consumables') {
                          _expiryDate = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                          ),
                          validator: (value) {
                            final parsed = int.tryParse(value?.trim() ?? '');
                            if (parsed == null) {
                              return 'Enter a whole number';
                            }
                            if (parsed < 1) {
                              return 'Minimum 1';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCondition,
                          decoration: const InputDecoration(
                            labelText: 'Condition',
                          ),
                          items:
                              _conditions
                                  .map(
                                    (condition) => DropdownMenuItem<String>(
                                      value: condition,
                                      child: Text(condition),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _selectedCondition = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Availability Status',
                    ),
                    child: Text(
                      _isEditing
                          ? _titleCase(
                            widget.item?.availabilityStatus ?? 'available',
                          )
                          : 'Available',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.forest,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.pine),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Handover Methods',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Choose what recipients can request for this listing.',
                          style: TextStyle(color: AppColors.mist, height: 1.45),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            FilterChip(
                              selected: _allowsIndependentPickup,
                              label: const Text('Independent Pickup'),
                              onSelected: (selected) {
                                setState(() {
                                  _allowsIndependentPickup = selected;
                                });
                              },
                            ),
                            FilterChip(
                              selected: _allowsCommunityHubPickup,
                              label: const Text('Community Hub Pickup'),
                              onSelected: (selected) {
                                setState(() {
                                  _allowsCommunityHubPickup = selected;
                                  if (!selected) {
                                    _selectedHubId = null;
                                    _selectedHubName = '';
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        if (_allowsCommunityHubPickup) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Approved Community Hub',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            onTap: _selectCommunityHub,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                border: Border.all(color: AppColors.mint),
                                color: AppColors.forest,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedHubName.isNotEmpty
                                              ? _selectedHubName
                                              : 'Browse community hubs',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color:
                                                _selectedHubName.isNotEmpty
                                                    ? AppColors.white
                                                    : AppColors.sand,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          _selectedHubId?.isNotEmpty == true
                                              ? 'Hub ID: $_selectedHubId'
                                              : 'Open the hub list and select an approved pickup hub.',
                                          style: const TextStyle(
                                            color: AppColors.mist,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 18,
                                    color: AppColors.mint,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _selectCommunityHub,
                              icon: const Icon(Icons.storefront_outlined),
                              label: Text(
                                _selectedHubId?.isNotEmpty == true
                                    ? 'Change Selected Hub'
                                    : 'Browse Community Hubs',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_selectedCategoryId == 'consumables') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickExpiryDate,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              _expiryDate == null
                                  ? 'Set Expiry Date'
                                  : _formatDate(_expiryDate!),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        if (_expiryDate != null)
                          TextButton(
                            onPressed: () => setState(() => _expiryDate = null),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon:
                          _isSaving
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.night,
                                ),
                              )
                              : Icon(
                                _isEditing
                                    ? Icons.save_outlined
                                    : Icons.add_circle_outline,
                              ),
                      label: Text(
                        _isSaving
                            ? 'Saving...'
                            : _isEditing
                            ? 'Save Changes'
                            : 'Create Donation',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryOption {
  const _CategoryOption(this.value, this.label);

  final String value;
  final String label;
}

String _categoryLabel(String category) {
  return switch (category) {
    'consumables' => 'Food & Consumables',
    'baby_essentials' => 'Baby Essentials',
    'toiletries_hygiene' => 'Toiletries & Hygiene',
    'sanitary_products' => 'Sanitary Products',
    'cleaning_supplies' => 'Cleaning Supplies',
    'school_supplies' => 'School Supplies',
    'clothing_footwear' => 'Clothing & Footwear',
    'bedding_linen' => 'Bedding & Linen',
    'household_basics' => 'Household Basics',
    'medical_supplies' => 'Medical Supplies',
    'others' => 'Others',
    _ => _titleCase(category),
  };
}

String _handoverMethodsLabel(DonorListingItem item) {
  if (item.allowsIndependentPickup && item.allowsCommunityHubPickup) {
    return 'Both';
  }
  if (item.allowsCommunityHubPickup) {
    return 'Hub pickup';
  }
  return 'Independent';
}

String _formatDate(DateTime date) {
  final month = switch (date.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
  return '$month ${date.day}, ${date.year}';
}

String _titleCase(String value) {
  if (value.isEmpty) {
    return value;
  }

  return value
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}

bool _isEditLockedStatus(String status) {
  switch (status.toLowerCase()) {
    case 'claimed':
    case 'reserved':
    case 'expired':
    case 'deactivated':
      return true;
    default:
      return false;
  }
}
