import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'constants.dart';
import 'widgets/state_widgets.dart';

class RecipientBrowseCommunityHubsPage extends StatefulWidget {
  const RecipientBrowseCommunityHubsPage({
    super.key,
    this.selectedHubId,
    this.selectionEnabled = false,
  });

  final String? selectedHubId;
  final bool selectionEnabled;

  @override
  State<RecipientBrowseCommunityHubsPage> createState() =>
      _RecipientBrowseCommunityHubsPageState();
}

class _RecipientBrowseCommunityHubsPageState
    extends State<RecipientBrowseCommunityHubsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _errorMessage = '';
  List<CommunityHubBrowseRecord> _hubs = const [];

  @override
  void initState() {
    super.initState();
    _loadHubs();
  }

  Future<void> _loadHubs() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final snapshot = await _firestore.collection('COMMUNITY_HUB').get();
      final hubs = snapshot.docs
          .map(
            (doc) => CommunityHubBrowseRecord.fromFirestore(doc.id, doc.data()),
          )
          .where((hub) => hub.status.toLowerCase() == 'active')
          .toList(growable: false)
        ..sort(
          (left, right) =>
              left.hubName.toLowerCase().compareTo(right.hubName.toLowerCase()),
        );

      if (!mounted) {
        return;
      }

      setState(() {
        _hubs = hubs;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to load community hubs: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingState(message: 'Loading community hubs...');
    }

    if (_errorMessage.isNotEmpty) {
      return AppErrorState(
        message: _errorMessage,
        onRetry: _loadHubs,
      );
    }

    if (_hubs.isEmpty) {
      return const AppEmptyState(
        icon: Icons.storefront_outlined,
        title: 'No available community hubs',
        message: 'Active hubs will appear here once they have been set up.',
      );
    }

    return RefreshIndicator(
      color: AppColors.mint,
      onRefresh: _loadHubs,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for (final hub in _hubs) ...[
            _HubCard(
              hub: hub,
              isSelected: hub.hubId == widget.selectedHubId,
              selectionEnabled: widget.selectionEnabled,
              onTap: () => _handleHubTap(hub),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }

  void _handleHubTap(CommunityHubBrowseRecord hub) {
    if (widget.selectionEnabled) {
      Navigator.of(context).pop(hub);
      return;
    }

    _showHubDetails(hub);
  }

  void _showHubDetails(CommunityHubBrowseRecord hub) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.forest,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hub.hubName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Hub ID: ${hub.hubId}',
                  style: const TextStyle(color: AppColors.sand),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _HubBadge(
                      icon: Icons.check_circle_outline,
                      label: 'Available',
                      color: AppColors.mint,
                    ),
                    _HubBadge(
                      icon: Icons.schedule_outlined,
                      label: hub.operatingHours.isNotEmpty
                          ? 'Hours listed'
                          : 'Hours unavailable',
                      color: AppColors.sun,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _HubDetailPanel(
                  title: 'Location',
                  icon: Icons.place_outlined,
                  body: hub.address.isNotEmpty
                      ? hub.address
                      : 'Address not provided',
                ),
                const SizedBox(height: AppSpacing.md),
                _HubDetailPanel(
                  title: 'Operating Hours',
                  icon: Icons.schedule_outlined,
                  body: hub.operatingHours.isNotEmpty
                      ? hub.operatingHours
                      : 'Operating hours not provided',
                ),
                const SizedBox(height: AppSpacing.md),
                _HubDetailPanel(
                  title: 'Contact Number',
                  icon: Icons.phone_outlined,
                  body: hub.contactNumber.isNotEmpty
                      ? hub.contactNumber
                      : 'Contact number not provided',
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CommunityHubBrowseRecord {
  const CommunityHubBrowseRecord({
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

  factory CommunityHubBrowseRecord.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    return CommunityHubBrowseRecord(
      hubId: _readString(data['hubId'], fallback: docId),
      hubName: _readString(data['hubName'], fallback: 'Community Hub'),
      address: _readString(data['address']),
      operatingHours: _readString(data['operatingHours']),
      contactNumber: _readString(data['contactNumber']),
      status: _readString(data['status'], fallback: 'inactive'),
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    return fallback;
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.hub,
    required this.isSelected,
    required this.selectionEnabled,
    required this.onTap,
  });

  final CommunityHubBrowseRecord hub;
  final bool isSelected;
  final bool selectionEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hub.hubName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Hub ID: ${hub.hubId}',
                          style: const TextStyle(color: AppColors.slate),
                        ),
                      ],
                    ),
                  ),
                  _HubBadge(
                    icon: isSelected
                        ? Icons.check_circle_outline
                        : Icons.storefront_outlined,
                    label: isSelected ? 'Selected' : 'Available',
                    color: isSelected ? AppColors.sun : AppColors.mint,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _HubDetailRow(
                icon: Icons.place_outlined,
                label: hub.address.isNotEmpty
                    ? hub.address
                    : 'Address not provided',
              ),
              const SizedBox(height: AppSpacing.sm),
              _HubDetailRow(
                icon: Icons.schedule_outlined,
                label: hub.operatingHours.isNotEmpty
                    ? hub.operatingHours
                    : 'Operating hours not provided',
              ),
              const SizedBox(height: AppSpacing.sm),
              _HubDetailRow(
                icon: Icons.phone_outlined,
                label: hub.contactNumber.isNotEmpty
                    ? hub.contactNumber
                    : 'Contact number not provided',
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                selectionEnabled ? 'Tap to select this hub.' : 'Tap to view full hub details.',
                style: const TextStyle(
                  color: AppColors.mint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubBadge extends StatelessWidget {
  const _HubBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HubDetailPanel extends StatelessWidget {
  const _HubDetailPanel({
    required this.title,
    required this.icon,
    required this.body,
  });

  final String title;
  final IconData icon;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.night.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.pine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.mint, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.sand,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HubDetailRow extends StatelessWidget {
  const _HubDetailRow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.mint),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.mist,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
