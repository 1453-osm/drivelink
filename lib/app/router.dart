import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:drivelink/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:drivelink/features/navigation/presentation/screens/map_screen.dart';
import 'package:drivelink/features/obd/presentation/screens/obd_dashboard_screen.dart';
import 'package:drivelink/features/media/presentation/screens/media_screen.dart';
import 'package:drivelink/features/settings/presentation/screens/settings_screen.dart';
import 'package:drivelink/features/trip_computer/presentation/screens/trip_computer_screen.dart';
import 'package:drivelink/features/vehicle_bus/presentation/screens/bus_monitor_screen.dart';
import 'package:drivelink/features/obd/presentation/screens/dtc_screen.dart';
import 'package:drivelink/features/settings/presentation/screens/vehicle_config_screen.dart';
import 'package:drivelink/features/settings/presentation/screens/usb_config_screen.dart';
import 'package:drivelink/features/settings/presentation/screens/theme_config_screen.dart';
import 'package:drivelink/features/settings/presentation/screens/map_download_screen.dart';
import 'package:drivelink/features/ai/presentation/screens/ai_assistant_screen.dart';
import 'package:drivelink/features/ai/presentation/screens/ai_settings_screen.dart';

/// Builds a [CustomTransitionPage] with a subtle fade transition.
/// Smoother than instant page flips on car head-unit displays.
CustomTransitionPage<void> _buildPage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      );
    },
  );
}

abstract final class AppRoutes {
  static const String dashboard = '/';
  static const String navigation = '/navigation';
  static const String obd = '/obd';
  static const String media = '/media';
  static const String settings = '/settings';
  static const String trip = '/trip';
  static const String busMonitor = '/bus-monitor';
  static const String dtc = '/dtc';
  static const String vehicleConfig = '/vehicle-config';
  static const String usbConfig = '/usb-config';
  static const String themeConfig = '/theme-config';
  static const String mapDownload = '/map-download';
  static const String aiAssistant = '/ai';
  static const String aiSettings = '/ai-settings';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.dashboard,
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.dashboard,
      name: 'dashboard',
      pageBuilder: (context, state) =>
          _buildPage(const DashboardScreen(), state),
      routes: <RouteBase>[
        GoRoute(
          path: 'navigation',
          name: 'navigation',
          pageBuilder: (context, state) =>
              _buildPage(const MapScreen(), state),
        ),
        GoRoute(
          path: 'obd',
          name: 'obd',
          pageBuilder: (context, state) =>
              _buildPage(const ObdDashboardScreen(), state),
        ),
        GoRoute(
          path: 'media',
          name: 'media',
          pageBuilder: (context, state) =>
              _buildPage(const MediaScreen(), state),
        ),
        GoRoute(
          path: 'settings',
          name: 'settings',
          pageBuilder: (context, state) =>
              _buildPage(const SettingsScreen(), state),
        ),
        GoRoute(
          path: 'trip',
          name: 'trip',
          pageBuilder: (context, state) =>
              _buildPage(const TripComputerScreen(), state),
        ),
        GoRoute(
          path: 'bus-monitor',
          name: 'bus-monitor',
          pageBuilder: (context, state) =>
              _buildPage(const BusMonitorScreen(), state),
        ),
        GoRoute(
          path: 'dtc',
          name: 'dtc',
          pageBuilder: (context, state) =>
              _buildPage(const DtcScreen(), state),
        ),
        GoRoute(
          path: 'vehicle-config',
          name: 'vehicle-config',
          pageBuilder: (context, state) =>
              _buildPage(const VehicleConfigScreen(), state),
        ),
        GoRoute(
          path: 'usb-config',
          name: 'usb-config',
          pageBuilder: (context, state) =>
              _buildPage(const UsbConfigScreen(), state),
        ),
        GoRoute(
          path: 'theme-config',
          name: 'theme-config',
          pageBuilder: (context, state) =>
              _buildPage(const ThemeConfigScreen(), state),
        ),
        GoRoute(
          path: 'map-download',
          name: 'map-download',
          pageBuilder: (context, state) =>
              _buildPage(const MapDownloadScreen(), state),
        ),
        GoRoute(
          path: 'ai',
          name: 'ai',
          pageBuilder: (context, state) =>
              _buildPage(const AiAssistantScreen(), state),
        ),
        GoRoute(
          path: 'ai-settings',
          name: 'ai-settings',
          pageBuilder: (context, state) =>
              _buildPage(const AiSettingsScreen(), state),
        ),
      ],
    ),
  ],
);
