import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/features/obd/data/datasources/elm327_serial_source.dart';
import 'package:drivelink/features/obd/data/repositories/obd_repository_impl.dart';
import 'package:drivelink/features/obd/domain/models/dtc_code.dart';
import 'package:drivelink/features/obd/domain/models/obd_data.dart';
import 'package:drivelink/features/obd/domain/repositories/obd_repository.dart';

/// Singleton ELM327 serial source.
final elm327SerialSourceProvider = Provider<Elm327SerialSource>((ref) {
  final source = Elm327SerialSource();
  ref.onDispose(() => source.dispose());
  return source;
});

/// Singleton OBD repository.
final obdRepositoryProvider = Provider<ObdRepository>((ref) {
  final serial = ref.watch(elm327SerialSourceProvider);
  final repo = ObdRepositoryImpl(serialSource: serial);
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// Live OBD data stream.
final obdDataProvider = StreamProvider<ObdData>((ref) {
  final repo = ref.watch(obdRepositoryProvider);
  return repo.dataStream;
});

/// Connection state stream — reactive, updates UI automatically.
final obdConnectionStreamProvider = StreamProvider<bool>((ref) {
  final serial = ref.watch(elm327SerialSourceProvider);
  return serial.connectionStream;
});

/// Whether the ELM327 adapter is currently connected (derived from stream).
final obdConnectedProvider = Provider<bool>((ref) {
  return ref.watch(obdConnectionStreamProvider).valueOrNull ?? false;
});

/// True while a connect() call is in progress — used to show loading UI.
final obdConnectingProvider = StateProvider<bool>((ref) => false);

/// Async notifier for DTC codes (read / clear).
final dtcCodesProvider =
    AsyncNotifierProvider<DtcCodesNotifier, List<DtcCode>>(
  DtcCodesNotifier.new,
);

class DtcCodesNotifier extends AsyncNotifier<List<DtcCode>> {
  @override
  Future<List<DtcCode>> build() async => [];

  Future<void> readCodes() async {
    state = const AsyncLoading();
    final repo = ref.read(obdRepositoryProvider);
    try {
      final codes = await repo.readDtcCodes();
      state = AsyncData(codes);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> clearCodes() async {
    final repo = ref.read(obdRepositoryProvider);
    await repo.clearDtcCodes();
    state = const AsyncData([]);
  }
}
