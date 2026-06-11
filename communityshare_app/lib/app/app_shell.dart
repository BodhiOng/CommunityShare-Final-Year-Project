import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
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
        sharedHome,
        const ShellTab(
          title: 'Donor Dashboard',
          label: 'Dashboard',
          icon: Icons.volunteer_activism_outlined,
          builder: _donorDashboard,
        ),
        const ShellTab(
          title: 'My Listings',
          label: 'Listings',
          icon: Icons.inventory_2_outlined,
          builder: _donorListings,
        ),
        sharedNotifications,
        sharedProfile,
      ];
    case UserRole.recipient:
      return [
        sharedHome,
        const ShellTab(
          title: 'Recipient Dashboard',
          label: 'Dashboard',
          icon: Icons.favorite_border,
          builder: _recipientDashboard,
        ),
        const ShellTab(
          title: 'Browse Items',
          label: 'Browse',
          icon: Icons.search_rounded,
          builder: _recipientBrowse,
        ),
        sharedNotifications,
        sharedProfile,
      ];
    case UserRole.hub:
      return [
        sharedHome,
        const ShellTab(
          title: 'Hub Dashboard',
          label: 'Dashboard',
          icon: Icons.holiday_village_outlined,
          builder: _hubDashboard,
        ),
        const ShellTab(
          title: 'Hub Activity',
          label: 'Activity',
          icon: Icons.track_changes_outlined,
          builder: _hubActivity,
        ),
        sharedNotifications,
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
    final cards = switch (role) {
      UserRole.donor => const [
          _ActionCardData('Create listing', 'Prepare a donation item and publish it.'),
          _ActionCardData('Review requests', 'Check incoming requests and decide next steps.'),
          _ActionCardData('Track handover', 'Keep donation status and meet-up details current.'),
        ],
      UserRole.recipient => const [
          _ActionCardData('Browse support', 'Explore available items in your area.'),
          _ActionCardData('Request item', 'Send a request with a short need summary.'),
          _ActionCardData('Track collection', 'Follow request approval and handover updates.'),
        ],
      UserRole.hub => const [
          _ActionCardData('Confirm handover', 'Validate donation exchanges at the hub.'),
          _ActionCardData('Manage profile', 'Maintain location, hours, and capacity.'),
          _ActionCardData('View activity', 'Monitor current community hub tasks.'),
        ],
      UserRole.admin => const [
          _ActionCardData('Review reports', 'Inspect flagged listings and user issues.'),
          _ActionCardData('Manage categories', 'Keep classification and moderation rules aligned.'),
          _ActionCardData('Track platform health', 'Use reports to monitor operations.'),
        ],
    };

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _HeroPanel(
          eyebrow: role.label,
          title: 'CommunityShare foundation is in place.',
          body: role.description,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final card in cards) ...[
          _ActionCard(data: card),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
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

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _HeroPanel(
          eyebrow: 'Account',
          title: user?.displayName?.trim().isNotEmpty == true
              ? user!.displayName!
              : (user?.email ?? 'CommunityShare user'),
          body: 'Role: ${role.label}',
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Email', value: user?.email ?? 'Not available'),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'UID', value: user?.uid ?? 'Not available'),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget _donorDashboard(BuildContext context) => const _RoleWorkspace(
      title: 'Donor flow',
      points: [
        'Donation intake summary',
        'New listing CTA',
        'Pending request queue',
      ],
    );

Widget _donorListings(BuildContext context) => const _RoleWorkspace(
      title: 'Listings workspace',
      points: [
        'My Listings page',
        'Edit or remove listing actions',
        'Status tracking entry points',
      ],
    );

Widget _recipientDashboard(BuildContext context) => const _RoleWorkspace(
      title: 'Recipient flow',
      points: [
        'Current requests snapshot',
        'Pickup reminders',
        'Recent support activity',
      ],
    );

Widget _recipientBrowse(BuildContext context) => const _RoleWorkspace(
      title: 'Browse workspace',
      points: [
        'Browse items grid',
        'Search and filter controls',
        'Request item action path',
      ],
    );

Widget _hubDashboard(BuildContext context) => const _RoleWorkspace(
      title: 'Hub operations',
      points: [
        'Handover confirmations',
        'Hub profile maintenance',
        'Daily coordination overview',
      ],
    );

Widget _hubActivity(BuildContext context) => const _RoleWorkspace(
      title: 'Hub activity',
      points: [
        'Upcoming handovers',
        'Completed confirmations',
        'Operational notes',
      ],
    );

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

class _ActionCardData {
  const _ActionCardData(this.title, this.body);

  final String title;
  final String body;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.data});

  final _ActionCardData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.mint.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.arrow_outward_rounded, color: AppColors.mint),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    data.body,
                    style: const TextStyle(color: AppColors.mist, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.mint, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(value)),
      ],
    );
  }
}
