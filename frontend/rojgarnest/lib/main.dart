// lib/main.dart - OPTIMIZED FOR FASTER LOAD
// ✅ Profile photo loaded from CACHE instantly on app start
// ✅ UserProfileProvider registered globally

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/routes/app_routes.dart';
import 'core/network/dio_client.dart';
import 'core/utils/platform_utils.dart';
import 'core/services/profile_state_service.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/user/providers/user_profile_provider.dart';

// ✅ Global error handler for web
void reportError(FlutterErrorDetails details) {
  if (kDebugMode) {
    FlutterError.dumpErrorToConsole(details);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = reportError;

  try {
    await Hive.initFlutter();
    await Hive.openBox('settings');
    await Hive.openBox('cache');
    if (kDebugMode) debugPrint("✅ Hive initialized");
  } catch (e) {
    if (kDebugMode) debugPrint("⚠️ Hive initialization failed: $e");
  }

  initDioClient();

  // ✅ CRITICAL: Load profile photo from cache BEFORE app renders
  // This makes the photo appear INSTANTLY on splash/dashboard
  await ProfileStateService().loadFromCache();
  if (kDebugMode) {
    debugPrint(
        "⚡ main.dart: Cached photo → ${ProfileStateService().profilePhotoUrl.value}");
  }

  if (PlatformUtils.isMobile) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  if (PlatformUtils.isDesktop) {
    if (kDebugMode) {
      debugPrint('🖥️ Running on Desktop: ${PlatformUtils.platformName}');
    }
  }
  if (PlatformUtils.isWeb) {
    if (kDebugMode) debugPrint('🌐 Running on Web');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        // ✅ Global profile provider — holds photo URL for all screens
        ChangeNotifierProvider(
          create: (_) => UserProfileProvider()..loadProfile(),
        ),
      ],
      child: MaterialApp.router(
        title: 'RojgarNest',
        debugShowCheckedModeBanner: !kReleaseMode,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.system,
        routerConfig: AppRoutes.router,
        builder: (context, child) {
          return ScrollConfiguration(
            behavior: const _NoGlowScrollBehavior(),
            child: child!,
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E3A8A),
        primary: const Color(0xFF1E3A8A),
        secondary: const Color(0xFF3B82F6),
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E3A8A),
        brightness: Brightness.dark,
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}