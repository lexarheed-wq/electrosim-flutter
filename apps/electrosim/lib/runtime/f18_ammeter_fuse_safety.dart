import 'package:electrosim_domain/electrosim_domain.dart';

/// The fuse is persistent state on the physical ammeter, never an edited
/// ordinary wire. Its electrical open state is projected only for simulation.
/// A user must explicitly replace a blown fuse; power cycling never resets it.
abstract final class F18AmmeterFuseSafety {
  static Connection? wiredCut(
    CircuitState circuit,
    InstrumentInstance instrument,
  ) {
    if (instrument.kind != InstrumentKind.ammeter ||
        instrument.cutConnectionId == null) {
      return null;
    }
    final Connection? cut = circuit.connections
        .where((c) => c.id == instrument.cutConnectionId && c.enabled)
        .firstOrNull;
    if (cut == null) return null;
    final TerminalId? amp = circuit.probes
        .where(
          (p) =>
              p.instrumentId == instrument.id && p.port == InstrumentPort.amp,
        )
        .firstOrNull
        ?.terminalId;
    final TerminalId? common = circuit.probes
        .where(
          (p) =>
              p.instrumentId == instrument.id &&
              p.port == InstrumentPort.common,
        )
        .firstOrNull
        ?.terminalId;
    final bool bridged =
        (amp == cut.fromTerminalId && common == cut.toTerminalId) ||
        (amp == cut.toTerminalId && common == cut.fromTerminalId);
    return bridged ? cut : null;
  }

  /// Trips only when the caller supplies a solver-verified overcurrent. An invalid wiring,
  /// disconnected meter, unsupported mode or arbitrary ERR cannot blow a fuse.
  static bool shouldTrip({
    required CircuitState circuit,
    required InstrumentInstance instrument,
    required bool solverDetectedOvercurrent,
  }) =>
      instrument.kind == InstrumentKind.ammeter &&
      !instrument.fuseBlown &&
      solverDetectedOvercurrent &&
      wiredCut(circuit, instrument) != null;

