import 'package:electrosim_domain/electrosim_domain.dart';

import 'mixed_board_projection.dart';
import 'runtime/electrosim_runtime_engine.dart';
import 'runtime/electrical_project_runtime_engine.dart';

/// Connects render-only board identities to the runtime that owns each device.
/// A mixed board combines networks for editing, while every solver still uses
/// its original local IDs and homogeneous circuit.
final class MixedBoardRuntimeView {
  MixedBoardRuntimeView({
    required this.projection,
    required this.snapshot,
    required this.running,
    required this.defaultNetworkId,
  });

  final MixedBoardProjection projection;
  final ElectricalProjectRuntimeSnapshot? snapshot;
  final bool running;
  final String? defaultNetworkId;

  Duration get elapsed => snapshot?.elapsed ?? Duration.zero;

  ElectroSimRuntimeSnapshot? get defaultRuntime =>
      snapshot?.networks[defaultNetworkId];

  MixedBoardOrigin? originForElement(String boardId) =>
      projection.componentOrigins[boardId] ??
      projection.sourceOrigins[boardId] ??
      projection.connectionOrigins[boardId] ??
      projection.instrumentOrigins[boardId];

  ElectroSimRuntimeSnapshot? runtimeForElement(String boardId) {
    final MixedBoardOrigin? origin = originForElement(boardId);
    return origin == null ? null : snapshot?.networks[origin.networkId];
  }

  ElectroSimRuntimeSnapshot? runtimeForTerminal(String boardTerminalId) {
    final MixedBoardOrigin? origin =
        projection.terminalOrigins[boardTerminalId];
    return origin == null ? null : snapshot?.networks[origin.networkId];
  }

  String? localIdForElement(String boardId) =>
      originForElement(boardId)?.localId;

  String? localTerminalId(String boardTerminalId) =>
      projection.terminalOrigins[boardTerminalId]?.localId;

  ComponentInstance? runtimeComponent(ComponentInstance boardComponent) {
    final ElectroSimRuntimeSnapshot? runtime = runtimeForElement(
      boardComponent.id.value,
    );
    final String? localId = localIdForElement(boardComponent.id.value);
    if (runtime == null || localId == null) return null;
    return runtime.effectiveCircuit.components
        .where((ComponentInstance item) => item.id.value == localId)
        .firstOrNull;
  }

  InstrumentInstance? runtimeInstrument(InstrumentInstance boardInstrument) {
    final String? localId = localIdForElement(boardInstrument.id.value);
    if (localId == null) return null;
    final Map<String, Object?> raw = boardInstrument.toJson()..['id'] = localId;
    final String? cutConnection = boardInstrument.cutConnectionId?.value;
    if (cutConnection != null) {
      raw['cutConnectionId'] =
          projection.connectionOrigins[cutConnection]?.localId ?? cutConnection;
    }
    return InstrumentInstance.fromJson(raw);
  }

  Connection? runtimeConnection(Connection boardConnection) {
    final String? localId = localIdForElement(boardConnection.id.value);
    final String? fromId = localTerminalId(
      boardConnection.fromTerminalId.value,
    );
    final String? toId = localTerminalId(boardConnection.toTerminalId.value);
    if (localId == null || fromId == null || toId == null) return null;
    return Connection(
      id: ConnectionId(localId),
      fromTerminalId: TerminalId(fromId),
      toTerminalId: TerminalId(toId),
      conductorType: boardConnection.conductorType,
      phase: boardConnection.phase,
      enabled: boardConnection.enabled,
      metadata: boardConnection.metadata,
    );
  }
}
