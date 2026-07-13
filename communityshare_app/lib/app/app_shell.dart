import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../pages/donor/donor_donation_status_tracking_page.dart';
import '../pages/donor/donor_incoming_requests_page.dart';
import '../pages/donor/donor_listing_page.dart';
import '../pages/donor/donor_select_handover_point_page.dart';
import '../pages/hub/hub_handover_confirmation_page.dart';
import '../pages/hub/hub_manage_profile_page.dart';
import '../pages/recipient/recipient_browse_items_page.dart';
import '../pages/recipient/recipient_browse_community_hubs_page.dart';
import '../pages/recipient/recipient_request_status_page.dart';
import '../pages/admin/admin_user_crud_page.dart';
import '../pages/admin/admin_review_flagged_listings_page.dart';
import '../features/profile/shared_profile_page.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/state_widgets.dart';
import 'user_role.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.role, this.initialIndex = 0});

  final UserRole role;
  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  bool _isInactiveStatus(String status) {
    return status.trim().toLowerCase() == 'inactive';
  }

  void _showInactiveAccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Your account is inactive. Complete the required profile fields to reactivate it.',
        ),
      ),
    );
  }

  void _handleTabTap({
    required int index,
    required int profileIndex,
    required bool isInactive,
  }) {
    if (isInactive && index != profileIndex) {
      _showInactiveAccessMessage();
      setState(() {
        _selectedIndex = profileIndex;
      });
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    final tabs = _tabsForRole(widget.role);
    final profileIndex = tabs.length - 1;

    if (uid == null) {
      final safeIndex = _selectedIndex.clamp(0, tabs.length - 1);
      return AppShellScaffold(
        title: tabs[safeIndex].title,
        subtitle: widget.role.description,
        currentIndex: safeIndex,
        destinations: [
          for (final tab in tabs)
            ShellDestinationData(icon: tab.icon, label: tab.label),
        ],
        onTap: (index) => setState(() => _selectedIndex = index),
        role: widget.role,
        child: tabs[safeIndex].builder(context),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('USER').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final status =
            snapshot.data?.data()?['status']?.toString().trim().toLowerCase() ??
            'active';
        final isInactive = _isInactiveStatus(status);
        final safeIndex = (isInactive ? profileIndex : _selectedIndex).clamp(
          0,
          tabs.length - 1,
        );

        if (isInactive && _selectedIndex != profileIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _selectedIndex = profileIndex;
            });
          });
        }

        return AppShellScaffold(
          title: tabs[safeIndex].title,
          subtitle: widget.role.description,
          currentIndex: safeIndex,
          destinations: [
            for (final tab in tabs)
              ShellDestinationData(icon: tab.icon, label: tab.label),
          ],
          onTap:
              (index) => _handleTabTap(
                index: index,
                profileIndex: profileIndex,
                isInactive: isInactive,
              ),
          role: widget.role,
          child: tabs[safeIndex].builder(context),
        );
      },
    );
  }
}