  static CircuitState latch({
    required CircuitState circuit,
    required InstrumentId instrumentId,
  }) {
    bool changed = false;
    final instruments = <InstrumentInstance>[
      for (final meter in circuit.instruments)
        if (meter.id == instrumentId &&
            meter.kind == InstrumentKind.ammeter &&
            !meter.fuseBlown &&
            wiredCut(circuit, meter) != null)
          _markBlown(meter)
        else
          meter,
    ];
    for (var index = 0; index < circuit.instruments.length; index++) {
      if (!identical(instruments[index], circuit.instruments[index])) {
        changed = true;
        break;
      }
    }
    if (!changed) return circuit;
    return CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision + 1,
      mode: circuit.mode,
      components: circuit.components,
      sources: circuit.sources,
      connections: circuit.connections,
      instruments: instruments,
      probes: circuit.probes,
      settings: circuit.settings,
      metadata: circuit.metadata,
    );
  }

  static InstrumentInstance _markBlown(InstrumentInstance meter) =>
      InstrumentInstance(
        id: meter.id,
        kind: meter.kind,
        mode: meter.mode,
        inputImpedanceOhm: meter.inputImpedanceOhm,
        burdenResistanceOhm: meter.burdenResistanceOhm,
        maximumVoltageV: meter.maximumVoltageV,
        maximumCurrentA: meter.maximumCurrentA,
        fuseRatingA: meter.fuseRatingA,
        fuseBlown: true,
        poweredOn: meter.poweredOn,
        cutConnectionId: meter.cutConnectionId,
        settings: meter.settings,
      );

  /// A fuse can be physically replaced only after the instrument is OFF and
  /// EVERY electrical source/storage component has been removed from this
  /// simulation scene. A 0 V reading across the blown fuse is not isolation.
  /// This intentionally conservative policy cannot energize a repair scene.
  static bool canReplace(CircuitState circuit, InstrumentInstance meter) =>
      meter.kind == InstrumentKind.ammeter &&
      meter.fuseBlown &&
      !meter.poweredOn &&
      circuit.sources.isEmpty &&
      // Motors can regenerate and reactive elements may store energy.
      // Prefer a conservative explicit allow-list to fragile name guessing.
      circuit.components.every(
        (component) => const <String>{
          'resistor',
          'lamp',
          'switch',
          'switch_spst',
        }.contains(component.modelType.toLowerCase()),
      );

  static CircuitState replaceSafely({
    required CircuitState circuit,
    required InstrumentId instrumentId,
  }) {
    final meter = circuit.instruments
        .where((item) => item.id == instrumentId)
        .firstOrNull;
    if (meter == null || !canReplace(circuit, meter)) return circuit;
    final replacement = InstrumentInstance(
      id: meter.id,
      kind: meter.kind,
      mode: meter.mode,
      inputImpedanceOhm: meter.inputImpedanceOhm,
      burdenResistanceOhm: meter.burdenResistanceOhm,
      maximumVoltageV: meter.maximumVoltageV,
      maximumCurrentA: meter.maximumCurrentA,
      fuseRatingA: meter.fuseRatingA,
      fuseBlown: false,
      poweredOn: meter.poweredOn,
      cutConnectionId: meter.cutConnectionId,
      settings: meter.settings,
    );
    return CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision + 1,
      mode: circuit.mode,
      sources: circuit.sources,
      components: circuit.components,
      connections: circuit.connections,
      instruments: [
        for (final item in circuit.instruments)
          if (item.id == meter.id) replacement else item,
      ],
      probes: circuit.probes,
      settings: circuit.settings,
      metadata: circuit.metadata,
    );
  }

  /// In DC, the selected ampere meter replaces its cut ideal wire with its
  /// real burden resistor in the COMMON solver topology (not just in the LCD
  /// projection). The original wire ID is retained but electrically disabled
  /// in the runtime copy. Blown fuses are handled by projectOpenFuses first.
  ///
  /// AC and PV models remain on their pre-existing measurement projections
  /// until phase-specific solver parity is verified, avoiding phantom loads.
  static CircuitState projectDcSeriesBurden({
    required CircuitState design,
    required CircuitState fusedRuntime,
  }) {
    if (fusedRuntime.mode != ElectricalMode.dc) return fusedRuntime;
    final connected = <({InstrumentInstance meter, Connection cut})>[];
    final claimed = <ConnectionId>{};
    for (final meter in design.instruments) {
      if (meter.kind != InstrumentKind.ammeter || meter.fuseBlown) continue;
      final cut = wiredCut(design, meter);
      if (cut == null) continue;
      if (!claimed.add(cut.id)) {
        // Corrupt/imported graph with two serial meters owning the same cut.
        // Fail ELECTRICALLY OPEN, never silently restore the ideal conductor:
        // doing so would bypass both meter burdens and could hide overload.
        return CircuitState(
          circuitId: fusedRuntime.circuitId,
          revision: fusedRuntime.revision,
          mode: fusedRuntime.mode,
          components: fusedRuntime.components,
          sources: fusedRuntime.sources,
          connections: [
            for (final connection in fusedRuntime.connections)
              if (claimed.contains(connection.id))
                Connection(
                  id: connection.id,
                  fromTerminalId: connection.fromTerminalId,
                  toTerminalId: connection.toTerminalId,
                  conductorType: connection.conductorType,
                  phase: connection.phase,
                  enabled: false,
                  metadata: connection.metadata,
                )
              else
                connection,
          ],
          instruments: fusedRuntime.instruments,
          probes: fusedRuntime.probes,
          settings: fusedRuntime.settings,
          metadata: fusedRuntime.metadata,
        );
      }
      connected.add((meter: meter, cut: cut));
    }
    if (connected.isEmpty) return fusedRuntime;

    final ids = <String>{
      ...design.components.map((c) => c.id.value),
      ...design.sources.map((s) => s.id.value),
      ...design.connections.map((c) => c.id.value),
      for (final c in design.components)
        for (final t in c.terminals) t.id.value,
      for (final source in design.sources)
        for (final t in source.terminals) t.id.value,
    };
    final newComponents = <ComponentInstance>[...fusedRuntime.components];
    final newConnections = <Connection>[
      for (final connection in fusedRuntime.connections)
        if (claimed.contains(connection.id))
          Connection(
            id: connection.id,
            fromTerminalId: connection.fromTerminalId,
            toTerminalId: connection.toTerminalId,
            conductorType: connection.conductorType,
            phase: connection.phase,
            enabled: false,
            metadata: connection.metadata,
          )
        else
          connection,
    ];
    for (final entry in connected) {
      var count = 0;
      String id;
      do {
        id = 'g5-amperemeter-burden-${count++}';
      } while (ids.any((taken) => taken.startsWith(id)));
      ids.add(id);
      final a = TerminalId('$id-a');
      final b = TerminalId('$id-b');
      final amp = entry.meter;
      newComponents.add(
        ComponentInstance(
          id: ComponentId(id),
          modelType: 'resistor',
          terminals: [
            Terminal(id: a, name: 'A'),
            Terminal(id: b, name: 'COM'),
          ],
          parameters: {'resistanceOhm': amp.burdenResistanceOhm},
          controlState: {'runtimeMeterId': amp.id.value},
        ),
      );
      newConnections.addAll([
        Connection(
          id: ConnectionId('$id-wire-a'),
          fromTerminalId: entry.cut.fromTerminalId,
          toTerminalId: a,
        ),
        Connection(
          id: ConnectionId('$id-wire-b'),
          fromTerminalId: b,
          toTerminalId: entry.cut.toTerminalId,
        ),
      ]);
    }
    return CircuitState(
      circuitId: fusedRuntime.circuitId,
      revision: fusedRuntime.revision,
      mode: fusedRuntime.mode,
      sources: fusedRuntime.sources,
      components: newComponents,
      connections: newConnections,
      instruments: fusedRuntime.instruments,
      probes: fusedRuntime.probes,
      settings: fusedRuntime.settings,
      metadata: fusedRuntime.metadata,
    );
  }

  /// Runtime-only open circuit. The design connections and their metadata
  /// survive untouched; the solver sees exactly the cut wire disabled.
  static CircuitState projectOpenFuses(CircuitState design) {
    // A tripped series fuse must not reconnect just because somebody pulls
    // one probe lead away. cutConnectionId remains the authored insertion
    // point until the instrument is removed or the fuse is replaced safely.
    final cutIds = <ConnectionId>{
      for (final meter in design.instruments)
        if (meter.kind == InstrumentKind.ammeter &&
            meter.fuseBlown &&
            meter.cutConnectionId != null)
          meter.cutConnectionId!,
    };
    if (cutIds.isEmpty) return design;
    return CircuitState(
      circuitId: design.circuitId,
      revision: design.revision,
      mode: design.mode,
      sources: design.sources,
      components: design.components,
      instruments: design.instruments,
      probes: design.probes,
      connections: [
        for (final connection in design.connections)
          if (cutIds.contains(connection.id))
            Connection(
              id: connection.id,
              fromTerminalId: connection.fromTerminalId,
              toTerminalId: connection.toTerminalId,
              conductorType: connection.conductorType,
              phase: connection.phase,
              enabled: false,
              metadata: connection.metadata,
            )
          else
            connection,
      ],
      settings: design.settings,
      metadata: design.metadata,
    );
  }
}
