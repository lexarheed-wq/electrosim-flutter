import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';

import 'electrosim_runtime_engine.dart';

enum PhysicalInstrumentStatus {
  valid,
  off,
  invalidWiring,
  overRange,
  blownFuse,
  unsupportedMode,
  unavailable,
}

final class PhysicalInstrumentReading {
  const PhysicalInstrumentReading({
    required this.instrumentId,
    required this.status,
    this.result,
    this.message,
  });

  final InstrumentId instrumentId;
  final PhysicalInstrumentStatus status;
  final MeasurementResult? result;
  final String? message;

  bool get isValid =>
      status == PhysicalInstrumentStatus.valid && (result?.isValid ?? false);
}

/// Executes independent measurement projections against the existing solvers.
/// No probe is added to the permanent circuit; adding/removing an instrument
/// cannot change the stored wiring without an explicit edit.
final class ElectroSimInstrumentProjection {
  const ElectroSimInstrumentProjection({
    this.engine = const ElectroSimRuntimeEngine(),
  });

  final ElectroSimRuntimeEngine engine;

  PhysicalInstrumentReading read({
    required ElectroSimRuntimeSnapshot snapshot,
    required InstrumentInstance instrument,
  }) {
    PhysicalInstrumentReading error(
      PhysicalInstrumentStatus status,
      String message,
    ) => PhysicalInstrumentReading(
      instrumentId: instrument.id,
      status: status,
      message: message,
    );

    if (!instrument.poweredOn) {
      return error(PhysicalInstrumentStatus.off, 'Instrument switched off.');
    }
    if (instrument.fuseBlown) {
      return error(
        PhysicalInstrumentStatus.blownFuse,
        'Instrument fuse blown.',
      );
    }
    final CircuitState circuit = snapshot.circuit;
    if (!circuit.instruments.any((item) => item.id == instrument.id)) {
      return error(
        PhysicalInstrumentStatus.invalidWiring,
        'Instrument is not part of the circuit.',
      );
    }
    final List<ProbeConnection> leads = circuit.probes
        .where((item) => item.instrumentId == instrument.id)
        .toList(growable: false);

    ProbeConnection? probe(InstrumentPort port) {
      for (final lead in leads) {
        if (lead.port == port) return lead;
      }
      return null;
    }

    // A probe is disconnected until its leads are placed. Do not display
    // N/A (which means a real incompatibility) before any PV measurement.
    if (circuit.mode == ElectricalMode.pv) {
      return _readPv(snapshot, instrument, probe);
    }

    final InstrumentMode mode = instrument.mode;
    if (mode == InstrumentMode.voltageDc ||
        mode == InstrumentMode.voltageAcRms) {
      final bool dc = mode == InstrumentMode.voltageDc;
      if ((dc && circuit.mode != ElectricalMode.dc) ||
          (!dc && circuit.mode == ElectricalMode.dc)) {
        return error(
          PhysicalInstrumentStatus.unsupportedMode,
          'Voltage mode does not match the circuit.',
        );
      }
      final TerminalId? positive = probe(InstrumentPort.voltOhm)?.terminalId;
      final TerminalId? common = probe(InstrumentPort.common)?.terminalId;
      if (positive == null || common == null || positive == common) {
        return error(
          PhysicalInstrumentStatus.invalidWiring,
          'Connect V/Ω and COM to two distinct electrical terminals.',
        );
      }

      // Finite input impedance: solve a temporary shunt using the same MNA
      // solver as the original circuit, instead of reading an ideal voltage.
      final _ProjectionWiring wiring = _projectionWiring(
        circuit,
        resistanceOhm: instrument.inputImpedanceOhm,
        first: positive,
        second: common,
      );
      final ElectroSimRuntimeSnapshot loaded = engine.evaluate(wiring.circuit);
      final MeasurementResult measured = dc
          ? loaded.measureVoltage(
              positiveProbe: wiring.first,
              negativeProbe: wiring.second,
            )
          : loaded.measureAcVoltage(
              positiveProbe: wiring.first,
              negativeProbe: wiring.second,
            );
      if (!measured.isValid || measured.reading == null) {
        return error(
          PhysicalInstrumentStatus.unavailable,
          measured.message ?? 'Physical voltage projection did not solve.',
        );
      }
      if (measured.reading!.value.abs() > instrument.maximumVoltageV) {
        return error(
          PhysicalInstrumentStatus.overRange,
          'Measurement exceeds instrument maximum voltage.',
        );
      }
      return PhysicalInstrumentReading(
        instrumentId: instrument.id,
        status: PhysicalInstrumentStatus.valid,
        result: measured,
      );
    }

    if (mode == InstrumentMode.currentDc ||
        mode == InstrumentMode.currentAcRms) {
      final bool dc = mode == InstrumentMode.currentDc;
      if ((dc && circuit.mode != ElectricalMode.dc) ||
          (!dc && circuit.mode == ElectricalMode.dc)) {
        return error(
          PhysicalInstrumentStatus.unsupportedMode,
          'Current mode does not match the circuit.',
        );
      }
      if (instrument.kind == InstrumentKind.clampAmmeter) {
        final ConnectionId? target = probe(InstrumentPort.clamp)?.connectionId;
        if (target == null) {
          return error(
            PhysicalInstrumentStatus.invalidWiring,
            'Place the clamp on one existing conductor.',
          );
        }
        final Connection? cable = circuit.connections
            .where((item) => item.id == target)
            .firstOrNull;
        if (cable == null || !cable.enabled) {
          return error(
            PhysicalInstrumentStatus.invalidWiring,
            'Clamped conductor is absent or disabled.',
          );
        }
        final double reading = snapshot
            .connectionCurrentEvidence(cable)
            .magnitudeA;
        if (!reading.isFinite) {
          return error(
            PhysicalInstrumentStatus.unavailable,
            'Cable current has no physical solution.',
          );
        }
        // Clamp current uses solver wire evidence and does not disturb the
        // circuit; signed direction is intentionally not claimed for AC.
        final MeasurementResult measured = MeasurementResult.valid(
          kind: dc ? MeasurementKind.currentDc : MeasurementKind.currentAcRms,
          value: reading,
          unit: ElectricalUnit.ampere,
          evidenceIds: <String>['wire:${target.value}'],
        );
        if (reading > instrument.maximumCurrentA) {
          return error(
            PhysicalInstrumentStatus.overRange,
            'Clamp range exceeded.',
          );
        }
        return PhysicalInstrumentReading(
          instrumentId: instrument.id,
          status: PhysicalInstrumentStatus.valid,
          result: measured,
        );
      }

      final ConnectionId? cut = instrument.cutConnectionId;
      if (cut == null ||
          probe(InstrumentPort.amp) == null ||
          probe(InstrumentPort.common) == null) {
        return error(
          PhysicalInstrumentStatus.invalidWiring,
          'Series current measurement requires cut wire, A and COM leads.',
        );
      }
      final Connection? original = circuit.connections
          .where((item) => item.id == cut)
          .firstOrNull;
      if (original == null || !original.enabled) {
        return error(
          PhysicalInstrumentStatus.invalidWiring,
          'Series connection is absent or disabled.',
        );
      }
      // The original wire is opened in the temporary projection. A real
      // ammeter burden element is inserted in series. A second solver is NOT
      // introduced, and the authored circuit remains untouched.
      final _ProjectionWiring wiring = _projectionWiring(
        circuit,
        resistanceOhm: instrument.burdenResistanceOhm,
        first: original.fromTerminalId,
        second: original.toTerminalId,
        cutConnection: cut,
      );
      final ElectroSimRuntimeSnapshot loaded = engine.evaluate(wiring.circuit);
      final MeasurementResult measured = dc
          ? loaded.measureCurrent(branchId: wiring.branchId)
          : loaded.measureAcCurrent(branchId: wiring.branchId);
      if (!measured.isValid || measured.reading == null) {
        return error(
          PhysicalInstrumentStatus.unavailable,
          measured.message ?? 'Physical current projection did not solve.',
        );
      }
      if (measured.reading!.value.abs() > instrument.fuseRatingA) {
        return error(
          PhysicalInstrumentStatus.blownFuse,
          'Meter current exceeds fuse rating; opening required.',
        );
      }
      if (measured.reading!.value.abs() > instrument.maximumCurrentA) {
        return error(
          PhysicalInstrumentStatus.overRange,
          'Meter current range exceeded.',
        );
      }
      return PhysicalInstrumentReading(
        instrumentId: instrument.id,
        status: PhysicalInstrumentStatus.valid,
        result: measured,
      );
    }
    return error(
      PhysicalInstrumentStatus.unsupportedMode,
      'This physical instrument mode has not yet been implemented.',
    );
  }

