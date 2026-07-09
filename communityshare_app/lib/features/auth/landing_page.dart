import 'package:flutter/material.dart';

import '../../app/user_role.dart';
import '../../constants.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key, this.role});

  final UserRole? role;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role != null) {
      return RoleLandingPage(role: widget.role!);
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.night, AppColors.forest, AppColors.pine],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 144,
                      height: 144,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: AppColors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Image.asset('assets/logo.png'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      AppCopy.appName,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      AppCopy.tagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.sand,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoleLandingPage extends StatelessWidget {
  const RoleLandingPage({
    super.key,
    required this.role,
    this.includeScaffold = false,
  });

  final UserRole role;
  final bool includeScaffold;

  @override
  Widget build(BuildContext context) {
    final page = _RoleLandingContent(role: role);
    if (!includeScaffold) {
      return page;
    }

    return Scaffold(body: page);
  }
}

class _RoleLandingContent extends StatelessWidget {
  const _RoleLandingContent({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final config = _RoleLandingConfig.fromRole(role);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [config.primaryColor, config.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(config.icon, color: AppColors.white, size: 32),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                config.eyebrow,
                style: const TextStyle(
                  color: AppColors.sand,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                config.title,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                config.description,
                style: const TextStyle(
                  color: AppColors.sand,
                  fontSize: 16,
                  height: 1.5,
                ),
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
                const Text(
                  'Priority actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final item in config.actions) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(config.bulletIcon, size: 18, color: config.accentColor),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(height: 1.45),
                        ),
                      ),
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

class _RoleLandingConfig {
  const _RoleLandingConfig({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actions,
    required this.icon,
    required this.bulletIcon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
  });

  final String eyebrow;
  final String title;
  final String description;
  final List<String> actions;
  final IconData icon;
  final IconData bulletIcon;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;

  static _RoleLandingConfig fromRole(UserRole role) {
    switch (role) {
      case UserRole.donor:
        return const _RoleLandingConfig(
          eyebrow: 'Donor workspace',
          title: 'Prepare donations and manage requests.',
          description: 'Start from your donor flow: create listings, review recipient requests, and keep handovers moving.',
          actions: [
            'Publish a new donation listing with category and item condition.',
            'Review active requests and confirm the next handover step.',
            'Track completed and pending item collections.',
          ],
          icon: Icons.volunteer_activism_outlined,
          bulletIcon: Icons.check_circle_outline,
          primaryColor: AppColors.forest,
          secondaryColor: AppColors.pine,
          accentColor: AppColors.mint,
        );
      case UserRole.recipient:
        return const _RoleLandingConfig(
          eyebrow: 'Recipient workspace',
          title: 'Browse support and request essentials.',
          description: 'Your landing page is centered on finding available items, submitting requests, and following collection updates.',
          actions: [
            'Browse available community items based on current need.',
            'Send a request with context so donors can review quickly.',
            'Track approval and collection details in one place.',
          ],
          icon: Icons.favorite_border,
          bulletIcon: Icons.arrow_circle_right_outlined,
          primaryColor: AppColors.night,
          secondaryColor: AppColors.forest,
          accentColor: AppColors.sun,
        );
      case UserRole.hub:
        return const _RoleLandingConfig(
          eyebrow: 'Hub workspace',
          title: 'Coordinate community handovers.',
          description: 'Community hubs start with operational visibility: confirm exchanges, manage site readiness, and monitor local throughput.',
          actions: [
            'Confirm scheduled handovers and update exchange status.',
            'Review hub availability, hours, and coordination capacity.',
            'Monitor daily activity that needs local intervention.',
          ],
          icon: Icons.holiday_village_outlined,
          bulletIcon: Icons.hub_outlined,
          primaryColor: AppColors.pine,
          secondaryColor: AppColors.forest,
          accentColor: AppColors.sand,
        );
      case UserRole.admin:
        return const _RoleLandingConfig(
          eyebrow: 'Admin workspace',
          title: 'Moderate the platform and manage access.',
          description: 'Administrators land on oversight-first content so user issues, flagged items, and platform controls are immediately visible.',
          actions: [
            'Review user reports, flagged items, and moderation backlog.',
            'Manage role assignments and account status changes.',
            'Check platform health before moving into detailed admin tools.',
          ],
          icon: Icons.admin_panel_settings_outlined,
          bulletIcon: Icons.shield_outlined,
          primaryColor: Color(0xFF3E2723),
          secondaryColor: AppColors.coral,
          accentColor: AppColors.sun,
        );
    }
  }
}
