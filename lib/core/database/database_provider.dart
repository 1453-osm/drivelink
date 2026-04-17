import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// Singleton Drift database instance shared across the app.
///
/// Dispose is handled by Riverpod — when the ProviderScope is destroyed
/// the database connection is closed cleanly.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
