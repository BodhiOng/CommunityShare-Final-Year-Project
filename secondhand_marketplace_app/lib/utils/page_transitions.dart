import 'package:flutter/material.dart';
import '../constants.dart';

/// Custom page route that maintains the dark background during transitions
/// Uses fade transition instead of slide for a smoother experience
class DarkPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  
  DarkPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          // Set the background color to match your app's dark theme
          opaque: true,
          barrierColor: AppColors.charcoalBlack,
          barrierDismissible: false,
          maintainState: true,
        );
}

/// Custom page route for replacing the current page
class DarkPageReplaceRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  
  DarkPageReplaceRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          // Set the background color to match your app's dark theme
          opaque: true,
          barrierColor: AppColors.charcoalBlack,
          barrierDismissible: false,
          maintainState: true,
        );
}
