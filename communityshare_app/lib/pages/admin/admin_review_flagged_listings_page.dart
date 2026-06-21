import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_deactivate_listing_page.dart';
import '../../constants.dart';
import '../../widgets/state_widgets.dart';

class AdminReviewFlaggedListingsPage extends StatefulWidget {
  const AdminReviewFlaggedListingsPage({super.key});

  @override
  State<AdminReviewFlaggedListingsPage> createState() =>
      _AdminReviewFlaggedListingsPageState();
}

class _AdminReviewFlaggedListingsPageState
    extends State<AdminReviewFlaggedListingsPage> {
  static const int _reportsPerPage = 8;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _errorMessage = '';
  List<FlaggedListingReportRecord> _reports = const [];
  List<FlaggedListingReportRecord> _filteredReports = const [];
  String _selectedStatus = 'all';
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _loadReports();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final reportSnapshot = await _firestore
          .collection('REPORT')
          .orderBy('createdAt', descending: true)
          .get();

      final records = <FlaggedListingReportRecord>[];
      for (final doc in reportSnapshot.docs) {
        final data = doc.data();
        final itemId = data['itemId']?.toString().trim() ?? '';
        if (itemId.isEmpty) {
          continue;
        }

        final listingSnapshot = await _firestore
            .collection('ITEM_LISTING')
            .where('itemId', isEqualTo: itemId)
            .limit(1)
            .get();
        final listingDoc =
            listingSnapshot.docs.isNotEmpty ? listingSnapshot.docs.first : null;
        final listingData = listingDoc?.data();

        final reporterId = data['reporterUserId']?.toString().trim() ?? '';
        final reporterDoc = reporterId.isEmpty
            ? null
            : await _firestore.collection('USER').doc(reporterId).get();
        final reporterData = reporterDoc?.data();

        records.add(
          FlaggedListingReportRecord(
            reportId: data['reportId']?.toString().trim().isNotEmpty == true
                ? data['reportId'].toString().trim()
                : doc.id,
            itemId: itemId,
            reporterUserId: reporterId,
            reportedUserId: data['reportedUserId']?.toString().trim() ?? '',
            reason: data['reason']?.toString().trim() ?? '',
            reportStatus: data['reportStatus']?.toString().trim() ?? 'pending',
            createdAt: _readDateTime(data['createdAt']),
            listingDocId: listingDoc?.id ?? '',
            listingTitle: listingData?['title']?.toString().trim().isNotEmpty ==
                    true
                ? listingData!['title'].toString().trim()
                : 'Listing unavailable',
            listingCategory:
                listingData?['category']?.toString().trim() ?? 'others',
            listingPhotoUrl: listingData?['photoUrl']?.toString().trim() ?? '',
            listingAvailabilityStatus:
                listingData?['availabilityStatus']?.toString().trim() ??
                    'unknown',
            reporterName: _displayNameForUser(reporterData, reporterId),
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _reports = records;
        _filteredReports = records;
        _isLoading = false;
        _currentPage = 0;
      });
      _applyFilters();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to load flagged listings: $error';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredReports = _reports.where((report) {
        final matchesQuery =
            query.isEmpty ||
            report.listingTitle.toLowerCase().contains(query) ||
            report.reason.toLowerCase().contains(query) ||
            report.reporterName.toLowerCase().contains(query) ||
            report.reportedUserId.toLowerCase().contains(query);

        final matchesStatus =
            _selectedStatus == 'all' ||
            report.reportStatus.toLowerCase() == _selectedStatus;

        return matchesQuery && matchesStatus;
      }).toList(growable: false);
      _currentPage = 0;
    });
  }

  int get _totalPages {
    if (_filteredReports.isEmpty) {
      return 0;
    }
    return (_filteredReports.length / _reportsPerPage).ceil();
  }

  List<FlaggedListingReportRecord> get _pagedReports {
    if (_filteredReports.isEmpty) {
      return const [];
    }

    final start = _currentPage * _reportsPerPage;
    final end = (start + _reportsPerPage)
        .clamp(0, _filteredReports.length)
        .toInt();
    return _filteredReports.sublist(start, end);
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) {
      return;
    }

    setState(() {
      _currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: const AppLoadingState(message: 'Loading flagged listings...'),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: AppErrorState(
          message: _errorMessage,
          onRetry: _loadReports,
        ),
      );
    }

    if (_reports.isEmpty) {
      return Scaffold(
        body: const AppEmptyState(
          icon: Icons.flag_outlined,
          title: 'No flagged listings',
          message: 'New listing reports will appear here for review.',
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.mint,
        onRefresh: _loadReports,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search flagged listings',
                hintText: 'Search by listing, reason, reporter, or user ID',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => _searchController.clear(),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  const statuses = [
                    'all',
                    'pending',
                    'investigating',
                    'dismissed',
                  ];
                  final status = statuses[index];
                  final selected = _selectedStatus == status;
                  return FilterChip(
                    selected: selected,
                    showCheckmark: false,
                    label: Text(
                      status == 'all'
                          ? 'All Statuses'
                          : _titleCaseLabel(status),
                    ),
                    onSelected: (_) {
                      _selectedStatus = status;
                      _applyFilters();
                    },
                    backgroundColor: AppColors.forest,
                    selectedColor: AppColors.mint.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      color: selected ? AppColors.mint : AppColors.sand,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: selected ? AppColors.mint : AppColors.pine,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${_filteredReports.length} flagged ${_filteredReports.length == 1 ? 'listing' : 'listings'}',
              style: const TextStyle(color: AppColors.sand),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_filteredReports.isEmpty)
              const AppEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matching flagged listings',
                message: 'Try a different search term or reset the status filter.',
              )
            else ...[
              ..._pagedReports.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(AppSpacing.md),
                      title: Text(report.listingTitle),
                      subtitle: Text(
                        '${_titleCaseLabel(report.listingCategory)} | ${_titleCaseLabel(report.reportStatus)} | ${report.createdAtLabel}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AdminDeactivateListingPage(report: report),
                          ),
                        );
                        if (mounted) {
                          await _loadReports();
                        }
                      },
                    ),
                  ),
                ),
              ),
              if (_totalPages > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Page ${_currentPage + 1} of $_totalPages',
                      style: const TextStyle(color: AppColors.sand),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _currentPage > 0
                              ? () => _goToPage(_currentPage - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          onPressed: _currentPage + 1 < _totalPages
                              ? () => _goToPage(_currentPage + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
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
    Map<String, dynamic>? data,
    String fallback,
  ) {
    if (data == null || data.isEmpty) {
      return fallback.isNotEmpty ? fallback : 'Unknown user';
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
    return fallback.isNotEmpty ? fallback : 'Unknown user';
  }

  static String _titleCaseLabel(String value) {
    return value
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) {
          final lower = part.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }
}

class FlaggedListingReportRecord {
  const FlaggedListingReportRecord({
    required this.reportId,
    required this.itemId,
    required this.reporterUserId,
    required this.reportedUserId,
    required this.reason,
    required this.reportStatus,
    required this.createdAt,
    required this.listingDocId,
    required this.listingTitle,
    required this.listingCategory,
    required this.listingPhotoUrl,
    required this.listingAvailabilityStatus,
    required this.reporterName,
  });

  final String reportId;
  final String itemId;
  final String reporterUserId;
  final String reportedUserId;
  final String reason;
  final String reportStatus;
  final DateTime? createdAt;
  final String listingDocId;
  final String listingTitle;
  final String listingCategory;
  final String listingPhotoUrl;
  final String listingAvailabilityStatus;
  final String reporterName;

  String get createdAtLabel {
    if (createdAt == null) {
      return 'Unknown date';
    }
    return DateFormat('MMM d, yyyy | h:mm a').format(createdAt!);
  }
}
