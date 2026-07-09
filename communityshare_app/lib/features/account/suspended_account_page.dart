import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../constants.dart';

class SuspendedAccountPage extends StatelessWidget {
  const SuspendedAccountPage({super.key});

  Future<void> _backToLogin(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.night, AppColors.forest],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.block_outlined,
                          color: AppColors.sun,
                          size: 56,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'Account suspended',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'This account has been suspended. You cannot use the app until an administrator restores access.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.mist,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _backToLogin(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.sun,
                              foregroundColor: AppColors.night,
                            ),
                            child: const Text('Back to Login'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
