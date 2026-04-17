import 'package:drivelink/features/navigation/domain/models/route_model.dart';
import 'package:drivelink/features/navigation/domain/models/turn_instruction.dart';
import 'package:drivelink/features/navigation/domain/repositories/navigation_repository.dart';

/// Extracts turn-by-turn navigation instructions from a route.
class GetTurnInstructions {
  const GetTurnInstructions(this._repository);

  final NavigationRepository _repository;

  /// Execute the use case.
  Future<List<TurnInstruction>> call(RouteModel route) {
    return _repository.getTurnInstructions(route);
  }
}
