import 'package:flutter/material.dart';

import '../auth_wrapper.dart';
import '../login_page.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'user_role.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.auth:
        return MaterialPageRoute(
          builder: (_) => const AuthWrapper(),
          settings: settings,
        );
      case AppRoutes.login:
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
      case AppRoutes.shell:
        final args = settings.arguments;
        final config = args is AppShellArguments
            ? args
            : const AppShellArguments(role: UserRole.recipient);
        return MaterialPageRoute(
          builder: (_) => AppShell(
            role: config.role,
            initialIndex: config.initialIndex,
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const AuthWrapper(),
          settings: settings,
        );
    }
  }
}

class AppShellArguments {
  const AppShellArguments({
    required this.role,
    this.initialIndex = 0,
  });

  final UserRole role;
  final int initialIndex;
}
