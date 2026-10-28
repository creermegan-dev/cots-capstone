import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/firebase_bootstrap.dart';
import 'features/admin/admin_routes.dart';
import 'features/admin/screens/admin_shell_screen.dart';
import 'features/auth/auth_routes.dart';
import 'features/auth/auth_wrapper.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/user/follow_up_page.dart';
import 'features/user/user_bottom_nav.dart';
import 'core/root_scaffold_messenger.dart';
import 'firebase_options.dart';
import 'providers/admin_record_review_tracker.dart';
import 'providers/auth_provider.dart';
import 'services/offline_submission_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!deferFirebaseUntilFirstUse) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on UnsupportedError catch (e) {
      if (kDebugMode) {
        debugPrint('Firebase not configured for this platform: $e');
      }
    }
  }

  await OfflineSubmissionService.instance.initialize();

  runApp(const CotsMonitorApp());
}

class CotsMonitorApp extends StatelessWidget {
  const CotsMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminRecordReviewTracker(),
        ),
        ChangeNotifierProvider.value(
          value: OfflineSubmissionService.instance,
        ),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: kRootScaffoldMessengerKey,
        title: 'COTS Monitor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1F7A7A),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: Colors.white,
        ),
        home: const AuthWrapper(),
        routes: {
          AuthRoutes.signup: (_) => const SignupScreen(),
          AuthRoutes.login: (_) => const LoginScreen(),
          AdminRoutes.shell: (_) => const AdminShellScreen(),
          '/landing': (_) => const AuthWrapper(),
          userFollowUpRoute: (_) => const FollowUpPage(),
        },
      ),
    );
  }
}
