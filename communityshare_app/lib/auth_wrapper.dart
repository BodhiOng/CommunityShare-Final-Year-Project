import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app/app_shell.dart';
import 'app/user_role.dart';
import 'app/user_role_resolver.dart';
import 'landing_page.dart';
import 'login_page.dart';
import 'widgets/state_widgets.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _showSplash = true;
  Future<UserRole>? _roleFuture;
  String? _resolvedUid;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  Future<UserRole> _getUserRole(String uid) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return UserRole.recipient;
      }

      return UserRoleResolver.resolve(user);
    } catch (error) {
      debugPrint('Unable to read user role: $error');
      return UserRole.recipient;
    }
  }

  Future<UserRole> _roleFutureFor(String uid) {
    final future = _roleFuture;
    if (future != null && _resolvedUid == uid) {
      return future;
    }

    final resolved = _getUserRole(uid);
    _roleFuture = resolved;
    _resolvedUid = uid;
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const LandingPage();
    }

    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoadingState(message: 'Checking your session...'),
          );
        }

        if (!snapshot.hasData) {
          _roleFuture = null;
          _resolvedUid = null;
          return const LoginPage();
        }

        final user = snapshot.data!;
        return FutureBuilder<UserRole>(
          future: _roleFutureFor(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: AppLoadingState(message: 'Preparing your workspace...'),
              );
            }

            if (roleSnapshot.hasError) {
              return const Scaffold(
                body: AppErrorState(
                  message: 'Unable to load your role. Please try again.',
                ),
              );
            }

            final role = roleSnapshot.data ?? UserRole.recipient;
            final initialIndex = role == UserRole.donor ? 0 : 0;
            return AppShell(
              role: role,
              initialIndex: initialIndex,
            );
          },
        );
      },
    );
  }
}