class ShellTab {
  const ShellTab({
    required this.title,
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

List<ShellTab> _tabsForRole(UserRole role) {
  final sharedProfile = ShellTab(
    title: 'Profile',
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    builder: (context) => _ProfilePage(role: role),
  );

  switch (role) {
    case UserRole.donor:
      return [
        const ShellTab(
          title: 'My Listings',
          label: 'Listings',
          icon: Icons.inventory_2_outlined,
          builder: _donorListings,
        ),
        const ShellTab(
          title: 'Incoming Requests',
          label: 'Requests',
          icon: Icons.inbox_outlined,
          builder: _donorIncomingRequests,
        ),
        const ShellTab(
          title: 'Donation Tracking',
          label: 'Tracking',
          icon: Icons.timeline_outlined,
          builder: _donorDonationTracking,
        ),
        const ShellTab(
          title: 'Handover Point',
          label: 'Handover',
          icon: Icons.location_on_outlined,
          builder: _donorHandoverPoint,
        ),
        sharedProfile,
      ];
    case UserRole.recipient:
      return [
        const ShellTab(
          title: 'Browse Items',
          label: 'Browse',
          icon: Icons.search_rounded,
          builder: _recipientBrowse,
        ),
        const ShellTab(
          title: 'Community Hubs',
          label: 'Hubs',
          icon: Icons.storefront_outlined,
          builder: _recipientBrowseHubs,
        ),
        const ShellTab(
          title: 'Request Status',
          label: 'Status',
          icon: Icons.timeline_outlined,
          builder: _recipientRequestStatus,
        ),
        sharedProfile,
      ];
    case UserRole.hub:
      return [
        const ShellTab(
          title: 'Handover Confirmation',
          label: 'Handover',
          icon: Icons.inventory_2_outlined,
          builder: _hubHandoverConfirmation,
        ),
        const ShellTab(
          title: 'Manage Hub Profile',
          label: 'Hub',
          icon: Icons.storefront_outlined,
          builder: _hubManageProfile,
        ),
        sharedProfile,
      ];
    case UserRole.admin:
      return [
        const ShellTab(
          title: 'User Management',
          label: 'Users',
          icon: Icons.groups_outlined,
          builder: _adminUserManagement,
        ),
        const ShellTab(
          title: 'Review Flagged Listings',
          label: 'Review',
          icon: Icons.flag_outlined,
          builder: _adminReviewFlaggedListings,
        ),
        sharedProfile,
      ];
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return SharedProfilePage(role: role);
  }
}

Widget _donorListings(BuildContext context) => const DonorListingPage();

Widget _donorIncomingRequests(BuildContext context) =>
    const DonorIncomingRequestsPage();

Widget _donorDonationTracking(
  BuildContext context,
) => const _DonorRequestLauncherPage(
  title: 'Donation Tracking',
  emptyTitle: 'No trackable requests yet',
  emptyMessage:
      'Approved or scheduled requests will appear here so you can review status and complete the handover flow.',
  actionLabel: 'Open Tracking',
  actionIcon: Icons.timeline_outlined,
  builder: DonorDonationStatusTrackingPage.new,
);

Widget _donorHandoverPoint(
  BuildContext context,
) => const _DonorRequestLauncherPage(
  title: 'Select Handover Point',
  emptyTitle: 'No requests ready for handover',
  emptyMessage:
      'Once a request is approved, you can confirm the recipient-selected handover method from here.',
  actionLabel: 'Open Handover',
  actionIcon: Icons.location_on_outlined,
  builder: DonorSelectHandoverPointPage.new,
);

Widget _recipientBrowse(BuildContext context) =>
    const RecipientBrowseItemsPage();

Widget _recipientBrowseHubs(BuildContext context) =>
    const RecipientBrowseCommunityHubsPage();

Widget _recipientRequestStatus(BuildContext context) =>
    const _RecipientRequestStatusLauncherPage();

Widget _hubHandoverConfirmation(BuildContext context) =>
    const HubHandoverConfirmationPage();

Widget _hubManageProfile(BuildContext context) => const ManageHubProfilePage();

Widget _adminUserManagement(BuildContext context) => const AdminUserCrudPage();

Widget _adminReviewFlaggedListings(BuildContext context) =>
    const AdminReviewFlaggedListingsPage();

class _DonorRequestLauncherPage extends StatefulWidget {
  const _DonorRequestLauncherPage({
    required this.title,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.actionLabel,
    required this.actionIcon,
    required this.builder,
  });

  final String title;
  final String emptyTitle;
  final String emptyMessage;
  final String actionLabel;
  final IconData actionIcon;
  final Widget Function({Key? key, required DonorIncomingRequestRecord request})
  builder;

  @override
  State<_DonorRequestLauncherPage> createState() =>
      _DonorRequestLauncherPageState();
}

class _RecipientRequestStatusLauncherPage extends StatefulWidget {
  const _RecipientRequestStatusLauncherPage();

  @override
  State<_RecipientRequestStatusLauncherPage> createState() =>
      _RecipientRequestStatusLauncherPageState();
}

class _RecipientRequestStatusLauncherPageState
    extends State<_RecipientRequestStatusLauncherPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _errorMessage = '';
  List<RecipientRequestRecord> _requests = const [];
  List<RecipientRequestRecord> _filteredRequests = const [];
  int _currentPage = 0;
  bool _showFilters = false;
  String _selectedCategory = 'all';
  String _selectedStatus = 'all';

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

      final requestSnapshot =
          await _firestore
              .collection('ITEM_REQUEST')
              .where('recipientId', isEqualTo: userId)
              .get();

      final itemIds = requestSnapshot.docs
          .map((doc) => doc.data()['itemId']?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final listingsByItemId = <String, Map<String, dynamic>>{};
      for (final chunk in _chunkStrings(itemIds, 10)) {
        final snapshot =
            await _firestore
                .collection('ITEM_LISTING')
                .where('itemId', whereIn: chunk)
                .get();
        for (final doc in snapshot.docs) {
          final itemId =
              doc.data()['itemId']?.toString().trim().isNotEmpty == true
                  ? doc.data()['itemId'].toString().trim()
                  : doc.id;
          listingsByItemId[itemId] = {...doc.data(), '_docId': doc.id};
        }
      }

      final records = requestSnapshot.docs
        .map((doc) {
          final data = doc.data();
          final itemId = data['itemId']?.toString().trim() ?? '';
          final itemData =
              listingsByItemId[itemId] ?? const <String, dynamic>{};
          return RecipientRequestRecord(
            requestId:
                data['requestId']?.toString().trim().isNotEmpty == true
                    ? data['requestId'].toString().trim()
                    : doc.id,
            docId: doc.id,
            itemId: itemId,
            itemDocId: itemData['_docId']?.toString() ?? '',
            itemTitle:
                itemData['title']?.toString().trim().isNotEmpty == true
                    ? itemData['title'].toString().trim()
                    : 'Community item',
            itemCategory: itemData['category']?.toString().trim() ?? 'others',
            itemQuantity: _readInt(itemData['quantity']),
            availabilityStatus:
                itemData['availabilityStatus']?.toString().trim() ??
                'available',
            donorId: itemData['donorId']?.toString().trim() ?? '',
            handoverType: data['handoverType']?.toString().trim() ?? '',
            hubId: data['hubId']?.toString().trim() ?? '',
            hubName: data['hubName']?.toString().trim() ?? '',
            requestNote: data['requestNote']?.toString().trim() ?? '',
            requestStatus:
                data['requestStatus']?.toString().trim() ?? 'pending',
            requestedAt: _readDateTime(data['requestedAt']),
            updatedAt: _readDateTime(data['updatedAt']),
          );
        })
        .toList(growable: false)..sort((a, b) {
        final left =
            a.updatedAt ??
            a.requestedAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final right =
            b.updatedAt ??
            b.requestedAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _requests = records;
        _filteredRequests = _applyFilters(
          records,
          _searchController.text,
          _selectedCategory,
          _selectedStatus,
        );
        _currentPage = 0;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load request status: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingState(message: 'Loading your request status...');
    }

    if (_errorMessage.isNotEmpty) {
      return AppErrorState(message: _errorMessage, onRetry: _loadRequests);
    }

    if (_requests.isEmpty) {
      return const AppEmptyState(
        icon: Icons.timeline_outlined,
        title: 'No active requests',
        message:
            'Approved requests will appear here so you can track handover progress.',
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
                hintText: 'Search by item, status, or category',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon:
                    _searchController.text.isEmpty
                        ? null
                        : IconButton(
                          onPressed: () => _searchController.clear(),
                          icon: const Icon(Icons.close_rounded),
                        ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildHeaderControls(),
            if (_showFilters) ...[
              const SizedBox(height: AppSpacing.md),
              _buildFilters(),
            ],
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

    final paginated = _paginatedRequests;

    return RefreshIndicator(
      color: AppColors.mint,
      onRefresh: _loadRequests,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by item, status, or category',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon:
                  _searchController.text.isEmpty
                      ? null
                      : IconButton(
                        onPressed: () => _searchController.clear(),
                        icon: const Icon(Icons.close_rounded),
                      ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildHeaderControls(),
          if (_showFilters) ...[
            const SizedBox(height: AppSpacing.md),
            _buildFilters(),
          ],
          const SizedBox(height: AppSpacing.lg),
          ...paginated.map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                  title: Text(request.itemTitle),
                  subtitle: Text(
                    '${titleCaseLabel(request.requestStatus)} • ${formatCategoryLabel(request.itemCategory)}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  RecipientRequestStatusPage(request: request),
                        ),
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _PaginationBar(
            currentPage: _currentPage,
            totalPages: _totalPages,
            onPrevious:
                _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
            onNext:
                _currentPage + 1 < _totalPages
                    ? () => _goToPage(_currentPage + 1)
                    : null,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderControls() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _HeaderPill(
            icon: Icons.search_rounded,
            label: '${_filteredRequests.length} shown',
          ),
          const SizedBox(width: AppSpacing.md),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            icon: Icon(
              _showFilters ? Icons.filter_alt_off_rounded : Icons.tune_rounded,
            ),
            label: Text(_showFilters ? 'Hide filters' : 'Filters'),
          ),
        ],
      ),
    );
  }

  void _filterRequests() {
    setState(() {
      _filteredRequests = _applyFilters(
        _requests,
        _searchController.text,
        _selectedCategory,
        _selectedStatus,
      );
      _currentPage = 0;
    });
  }

  List<RecipientRequestRecord> _applyFilters(
    List<RecipientRequestRecord> requests,
    String query,
    String selectedCategory,
    String selectedStatus,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    final active = requests
        .where((request) {
          final status = request.requestStatus.toLowerCase();
          return status == 'approved' ||
              status == 'reserved' ||
              status == 'delivering' ||
              status == 'delivering_to_hub' ||
              status == 'delivering_to_recipient' ||
              status == 'item_at_community_hub' ||
              status == 'completed';
        })
        .toList(growable: false);

    return active
        .where((request) {
          final category = request.itemCategory.toLowerCase();
          final status = request.requestStatus.toLowerCase();

          if (selectedCategory != 'all' && category != selectedCategory) {
            return false;
          }

          if (selectedStatus != 'all' && status != selectedStatus) {
            return false;
          }

          if (normalizedQuery.isEmpty) {
            return true;
          }

          return request.itemTitle.toLowerCase().contains(normalizedQuery) ||
              request.requestStatus.toLowerCase().contains(normalizedQuery) ||
              request.itemCategory.toLowerCase().contains(normalizedQuery) ||
              request.itemId.toLowerCase().contains(normalizedQuery) ||
              request.hubId.toLowerCase().contains(normalizedQuery) ||
              request.requestNote.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  List<String> get _categories {
    final values =
        _requests
            .map((request) => request.itemCategory.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['all', ...values];
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        option == 'all'
                            ? 'All categories'
                            : formatCategoryLabel(option),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedCategory = value;
                  _currentPage = 0;
                  _filteredRequests = _applyFilters(
                    _requests,
                    _searchController.text,
                    _selectedCategory,
                    _selectedStatus,
                  );
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All statuses')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'reserved', child: Text('Reserved')),
                DropdownMenuItem(
                  value: 'delivering',
                  child: Text('Delivering'),
                ),
                DropdownMenuItem(
                  value: 'delivering_to_hub',
                  child: Text('Delivering to hub'),
                ),
                DropdownMenuItem(
                  value: 'delivering_to_recipient',
                  child: Text('Delivering to recipient'),
                ),
                DropdownMenuItem(
                  value: 'item_at_community_hub',
                  child: Text('Item at community hub'),
                ),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedStatus = value;
                  _currentPage = 0;
                  _filteredRequests = _applyFilters(
                    _requests,
                    _searchController.text,
                    _selectedCategory,
                    _selectedStatus,
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  List<RecipientRequestRecord> get _paginatedRequests {
    final start = _currentPage * _requestsPerPage;
    if (start >= _filteredRequests.length) {
      return const [];
    }
    final end = (start + _requestsPerPage).clamp(0, _filteredRequests.length);
    return _filteredRequests.sublist(start, end);
  }

  int get _totalPages {
    if (_filteredRequests.isEmpty) {
      return 1;
    }
    return (_filteredRequests.length / _requestsPerPage).ceil();
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) {
      return;
    }
    setState(() => _currentPage = page);
  }

  static String formatCategoryLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Unknown';
    }
    return trimmed
        .split('_')
        .map((part) {
          if (part.isEmpty) {
            return part;
          }
          return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
        })
        .join(' ');
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
}

class _DonorRequestLauncherPageState extends State<_DonorRequestLauncherPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedRequestStatus = 'all';
  String _selectedHandoverStage = 'all';
  List<DonorIncomingRequestRecord> _requests = const [];
  List<DonorIncomingRequestRecord> _filteredRequests = const [];
  int _currentPage = 0;
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
      final donorId = _auth.currentUser?.uid;
      if (donorId == null) {
        throw Exception('User not authenticated');
      }

      final listingSnapshot =
          await _firestore
              .collection('ITEM_LISTING')
              .where('donorId', isEqualTo: donorId)
              .get();
      final itemIds = listingSnapshot.docs
          .map(
            (doc) =>
                doc.data()['itemId']?.toString().trim().isNotEmpty == true
                    ? doc.data()['itemId'].toString().trim()
                    : doc.id,
          )
          .toList(growable: false);
      if (itemIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _requests = const [];
          _filteredRequests = const [];
          _currentPage = 0;
          _isLoading = false;
        });
        return;
      }

      final requestDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final chunk in _chunkStrings(itemIds, 10)) {
        final snapshot =
            await _firestore
                .collection('ITEM_REQUEST')
                .where('itemId', whereIn: chunk)
                .get();
        requestDocs.addAll(snapshot.docs);
      }

      final requestIds = requestDocs
          .map(
            (doc) =>
                doc.data()['requestId']?.toString().trim().isNotEmpty == true
                    ? doc.data()['requestId'].toString().trim()
                    : doc.id,
          )
          .toSet()
          .toList(growable: false);
      final handoversByRequestId = await _loadHandoversByRequestIds(requestIds);

      final usersById = await _loadUsersByIds(
        requestDocs
            .map((doc) => doc.data()['recipientId']?.toString().trim() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(growable: false),
      );
      final hubsById = await _loadUsersByIds(
        requestDocs
            .map((doc) => doc.data()['hubId']?.toString().trim() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(growable: false),
      );

      final records = requestDocs
        .map((doc) {
          final data = doc.data();
          final itemId = data['itemId']?.toString().trim() ?? '';
          final itemData =
              {
                for (final itemDoc in listingSnapshot.docs)
                  (itemDoc.data()['itemId']?.toString().trim().isNotEmpty ==
                          true
                      ? itemDoc.data()['itemId'].toString().trim()
                      : itemDoc.id): {...itemDoc.data(), '_docId': itemDoc.id},
              }[itemId] ??
              const <String, dynamic>{};
          final recipientId = data['recipientId']?.toString().trim() ?? '';
          final hubId = data['hubId']?.toString().trim() ?? '';
          final requestId =
              data['requestId']?.toString().trim().isNotEmpty == true
                  ? data['requestId'].toString().trim()
                  : doc.id;
          final handoverData =
              handoversByRequestId[requestId] ?? const <String, dynamic>{};

          return DonorIncomingRequestRecord(
            requestId: requestId,
            docId: doc.id,
            itemId: itemId,
            itemDocId: itemData['_docId']?.toString() ?? '',
            itemTitle:
                itemData['title']?.toString().trim().isNotEmpty == true
                    ? itemData['title'].toString().trim()
                    : 'Community item',
            itemPhotoUrl: itemData['photoUrl']?.toString().trim() ?? '',
            itemCategory: itemData['category']?.toString().trim() ?? 'others',
            itemQuantity:
                int.tryParse(itemData['quantity']?.toString() ?? '') ?? 1,
            availabilityStatus:
                itemData['availabilityStatus']?.toString().trim() ??
                'available',
            recipientId: recipientId,
            recipientName: _displayNameForUser(usersById[recipientId]),
            recipientPhone: _phoneForUser(usersById[recipientId]),
            recipientLocation: _locationForUser(usersById[recipientId]),
            handoverType: data['handoverType']?.toString().trim() ?? '',
            hubId: hubId,
            hubName:
                data['hubName']?.toString().trim().isNotEmpty == true
                    ? data['hubName'].toString().trim()
                    : _displayNameForHub(hubsById[hubId], hubId),
            requestNote: data['requestNote']?.toString().trim() ?? '',
            requestStatus:
                data['requestStatus']?.toString().trim() ?? 'pending',
            handoverStatus:
                handoverData['handoverStatus']?.toString().trim() ?? '',
            requestedAt: _readDateTime(data['requestedAt']),
            updatedAt: _readDateTime(data['updatedAt']),
          );
        })
        .toList(growable: false)..sort((a, b) {
        final left = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });

      if (!mounted) return;
      setState(() {
        _requests = records;
        _filteredRequests = _applyFilters(
          records,
          _searchController.text,
          _selectedRequestStatus,
          _selectedHandoverStage,
        );
        _currentPage = 0;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          title: const SizedBox.shrink(),
        ),
        body: const AppLoadingState(message: 'Loading requests...'),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          title: const SizedBox.shrink(),
        ),
        body: AppErrorState(message: _errorMessage, onRetry: _loadRequests),
      );
    }

    if (_requests.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          title: const SizedBox.shrink(),
        ),
        body: AppEmptyState(
          icon: Icons.inbox_outlined,
          title: widget.emptyTitle,
          message: widget.emptyMessage,
        ),
      );
    }

    if (_filteredRequests.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          title: const SizedBox.shrink(),
        ),
        body: RefreshIndicator(
          color: AppColors.mint,
          onRefresh: _loadRequests,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _buildFilters(),
              const SizedBox(height: AppSpacing.lg),
              const AppEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matching requests',
                message: 'Try a different search term.',
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
      ),
      body: RefreshIndicator(
        color: AppColors.mint,
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _buildFilters(),
            const SizedBox(height: AppSpacing.lg),
            ..._paginatedRequests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(AppSpacing.md),
                    title: Text(request.itemTitle),
                    subtitle: Text(
                      '${titleCaseLabel(request.requestStatus)} - ${request.recipientName}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => widget.builder(request: request),
                          ),
                        ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PaginationBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPrevious:
                  _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
              onNext:
                  _currentPage + 1 < _totalPages
                      ? () => _goToPage(_currentPage + 1)
                      : null,
            ),
          ],
        ),
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

  Future<Map<String, Map<String, dynamic>>> _loadUsersByIds(
    List<String> ids,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    for (final id in ids) {
      final usersDoc = await _firestore.collection('USER').doc(id).get();
      final userDoc = await _firestore.collection('USER').doc(id).get();
      result[id] = {...?usersDoc.data(), ...?userDoc.data()};
    }
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _loadHandoversByRequestIds(
    List<String> requestIds,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    for (final chunk in _chunkStrings(requestIds, 10)) {
      final snapshot =
          await _firestore
              .collection('HANDOVER')
              .where('requestId', whereIn: chunk)
              .get();
      for (final doc in snapshot.docs) {
        final requestId = doc.data()['requestId']?.toString().trim() ?? '';
        if (requestId.isNotEmpty) {
          result[requestId] = {...doc.data(), '_docId': doc.id};
        }
      }
    }
    return result;
  }

  void _filterRequests() {
    setState(() {
      _filteredRequests = _applyFilters(
        _requests,
        _searchController.text,
        _selectedRequestStatus,
        _selectedHandoverStage,
      );
      _currentPage = 0;
    });
  }

  List<DonorIncomingRequestRecord> _applyFilters(
    List<DonorIncomingRequestRecord> requests,
    String query,
    String selectedRequestStatus,
    String selectedHandoverStage,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    return requests
        .where((request) {
          final status = request.requestStatus.toLowerCase();
          final handoverStage = _effectiveHandoverStage(request);
          final isTracking = widget.title == 'Donation Tracking';
          final isEligible =
              isTracking
                  ? status == 'approved' ||
                      status == 'delivering' ||
                      status == 'delivering_to_hub' ||
                      status == 'delivering_to_recipient' ||
                      status == 'item_at_community_hub' ||
                      status == 'completed'
                  : status == 'approved' ||
                      status == 'delivering' ||
                      status == 'delivering_to_hub' ||
                      status == 'delivering_to_recipient' ||
                      status == 'item_at_community_hub';
          if (!isEligible) {
            return false;
          }

          if (selectedRequestStatus != 'all' &&
              status != selectedRequestStatus) {
            return false;
          }

          if (selectedHandoverStage != 'all' &&
              handoverStage != selectedHandoverStage) {
            return false;
          }

          if (normalizedQuery.isEmpty) {
            return true;
          }

          return request.itemTitle.toLowerCase().contains(normalizedQuery) ||
              request.recipientName.toLowerCase().contains(normalizedQuery) ||
              request.requestNote.toLowerCase().contains(normalizedQuery) ||
              request.requestStatus.toLowerCase().contains(normalizedQuery) ||
              request.itemCategory.toLowerCase().contains(normalizedQuery) ||
              request.hubName.toLowerCase().contains(normalizedQuery) ||
              request.itemId.toLowerCase().contains(normalizedQuery) ||
              request.recipientId.toLowerCase().contains(normalizedQuery) ||
              request.hubId.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  String _effectiveHandoverStage(DonorIncomingRequestRecord request) {
    final handoverStatus = request.handoverStatus.toLowerCase().trim();
    if (handoverStatus.isNotEmpty) {
      return handoverStatus;
    }

    final requestStatus = request.requestStatus.toLowerCase().trim();
    switch (requestStatus) {
      case 'approved':
      case 'delivering':
      case 'delivering_to_hub':
      case 'item_at_community_hub':
      case 'delivering_to_recipient':
      case 'completed':
        return requestStatus;
      default:
        return 'approved';
    }
  }

  Widget _buildFilters() {
    final showStatusFilters = widget.title == 'Donation Tracking';
    return Column(
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
            hintText:
                widget.title == 'Donation Tracking'
                    ? 'Search tracked requests'
                    : 'Search handover requests',
          ),
        ),
        if (showStatusFilters) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedRequestStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All statuses')),
                    DropdownMenuItem(
                      value: 'approved',
                      child: Text('Approved'),
                    ),
                    DropdownMenuItem(
                      value: 'delivering',
                      child: Text('Delivering'),
                    ),
                    DropdownMenuItem(
                      value: 'delivering_to_hub',
                      child: Text('Delivering to hub'),
                    ),
                    DropdownMenuItem(
                      value: 'item_at_community_hub',
                      child: Text('Item at community hub'),
                    ),
                    DropdownMenuItem(
                      value: 'delivering_to_recipient',
                      child: Text('Delivering to recipient'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedRequestStatus = value;
                      _currentPage = 0;
                      _filteredRequests = _applyFilters(
                        _requests,
                        _searchController.text,
                        _selectedRequestStatus,
                        _selectedHandoverStage,
                      );
                    });
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedHandoverStage,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Handover stage',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All stages')),
                    DropdownMenuItem(
                      value: 'approved',
                      child: Text('Approved'),
                    ),
                    DropdownMenuItem(
                      value: 'delivering',
                      child: Text('Delivering'),
                    ),
                    DropdownMenuItem(
                      value: 'delivering_to_hub',
                      child: Text('Delivering to hub'),
                    ),
                    DropdownMenuItem(
                      value: 'item_at_community_hub',
                      child: Text('Item at community hub'),
                    ),
                    DropdownMenuItem(
                      value: 'delivering_to_recipient',
                      child: Text('Delivering to recipient'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedHandoverStage = value;
                      _currentPage = 0;
                      _filteredRequests = _applyFilters(
                        _requests,
                        _searchController.text,
                        _selectedRequestStatus,
                        _selectedHandoverStage,
                      );
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
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

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _displayNameForUser(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return 'Recipient';
    final fullName = data['fullName']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;
    final displayName = data['displayName']?.toString().trim() ?? '';
    if (displayName.isNotEmpty) return displayName;
    final username = data['username']?.toString().trim() ?? '';
    return username.isNotEmpty ? username : 'Recipient';
  }

  static String _phoneForUser(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return 'Phone not provided';
    final phone = data['phoneNumber']?.toString().trim() ?? '';
    if (phone.isNotEmpty) return phone;
    final phoneCode = data['phoneCountryCode']?.toString().trim() ?? '';
    final localPhone = data['phoneLocalNumber']?.toString().trim() ?? '';
    final combined =
        [phoneCode, localPhone].where((v) => v.isNotEmpty).join(' ').trim();
    return combined.isNotEmpty ? combined : 'Phone not provided';
  }

  static String _locationForUser(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return 'Location not provided';
    final parts = [
      data['city']?.toString().trim() ?? '',
      data['state']?.toString().trim() ?? '',
      data['country']?.toString().trim() ?? '',
    ].where((v) => v.isNotEmpty).toList(growable: false);
    return parts.isNotEmpty ? parts.join(', ') : 'Location not provided';
  }

  static String _displayNameForHub(Map<String, dynamic>? data, String hubId) {
    if (hubId.isEmpty) return 'No hub selected';
    if (data == null || data.isEmpty) return hubId;
    final hubName = data['hubName']?.toString().trim() ?? '';
    if (hubName.isNotEmpty) return hubName;
    final displayName = data['displayName']?.toString().trim() ?? '';
    if (displayName.isNotEmpty) return displayName;
    final fullName = data['fullName']?.toString().trim() ?? '';
    return fullName.isNotEmpty ? fullName : hubId;
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

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.forest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.mint.withValues(alpha: 0.25)),
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
