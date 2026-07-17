import 'package:flutter/material.dart';

import '../app/user_role.dart';
import '../constants.dart';
import '../pages/shared/help_faq_page.dart';

class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
    required this.role,
    required this.child,
  });

  final String title;
  final String subtitle;
  final int currentIndex;
  final List<ShellDestinationData> destinations;
  final ValueChanged<int> onTap;
  final UserRole role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 82,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.mist),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        backgroundColor: AppColors.forest,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.forest, AppColors.pine],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    AppCopy.appName,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    role.label,
                    style: const TextStyle(color: AppColors.sand),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < destinations.length; i++)
              ListTile(
                leading: Icon(destinations[i].icon),
                title: Text(destinations[i].label),
                selected: i == currentIndex,
                onTap: () {
                  Navigator.of(context).pop();
                  onTap(i);
                },
              ),
            const Divider(height: 1, color: AppColors.pine),
            ListTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: const Text('Help / FAQ'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HelpFaqPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.night, Color(0xFF0F2A21)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: child,
      ),
      bottomNavigationBar: destinations.length >= 2
          ? NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: onTap,
              backgroundColor: AppColors.forest,
              indicatorColor: AppColors.mint.withValues(alpha: 0.18),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final item in destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
              ],
            )
          : null,
    );
  }
}

class ShellDestinationData {
  const ShellDestinationData({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}
