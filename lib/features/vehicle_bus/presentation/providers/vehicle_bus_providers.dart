import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/features/vehicle_bus/data/datasources/esp32_serial_source.dart';
import 'package:drivelink/features/vehicle_bus/data/repositories/vehicle_bus_repository_impl.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/van_message.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/vehicle_state.dart';
import 'package:drivelink/features/vehicle_bus/domain/repositories/vehicle_bus_repository.dart';

/// Singleton ESP32 serial source.
final esp32SerialSourceProvider = Provider<Esp32SerialSource>((ref) {
  final source = Esp32SerialSource();
  ref.onDispose(() => source.dispose());
  return source;
});

/// Singleton vehicle bus repository.
final vehicleBusRepositoryProvider = Provider<VehicleBusRepository>((ref) {
  final serial = ref.watch(esp32SerialSourceProvider);
  final repo = VehicleBusRepositoryImpl(serialSource: serial);
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// Live vehicle state stream.
final vehicleStateProvider = StreamProvider<VehicleState>((ref) {
  final repo = ref.watch(vehicleBusRepositoryProvider);
  return repo.vehicleStateStream;
});

/// Raw VAN message stream for the debug monitor.
final vanMessageStreamProvider = StreamProvider<VanMessage>((ref) {
  final repo = ref.watch(vehicleBusRepositoryProvider);
  return repo.messageStream;
});

/// Whether the ESP32 serial link is connected.
final vehicleBusConnectedProvider = Provider<bool>((ref) {
  final repo = ref.watch(vehicleBusRepositoryProvider);
  return repo.isConnected;
});

/// Live diagnostic counters from the ESP32 serial source — polled every
/// second so the Bus Monitor UI can show `bytes / parsed / errors` without
/// the source having to push updates.
final esp32StatsProvider = StreamProvider<Map<String, int>>((ref) {
  final source = ref.watch(esp32SerialSourceProvider);
  final controller = StreamController<Map<String, int>>();
  // Seed the first tick immediately so the UI has something to render.
  controller.add(source.stats);
  final timer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (!controller.isClosed) controller.add(source.stats);
  });
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});
