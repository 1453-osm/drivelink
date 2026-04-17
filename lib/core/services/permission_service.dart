import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Handles runtime permission requests needed by DriveLink.
///
/// Checks and requests:
/// - Location (ACCESS_FINE_LOCATION) — GPS navigation
/// - Storage — offline map tile caching
class PermissionService {
  const PermissionService._();

  /// The permissions DriveLink needs at startup.
  /// Note: storage permission is NOT needed — FMTC uses app-internal storage
  /// and audio files are accessed via MediaStore/SAF.
  static const _required = [
    Permission.locationWhenInUse,
    Permission.microphone,
  ];

  /// Checks all required permissions.  Returns `true` if every permission
  /// is already granted.
  static Future<bool> allGranted() async {
    for (final p in _required) {
      if (!(await p.isGranted)) return false;
    }
    return true;
  }

  /// Requests all permissions that have not yet been granted.
  /// Returns `true` when all permissions end up granted.
  static Future<bool> requestAll() async {
    final statuses = await _required.request();
    return statuses.values.every((s) => s.isGranted);
  }

  /// Runs the full permission flow: check, explain if needed, then request.
  ///
  /// Call this once from `main()` before showing the main app.  If the user
  /// denies a permission the app will still launch — features that depend on
  /// it degrade gracefully.
  static Future<void> ensurePermissions(BuildContext context) async {
    if (await allGranted()) return;

    // Show an explanation dialog before requesting.
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Izinler Gerekli'),
          content: const Text(
            'DriveLink, navigasyon icin konum izni ve '
            'sesli komutlar icin mikrofon iznine ihtiyac duyar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    }

    await requestAll();
  }
}
