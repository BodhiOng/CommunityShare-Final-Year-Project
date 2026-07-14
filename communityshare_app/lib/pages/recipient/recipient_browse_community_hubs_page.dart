import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants.dart';
import '../../widgets/state_widgets.dart';

class RecipientBrowseCommunityHubsPage extends StatefulWidget {
  const RecipientBrowseCommunityHubsPage({
    super.key,
    this.selectedHubId,
    this.selectionEnabled = false,
    this.standaloneTitle,
  });

  final String? selectedHubId;
  final bool selectionEnabled;
  final String? standaloneTitle;

  @override
  State<RecipientBrowseCommunityHubsPage> createState() =>
      _RecipientBrowseCommunityHubsPageState();
}

class _RecipientBrowseCommunityHubsPageState
    extends State<RecipientBrowseCommunityHubsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _errorMessage = '';
  List<CommunityHubBrowseRecord> _hubs = const [];
  int _currentPage = 0;

  static const int _hubsPerPage = 8;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleFiltersChanged);
    _loadHubs();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleFiltersChanged);
    _searchController.dispose();
    super.dispose();
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
        _currentPage = 0;
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
    return Scaffold(
      appBar: widget.standaloneTitle == null
          ? null
          : AppBar(title: Text(widget.standaloneTitle!)),
      body: _buildBody(),
    );
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

    final filteredHubs = _filteredHubs;
    final paginatedHubs = _paginatedHubs;

    return RefreshIndicator(
      color: AppColors.mint,
      onRefresh: _loadHubs,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          _buildSearchAndFilters(),
          const SizedBox(height: AppSpacing.lg),
          if (filteredHubs.isEmpty)
            const AppEmptyState(
              icon: Icons.search_off_outlined,
              title: 'No matching community hubs',
              message: 'Adjust the search terms and try again.',
            )
          else
            for (final hub in paginatedHubs) ...[
              _HubCard(
                hub: hub,
                isSelected: hub.hubId == widget.selectedHubId,
                selectionEnabled: widget.selectionEnabled,
                onTap: () => _handleHubTap(hub),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          if (filteredHubs.isNotEmpty) ...[
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

  Widget _buildSearchAndFilters() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by hub, address, contact, or ID',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () => _searchController.clear(),
                icon: const Icon(Icons.close),
              ),
      ),
    );
  }

  void _handleHubTap(CommunityHubBrowseRecord hub) {
    if (widget.selectionEnabled) {
      Navigator.of(context).pop(hub);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CommunityHubDetailsPage(hub: hub),
      ),
    );
  }

  List<CommunityHubBrowseRecord> get _filteredHubs {
    final query = _searchController.text.trim().toLowerCase();
    return _hubs.where((hub) {
      final matchesQuery =
          query.isEmpty ||
          hub.hubName.toLowerCase().contains(query) ||
          hub.hubId.toLowerCase().contains(query) ||
          hub.address.toLowerCase().contains(query) ||
          hub.contactNumber.toLowerCase().contains(query);
      return matchesQuery;
    }).toList(growable: false);
  }

  List<CommunityHubBrowseRecord> get _paginatedHubs {
    final start = _currentPage * _hubsPerPage;
    if (start >= _filteredHubs.length) {
      return const [];
    }
    final end = (start + _hubsPerPage).clamp(0, _filteredHubs.length);
    return _filteredHubs.sublist(start, end);
  }

  int get _totalPages {
    if (_filteredHubs.isEmpty) {
      return 1;
    }
    return (_filteredHubs.length / _hubsPerPage).ceil();
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) {
      return;
    }
    setState(() => _currentPage = page);
  }

  void _handleFiltersChanged() {
    if (!mounted) {
      return;
    }
    setState(() => _currentPage = 0);
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

class _CommunityHubDetailsPage extends StatelessWidget {
  const _CommunityHubDetailsPage({required this.hub});

  final CommunityHubBrowseRecord hub;

  Future<void> _copyLocation(BuildContext context) async {
    final location = hub.address.trim();
    if (location.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: location));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Hub'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            hub.hubName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
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
            body:
                hub.address.isNotEmpty ? hub.address : 'Address not provided',
            onBodyTap:
                hub.address.isNotEmpty ? () => _copyLocation(context) : null,
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
    this.onBodyTap,
  });

  final String title;
  final IconData icon;
  final String body;
  final VoidCallback? onBodyTap;

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
          InkWell(
            onTap: onBodyTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                body,
                style: TextStyle(
                  color:
                      onBodyTap == null ? AppColors.sand : AppColors.mint,
                  height: 1.5,
                ),
              ),
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
