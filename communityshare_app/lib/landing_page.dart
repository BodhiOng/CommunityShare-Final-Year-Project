import 'package:flutter/material.dart';

import 'constants.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

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
