import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_deactivate_listing_page.dart';
import 'constants.dart';
import 'widgets/state_widgets.dart';

class AdminReviewFlaggedListingsPage extends StatefulWidget {
  const AdminReviewFlaggedListingsPage({super.key});

  @override
  State<AdminReviewFlaggedListingsPage> createState() =>
      _AdminReviewFlaggedListingsPageState();
}

class _AdminReviewFlaggedListingsPageState
    extends State<AdminReviewFlaggedListingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _errorMessage = '';
  List<FlaggedListingReportRecord> _reports = const [];

  @override
  void initState() {
    super.initState();
    _loadReports();
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
            listingPhotoUrl:
                listingData?['photoUrl']?.toString().trim() ?? '',
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
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Flagged Listings')),
        body: const AppLoadingState(message: 'Loading flagged listings...'),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Flagged Listings')),
        body: AppErrorState(
          message: _errorMessage,
          onRetry: _loadReports,
        ),
      );
    }

    if (_reports.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Flagged Listings')),
        body: const AppEmptyState(
          icon: Icons.flag_outlined,
          title: 'No flagged listings',
          message: 'New listing reports will appear here for review.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Flagged Listings'),
      ),
      body: RefreshIndicator(
        color: AppColors.mint,
        onRefresh: _loadReports,
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _reports.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final report = _reports[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(AppSpacing.md),
                title: Text(report.listingTitle),
                subtitle: Text(
                  '${_titleCaseLabel(report.listingCategory)} • ${_titleCaseLabel(report.reportStatus)}',
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
            );
          },
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
    }).join(' ');
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
    return DateFormat('MMM d, yyyy • h:mm a').format(createdAt!);
  }
}