  /// PV currently publishes solved bus quantities rather than per-terminal
  /// phasors. Only match probes to a known PV/DC or inverter AC terminal pair;
  /// never infer a battery voltage from an unrelated conductor.
  PhysicalInstrumentReading _readPv(
    ElectroSimRuntimeSnapshot snapshot,
    InstrumentInstance instrument,
    ProbeConnection? Function(InstrumentPort) probe,
  ) {
    PhysicalInstrumentReading invalid(
      PhysicalInstrumentStatus status,
      String message,
    ) => PhysicalInstrumentReading(
      instrumentId: instrument.id,
      status: status,
      message: message,
    );

    final mode = instrument.mode;
    final bool voltage = mode == InstrumentMode.voltageDc ||
        mode == InstrumentMode.voltageAcRms;
    final bool current = mode == InstrumentMode.currentDc ||
        mode == InstrumentMode.currentAcRms;

    if (voltage) {
      final first = probe(InstrumentPort.voltOhm)?.terminalId;
      final second = probe(InstrumentPort.common)?.terminalId;
      if (first == null || second == null || first == second) {
        return invalid(PhysicalInstrumentStatus.invalidWiring,
          'Connect V/Ω and COM to two distinct PV terminals.');
      }
      final pv = snapshot.pvResult;
      if (pv == null || !pv.isSolved) {
        return invalid(PhysicalInstrumentStatus.unavailable,
          'PV source or topology is not solved; voltage cannot be measured.');
      }
      final nodes = snapshot.topology.terminalToNode;
      final firstNode = nodes[first];
      final secondNode = nodes[second];
      if (firstNode == null || secondNode == null ||
          firstNode == secondNode) {
        return invalid(PhysicalInstrumentStatus.invalidWiring,
          'PV voltage probes must reach distinct connected nodes.');
      }
      final circuit = snapshot.circuit;
      double? reading;
      String? evidence;
      bool matchesPair(List<Terminal> terminals, PhaseTag positive,
          PhaseTag negative) {
        final p = terminals.where((t) => t.phase == positive).toList();
        final n = terminals.where((t) => t.phase == negative).toList();
        if (p.length != 1 || n.length != 1) return false;
        final pNode = nodes[p.single.id];
        final nNode = nodes[n.single.id];
        return pNode != null && nNode != null &&
            ((firstNode == pNode && secondNode == nNode) ||
             (firstNode == nNode && secondNode == pNode));
      }
      if (mode == InstrumentMode.voltageDc) {
        for (final source in circuit.sources) {
          if (source.modelType == 'pv_array' &&
              matchesPair(source.terminals,
                  PhaseTag.dcPositive, PhaseTag.dcNegative)) {
            reading = pv.pvOperatingVoltageV;
            evidence = 'pv-array:${source.id.value}';
            break;
          }
        }
        if (reading == null && pv.batteryPresent) {
          for (final component in circuit.components) {
            if (component.modelType == 'pv_battery' &&
                matchesPair(component.terminals,
                    PhaseTag.dcPositive, PhaseTag.dcNegative)) {
              reading = pv.batteryVoltageV;
              evidence = 'pv-battery:${component.id.value}';
              break;
            }
          }
        }
      } else {
        for (final component in circuit.components) {
          if (component.modelType == 'pv_inverter' &&
              matchesPair(component.terminals,
                  PhaseTag.l1, PhaseTag.neutral)) {
            reading = pv.inverterOutputVoltageRmsV;
            evidence = 'pv-inverter:${component.id.value}';
            break;
          }
        }
      }
      if (reading == null || evidence == null || !reading.isFinite) {
        return invalid(PhysicalInstrumentStatus.invalidWiring,
          'PV measurement terminals do not correspond to a solved DC bus '
          'or inverter AC output for the selected function.');
      }
      if (reading.abs() > instrument.maximumVoltageV) {
        return invalid(PhysicalInstrumentStatus.overRange,
          'PV voltage exceeds the voltmeter range.');
      }
      return PhysicalInstrumentReading(
        instrumentId: instrument.id,
        status: PhysicalInstrumentStatus.valid,
        result: MeasurementResult.valid(
          kind: mode == InstrumentMode.voltageDc
              ? MeasurementKind.voltageDc : MeasurementKind.voltageAcRms,
          value: reading.abs(),
          unit: ElectricalUnit.volt,
          evidenceIds: [evidence],
        ),
      );
    }
    if (current) {
      if (instrument.kind == InstrumentKind.clampAmmeter) {
        final wireId = probe(InstrumentPort.clamp)?.connectionId;
        if (wireId == null) {
          return invalid(PhysicalInstrumentStatus.invalidWiring,
            'Place the PV current clamp on an existing conductor.');
        }
        final circuit = snapshot.circuit;
        final wires = circuit.connections
            .where((c) => c.id == wireId && c.enabled).toList();
        if (wires.length != 1) {
          return invalid(PhysicalInstrumentStatus.invalidWiring,
            'Clamped PV conductor is missing or disabled.');
        }
        final pv = snapshot.pvResult;
        if (pv == null || !pv.isSolved) {
          return invalid(PhysicalInstrumentStatus.unavailable,
            'PV solver has no valid current evidence.');
        }
        final cable = wires.single;
        // Only known PV source-side and inverter output buses are supported.
        // Never assign a global PV current to an arbitrary DC cable.
        final nodes = snapshot.topology.terminalToNode;
        final endpoint = nodes[cable.fromTerminalId];
        final endpoint2 = nodes[cable.toTerminalId];
        if (endpoint == null || endpoint2 == null || endpoint != endpoint2) {
          return invalid(PhysicalInstrumentStatus.invalidWiring,
            'PV clamp cable does not belong to a connected bus.');
        }
        double? value;
        String? evidence;
        if (mode == InstrumentMode.currentDc) {
          for (final source in circuit.sources.where(
              (s) => s.modelType == 'pv_array')) {
            final sourceNodes = source.terminals
                .map((t) => nodes[t.id]).toSet();
            if (sourceNodes.contains(endpoint)) {
              value = pv.pvDrawnCurrentA.abs();
              evidence = 'pv-array:${source.id.value}';
              break;
            }
          }
        } else {
          for (final component in circuit.components.where(
              (c) => c.modelType == 'pv_inverter')) {
            final terminals = component.terminals
                .where((t) => t.phase == PhaseTag.l1 || t.phase == PhaseTag.neutral);
            if (terminals.any((t) => nodes[t.id] == endpoint)) {
              value = pv.inverterOutputCurrentRmsA.abs();
              evidence = 'pv-inverter:${component.id.value}';
              break;
            }
          }
        }
        if (value == null && pv.batteryPresent &&
            mode == InstrumentMode.currentDc &&
            pv.batteryVoltageV > 0) {
          // Only a cable physically terminating on the battery port can
          // report battery charge/discharge current; do not map an unrelated
          // conductor on the same common bus to battery current.
          for (final battery in circuit.components.where(
              (c) => c.modelType == 'pv_battery')) {
            if (battery.terminals.any((t) =>
                t.id == cable.fromTerminalId ||
                t.id == cable.toTerminalId)) {
              value = (pv.batteryPowerW / pv.batteryVoltageV).abs();
              evidence = 'pv-battery:${battery.id.value}';
              break;
            }
          }
        }
        if (value == null || evidence == null) {
          return invalid(PhysicalInstrumentStatus.invalidWiring,
            'No solved PV cable current is available at the clamp position.');
        }
        if (value > instrument.maximumCurrentA) {
          return invalid(PhysicalInstrumentStatus.overRange,
            'PV current exceeds the clamp range.');
        }
        return PhysicalInstrumentReading(
          instrumentId: instrument.id,
          status: PhysicalInstrumentStatus.valid,
          result: MeasurementResult.valid(
            kind: mode == InstrumentMode.currentDc
                ? MeasurementKind.currentDc : MeasurementKind.currentAcRms,
            value: value,
            unit: ElectricalUnit.ampere,
            evidenceIds: [evidence, 'wire:${wireId.value}'],
          ),
        );
      }
      if (instrument.cutConnectionId == null ||
          probe(InstrumentPort.amp) == null ||
          probe(InstrumentPort.common) == null) {
        return invalid(PhysicalInstrumentStatus.invalidWiring,
          'Insert the PV ammeter in series using A and COM.');
      }
      // The aggregate PV model has no nodal series-burden representation.
      // Report this limitation; NEVER substitute a guessed bus current.
      return invalid(PhysicalInstrumentStatus.unsupportedMode,
        'PV series ammeter requires a burden-aware nodal PV solver.');
    }
    return invalid(PhysicalInstrumentStatus.unsupportedMode,
      'Selected PV instrument function is not supported.');
  }

