import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app/app.dart';
import 'core/database/database.dart';
import 'core/database/database_provider.dart';
import 'core/services/offline_map_service.dart';
import 'core/services/permission_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MapLibre offline system (set high tile limit).
  await OfflineMapService().initialize();

  // Create the Drift database eagerly so it's ready for all providers.
  final database = AppDatabase();

  WakelockPlus.enable();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Center(
        child: Text(
          'Hata: ${details.exception}',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  };

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
      child: _AppWithPermissions(),
    ),
  );
}

class _AppWithPermissions extends StatefulWidget {
  @override
  State<_AppWithPermissions> createState() => _AppWithPermissionsState();
}

class _AppWithPermissionsState extends State<_AppWithPermissions> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await PermissionService.requestAll().timeout(
        const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF121212),
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return const DriveLinkApp();
  }
}
