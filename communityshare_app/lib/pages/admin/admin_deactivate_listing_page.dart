import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_review_flagged_listings_page.dart';
import '../../constants.dart';
import '../../utils/image_utils.dart';
import '../../widgets/state_widgets.dart';

class AdminDeactivateListingPage extends StatefulWidget {
  const AdminDeactivateListingPage({
    super.key,
    required this.report,
  });

  final FlaggedListingReportRecord report;

  @override
  State<AdminDeactivateListingPage> createState() =>
      _AdminDeactivateListingPageState();
}

class _AdminDeactivateListingPageState extends State<AdminDeactivateListingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSubmitting = false;

  Future<void> _deactivateListing() async {
    if (widget.report.listingDocId.isEmpty || widget.report.reportDocId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing or report document was not found.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final batch = _firestore.batch();
      final listingRef =
          _firestore.collection('ITEM_LISTING').doc(widget.report.listingDocId);
      final reportRef =
          _firestore.collection('REPORT').doc(widget.report.reportDocId);

      batch.update(listingRef, {
        'availabilityStatus': 'deactivated',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(reportRef, {
        'reportStatus': 'resolved',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing deactivated and report resolved.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to deactivate listing: $error')),
      );
    }
  }

  Future<void> _dismissReport() async {
    if (widget.report.reportDocId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report document was not found.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final batch = _firestore.batch();
      final reportRef =
          _firestore.collection('REPORT').doc(widget.report.reportDocId);
      batch.update(reportRef, {
        'reportStatus': 'dismissed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (widget.report.listingDocId.isNotEmpty) {
        final listingRef =
            _firestore.collection('ITEM_LISTING').doc(widget.report.listingDocId);
        batch.update(listingRef, {
          'availabilityStatus': 'available',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report dismissed. The listing was restored to available.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to dismiss report: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dismiss Report'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: const LinearGradient(
                colors: [AppColors.coral, AppColors.forest],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FLAGGED LISTING',
                  style: TextStyle(
                    color: AppColors.sand,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  report.listingTitle,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _StatusChip(label: _titleCaseLabel(report.listingCategory)),
                    _StatusChip(
                      label: _titleCaseLabel(report.listingAvailabilityStatus),
                    ),
                    _StatusChip(label: _titleCaseLabel(report.reportStatus)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (report.listingPhotoUrl.trim().isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: ImageUtils.base64ToImage(
                          report.listingPhotoUrl,
                          fit: BoxFit.cover,
                          errorWidget: const AppEmptyState(
                            icon: Icons.image_not_supported_outlined,
                            title: 'Preview unavailable',
                            message: 'The listing image could not be rendered.',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _InfoLine(label: 'Report ID', value: report.reportId),
                  _InfoLine(label: 'Item ID', value: report.itemId),
                  _InfoLine(label: 'Reporter', value: report.reporterName),
                  _InfoLine(label: 'Reported user', value: report.reportedUserId),
                  _InfoLine(label: 'Submitted', value: report.createdAtLabel),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Report reason',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.sand,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    report.reason.isNotEmpty
                        ? report.reason
                        : 'No report reason provided.',
                    style: const TextStyle(
                      color: AppColors.mist,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.mint),
              color: AppColors.mint.withValues(alpha: 0.08),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report action',
                  style: TextStyle(
                    color: AppColors.mint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Choose whether to hide the listing or clear the report and restore the listing.',
                  style: TextStyle(
                    color: AppColors.mist,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _deactivateListing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.coral,
                          foregroundColor: AppColors.white,
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Icon(Icons.block_outlined),
                        label: Text(
                          _isSubmitting
                              ? 'Deactivating...'
                              : 'Deactivate Listing',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _dismissReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: AppColors.white,
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Icon(Icons.visibility_off_outlined),
                        label: Text(
                          _isSubmitting
                              ? 'Dismissing...'
                              : 'Dismiss Report',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.sand,
          fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
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