  _ProjectionWiring _projectionWiring(
    CircuitState circuit, {
    required double resistanceOhm,
    required TerminalId first,
    required TerminalId second,
    ConnectionId? cutConnection,
  }) {
    var suffix = 0;
    String marker;
    do {
      marker = 'meter-projection-$suffix';
      suffix++;
    } while (circuit.components.any((c) => c.id.value == marker) ||
        circuit.connections.any((c) => c.id.value.startsWith(marker)) ||
        circuit.components.any(
          (c) => c.terminals.any((t) => t.id.value.startsWith(marker)),
        ) ||
        circuit.sources.any(
          (s) => s.terminals.any((t) => t.id.value.startsWith(marker)),
        ));
    final TerminalId a = TerminalId('$marker-a');
    final TerminalId b = TerminalId('$marker-b');
    final ComponentInstance burden = ComponentInstance(
      id: ComponentId(marker),
      modelType: 'resistor',
      terminals: <Terminal>[
        Terminal(id: a, name: 'A'),
        Terminal(id: b, name: 'B'),
      ],
      parameters: <String, Object?>{'resistanceOhm': resistanceOhm},
    );
    final CircuitState loaded = CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision,
      mode: circuit.mode,
      components: <ComponentInstance>[...circuit.components, burden],
      sources: circuit.sources,
      connections: <Connection>[
        for (final connection in circuit.connections)
          if (connection.id != cutConnection) connection,
        Connection(
          id: ConnectionId('$marker-wire-1'),
          fromTerminalId: first,
          toTerminalId: a,
        ),
        Connection(
          id: ConnectionId('$marker-wire-2'),
          fromTerminalId: b,
          toTerminalId: second,
        ),
      ],
      settings: circuit.settings,
      metadata: circuit.metadata,
    );
    return _ProjectionWiring(
      circuit: loaded,
      first: a,
      second: b,
      branchId: 'component:$marker',
    );
  }
}

final class _ProjectionWiring {
  const _ProjectionWiring({
    required this.circuit,
    required this.first,
    required this.second,
    required this.branchId,
  });

  final CircuitState circuit;
  final TerminalId first;
  final TerminalId second;
  final String branchId;
}
