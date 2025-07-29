import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:media_kit/media_kit.dart';

import 'providers/simple_dashcam_provider.dart';
import 'providers/app_settings_provider.dart';
import 'screens/new_routes_list_screen.dart';
import 'screens/enhanced_route_player_screen.dart';
import 'utils/permissions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MediaKit for video playback
  MediaKit.ensureInitialized();

  // Request permissions for media_kit on Android
  if (UniversalPlatform.isAndroid) {
    print('🔐 请求Android权限...');
    final permissionsGranted = await PermissionUtils.requestMediaKitPermissions();
    if (!permissionsGranted) {
      print('❌ 权限被拒绝，应用可能无法正常播放视频');
    } else {
      print('✅ 权限已授予');
    }
  }

  // Configure window for desktop platforms
  if (UniversalPlatform.isDesktop) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'OpenpilotCam',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const DashcamApp());
}

class DashcamApp extends StatelessWidget {
  const DashcamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProxyProvider<AppSettingsProvider, SimpleDashcamProvider>(
          create: (context) => SimpleDashcamProvider(),
          update: (context, settings, provider) {
            provider ??= SimpleDashcamProvider();
            // 从设置中同步服务器URL
            provider.updateServerUrl(settings.serverUrl);
            return provider;
          },
        ),
      ],
      child: MaterialApp.router(
        title: 'PilotCam',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF667eea),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF667eea),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'routes',
      builder: (context, state) => const NewRoutesListScreen(),
    ),
    GoRoute(
      path: '/player/:routeName',
      name: 'player',
      builder: (context, state) {
        final routeName = state.pathParameters['routeName']!;
        return EnhancedRoutePlayerScreen(routeName: routeName);
      },
    ),
  ],
);
