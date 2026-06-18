import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../donor_donation_status_tracking_page.dart';
import '../donor_incoming_requests_page.dart';
import '../donor_listing_page.dart';
import '../donor_select_handover_point_page.dart';
import '../hub_handover_confirmation_page.dart';
import '../landing_page.dart';
import '../manage_hub_profile_page.dart';
import '../recipient_browse_items_page.dart';
import '../recipient_request_status_page.dart';
import '../shared_profile_page.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/state_widgets.dart';
import 'user_role.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.role,
    this.initialIndex = 0,
  });

  final UserRole role;
  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabsForRole(widget.role);
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
  final sharedHome = ShellTab(
    title: 'Home',
    label: 'Home',
    icon: Icons.home_rounded,
    builder: (context) => _HomeOverview(role: role),
  );
  final sharedNotifications = ShellTab(
    title: 'Notifications',
    label: 'Alerts',
    icon: Icons.notifications_active_outlined,
    builder: (context) => _NotificationsPage(role: role),
  );
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
        sharedHome,
        const ShellTab(
          title: 'Admin Dashboard',
          label: 'Dashboard',
          icon: Icons.admin_panel_settings_outlined,
          builder: _adminDashboard,
        ),
        const ShellTab(
          title: 'User Management',
          label: 'Users',
          icon: Icons.groups_outlined,
          builder: _adminUsers,
        ),
        sharedNotifications,
        sharedProfile,
      ];
  }
}

class _HomeOverview extends StatelessWidget {
  const _HomeOverview({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return RoleLandingPage(role: role);
  }
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.notifications_none_rounded,
      title: 'Notifications shell ready',
      message: 'Alerts, approvals, request updates, and handover reminders will plug into this shared page.',
    );
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

Widget _donorDonationTracking(BuildContext context) =>
    const _DonorRequestLauncherPage(
      title: 'Donation Tracking',
      emptyTitle: 'No trackable requests yet',
      emptyMessage:
          'Approved or scheduled requests will appear here so you can review status and complete the handover flow.',
      actionLabel: 'Open Tracking',
      actionIcon: Icons.timeline_outlined,
      builder: DonorDonationStatusTrackingPage.new,
    );

Widget _donorHandoverPoint(BuildContext context) =>
    const _DonorRequestLauncherPage(
      title: 'Select Handover Point',
      emptyTitle: 'No requests ready for handover',
      emptyMessage:
          'Once a request is approved, you can choose the COMMUNITY_HUB handover point from here.',
      actionLabel: 'Open Handover',
      actionIcon: Icons.location_on_outlined,
      builder: DonorSelectHandoverPointPage.new,
    );

Widget _recipientBrowse(BuildContext context) => const RecipientBrowseItemsPage();

Widget _recipientRequestStatus(BuildContext context) =>
    const _RecipientRequestStatusLauncherPage();

Widget _hubHandoverConfirmation(BuildContext context) =>
    const HubHandoverConfirmationPage();

Widget _hubManageProfile(BuildContext context) => const ManageHubProfilePage();

Widget _adminDashboard(BuildContext context) => const _RoleWorkspace(
      title: 'Administration',
      points: [
        'Platform summary metrics',
        'Flagged entities review',
        'Moderation shortcuts',
      ],
    );

Widget _adminUsers(BuildContext context) => const _RoleWorkspace(
      title: 'User management',
      points: [
        'Role assignments',
        'Account review and deactivation',
        'Category and access governance',
      ],
    );

class _RoleWorkspace extends StatelessWidget {
  const _RoleWorkspace({
    required this.title,
    required this.points,
  });

