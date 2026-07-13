import 'user_role.dart';

class AppRoutes {
  static const String auth = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String shell = '/shell';
  static const String donorListings = '/donor-listings';
}

class LandingRouteArguments {
  const LandingRouteArguments({required this.role});

  final UserRole role;
}
