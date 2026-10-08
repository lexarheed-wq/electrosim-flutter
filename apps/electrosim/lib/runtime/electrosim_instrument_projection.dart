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
      return error(PhysicalInstrumentStatus.blownFuse, 'Instrument fuse blown.');
    }
    final CircuitState circuit = snapshot.circuit;
    if (!circuit.instruments.any((item) => item.id == instrument.id)) {
      return error(
        PhysicalInstrumentStatus.invalidWiring,
        'Instrument is not part of the circuit.',
      );
    }
    if (circuit.mode == ElectricalMode.pv) {
      return error(
        PhysicalInstrumentStatus.unsupportedMode,
        'PV physical probe loading requires unified DC/PV island projection.',
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
            .where((item) => item.id == target).firstOrNull;
        if (cable == null || !cable.enabled) {
          return error(
            PhysicalInstrumentStatus.invalidWiring,
            'Clamped conductor is absent or disabled.',
          );
        }
        final double reading = snapshot.connectionCurrentEvidence(cable).magnitudeA;
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
          .where((item) => item.id == cut).firstOrNull;
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
        circuit.components.any((c) =>
            c.terminals.any((t) => t.id.value.startsWith(marker))) ||
        circuit.sources.any((s) =>
            s.terminals.any((t) => t.id.value.startsWith(marker))));
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
      circuit: loaded, first: a, second: b,
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
