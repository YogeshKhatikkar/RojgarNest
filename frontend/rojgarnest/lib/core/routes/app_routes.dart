// lib/core/routes/app_routes.dart

import 'package:go_router/go_router.dart';

import 'package:rojgarnest/features/splash/splash_page.dart';
import 'package:rojgarnest/features/home/home_screen.dart';
import 'package:rojgarnest/features/auth/presentation/screens/register_login_page.dart';
import 'package:rojgarnest/features/auth/presentation/screens/verify_otp_page.dart';
import 'package:rojgarnest/features/auth/presentation/screens/change_password_screen.dart';
import 'package:rojgarnest/features/user/presentation/screens/user_dashboard.dart';
import 'package:rojgarnest/features/admin/presentation/screens/admin_dashboard.dart';
import 'package:rojgarnest/features/superadmin/presentation/screens/superadmin_dashboard.dart';
import 'package:rojgarnest/features/customadmin/presentation/screens/customadmin_dashboard.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String home = '/';
  static const String auth = '/auth';
  static const String verifyOtp = '/verify-otp';
  static const String changePassword = '/change-password';
  static const String userDashboard = '/user';
  static const String adminDashboard = '/admin';
  static const String customAdminDashboard = '/customadmin';
  static const String superAdminDashboard = '/superadmin';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    debugLogDiagnostics: true,
    // ✅ CRITICAL: No redirect. Each screen handles its own auth.
    //    This prevents the router from bouncing the user to / when
    //    a scheme application finishes and a background API call
    //    happens to return 401 momentarily.
    routes: [
      GoRoute(
        path: splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: auth,
        name: 'auth',
        builder: (context, state) {
          final tabParam = state.uri.queryParameters['tab'];
          return RegisterLoginPage(initialTab: tabParam);
        },
      ),
      GoRoute(
        path: verifyOtp,
        name: 'verify-otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return VerifyOtpPage(
            email: extra['email'] as String? ?? '',
            mobile: extra['mobile'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: changePassword,
        name: 'change-password',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChangePasswordScreen(
            isForgotFlow: extra['isForgotFlow'] as bool? ?? false,
            isEmbedded: extra['isEmbedded'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: userDashboard,
        name: 'user-dashboard',
        builder: (context, state) => const UserDashboard(),
      ),
      GoRoute(
        path: adminDashboard,
        name: 'admin-dashboard',
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: customAdminDashboard,
        name: 'customadmin-dashboard',
        builder: (context, state) => const CustomAdminDashboard(),
      ),
      GoRoute(
        path: superAdminDashboard,
        name: 'superadmin-dashboard',
        builder: (context, state) => const SuperAdminDashboard(),
      ),
    ],
  );
}