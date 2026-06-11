import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app_router.dart';
import 'app/app_routes.dart';
import 'constants.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (error) {
    debugPrint('Failed to initialize Firebase: $error');
  }

  runApp(const CommunityShareApp());
}

class CommunityShareApp extends StatelessWidget {
  const CommunityShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppCopy.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      initialRoute: AppRoutes.auth,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
