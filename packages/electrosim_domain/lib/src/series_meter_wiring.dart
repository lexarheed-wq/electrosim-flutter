import 'circuit_state.dart';
import 'connection.dart';
import 'ids.dart';
import 'instrument.dart';

/// Shared series-input wiring contract for solver and physical cable drawing.
abstract final class SeriesMeterWiring {
  static Connection? wiredCut(CircuitState circuit, InstrumentInstance meter) {
    if (meter.kind != InstrumentKind.ammeter || meter.cutConnectionId == null) {
      return null;
    }
    final cut = circuit.connections
        .where((c) => c.id == meter.cutConnectionId && c.enabled)
        .firstOrNull;
    if (cut == null) return null;
    final amp = circuit.probes
        .where(
          (p) => p.instrumentId == meter.id && p.port == InstrumentPort.amp,
        )
        .firstOrNull
        ?.terminalId;
    final common = circuit.probes
        .where(
          (p) => p.instrumentId == meter.id && p.port == InstrumentPort.common,
        )
        .firstOrNull
        ?.terminalId;
    final bridged =
        (amp == cut.fromTerminalId && common == cut.toTerminalId) ||
        (amp == cut.toTerminalId && common == cut.fromTerminalId);
    return bridged ? cut : null;
  }

  static Set<ConnectionId> openConnectionIds(CircuitState circuit) => {
    for (final meter in circuit.instruments)
      if (meter.kind == InstrumentKind.ammeter &&
          meter.cutConnectionId != null &&
          (meter.fuseBlown || wiredCut(circuit, meter) != null))
        meter.cutConnectionId!,
  };
}