  final String title;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _HeroPanel(
          eyebrow: 'Skeleton',
          title: title,
          body: 'This page is intentionally lightweight so later feature work can plug into a stable shell.',
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next blocks to build here',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final point in points) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle_outline, size: 18, color: AppColors.mint),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(point)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(
          colors: [AppColors.forest, AppColors.pine],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              color: AppColors.sand,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.sand,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

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
  final Widget Function({Key? key, required DonorIncomingRequestRecord request}) builder;

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

  bool _isLoading = true;
  String _errorMessage = '';
  List<RecipientRequestRecord> _requests = const [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
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

      final requestSnapshot = await _firestore
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

      final records = requestSnapshot.docs.map((doc) {
        final data = doc.data();
        final itemId = data['itemId']?.toString().trim() ?? '';
        final itemData = listingsByItemId[itemId] ?? const <String, dynamic>{};
        return RecipientRequestRecord(
          requestId: data['requestId']?.toString().trim().isNotEmpty == true
              ? data['requestId'].toString().trim()
              : doc.id,
          docId: doc.id,
          itemId: itemId,
          itemDocId: itemData['_docId']?.toString() ?? '',
          itemTitle: itemData['title']?.toString().trim().isNotEmpty == true
              ? itemData['title'].toString().trim()
              : 'Community item',
          itemCategory: itemData['category']?.toString().trim() ?? 'others',
          itemQuantity: _readInt(itemData['quantity']),
          availabilityStatus:
              itemData['availabilityStatus']?.toString().trim() ?? 'available',
          donorId: itemData['donorId']?.toString().trim() ?? '',
          hubId: data['hubId']?.toString().trim() ?? '',
          requestNote: data['requestNote']?.toString().trim() ?? '',
          requestStatus: data['requestStatus']?.toString().trim() ?? 'pending',
          requestedAt: _readDateTime(data['requestedAt']),
          updatedAt: _readDateTime(data['updatedAt']),
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
        _requests = records;
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
      return AppErrorState(
        message: _errorMessage,
        onRetry: _loadRequests,
      );
    }

    final active = _requests.where((request) {
      final status = request.requestStatus.toLowerCase();
      return status == 'approved' ||
          status == 'reserved' ||
          status == 'delivering' ||
          status == 'delivering_to_hub' ||
          status == 'delivering_to_recipient' ||
          status == 'item_at_community_hub' ||
          status == 'completed';
    }).toList(growable: false);

    if (active.isEmpty) {
      return const AppEmptyState(
        icon: Icons.timeline_outlined,
        title: 'No active requests',
        message: 'Approved requests will appear here so you can track handover progress.',
      );
    }

    return RefreshIndicator(
      color: AppColors.mint,
      onRefresh: _loadRequests,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: active.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final request = active[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(AppSpacing.md),
              title: Text(request.itemTitle),
              subtitle: Text('${titleCaseLabel(request.requestStatus)} • ${request.itemCategory}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecipientRequestStatusPage(request: request),
                ),
              ),
            ),
          );
        },
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
}

class _DonorRequestLauncherPageState extends State<_DonorRequestLauncherPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String _errorMessage = '';
  List<DonorIncomingRequestRecord> _requests = const [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
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
      final itemIds = listingSnapshot.docs
          .map((doc) => doc.data()['itemId']?.toString().trim().isNotEmpty == true
              ? doc.data()['itemId'].toString().trim()
              : doc.id)
          .toList(growable: false);
      if (itemIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _requests = const [];
          _isLoading = false;
        });
        return;
      }

      final requestDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final chunk in _chunkStrings(itemIds, 10)) {
        final snapshot = await _firestore
            .collection('ITEM_REQUEST')
            .where('itemId', whereIn: chunk)
            .get();
        requestDocs.addAll(snapshot.docs);
      }

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

      final records = requestDocs.map((doc) {
        final data = doc.data();
        final itemId = data['itemId']?.toString().trim() ?? '';
        final itemData = {
          for (final itemDoc in listingSnapshot.docs)
            (itemDoc.data()['itemId']?.toString().trim().isNotEmpty == true
                    ? itemDoc.data()['itemId'].toString().trim()
                    : itemDoc.id):
                {...itemDoc.data(), '_docId': itemDoc.id},
        }[itemId] ??
            const <String, dynamic>{};
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
          itemQuantity: int.tryParse(itemData['quantity']?.toString() ?? '') ?? 1,
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
          requestedAt: _readDateTime(data['requestedAt']),
          updatedAt: _readDateTime(data['updatedAt']),
        );
      }).toList(growable: false)
        ..sort((a, b) {
          final left = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });

      if (!mounted) return;
      setState(() {
        _requests = records;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const AppLoadingState(message: 'Loading requests...'),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: AppErrorState(message: _errorMessage, onRetry: _loadRequests),
      );
    }

    final eligible = _requests.where((request) {
      final status = request.requestStatus.toLowerCase();
      return widget.title == 'Donation Tracking'
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
    }).toList(growable: false);

    if (eligible.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: AppEmptyState(
          icon: Icons.inbox_outlined,
          title: widget.emptyTitle,
          message: widget.emptyMessage,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        color: AppColors.mint,
        onRefresh: _loadRequests,
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: eligible.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final request = eligible[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(AppSpacing.md),
                title: Text(request.itemTitle),
                subtitle: Text('${request.requestStatus} • ${request.recipientName}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => widget.builder(request: request),
                  ),
                ),
              ),
            );
          },
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
      final usersDoc = await _firestore.collection('users').doc(id).get();
      final userDoc = await _firestore.collection('USER').doc(id).get();
      result[id] = {
        ...?usersDoc.data(),
        ...?userDoc.data(),
      };
    }
    return result;
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
    final combined = [phoneCode, localPhone].where((v) => v.isNotEmpty).join(' ').trim();
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
