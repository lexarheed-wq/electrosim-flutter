import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim/runtime/f18_ammeter_fuse_safety.dart';
import 'package:electrosim/f18_ammeter_controls.dart';
import 'package:electrosim/f18_voltmeter_controls.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  const engine = ElectroSimRuntimeEngine();
  const projection = ElectroSimInstrumentProjection();

  CircuitState seriesMeter({
    double rating = 0.5,
    bool swappedLeads = false,
    bool disconnected = false,
  }) {
    final base = buildRegressionFixtureCircuit();
    final instrument = InstrumentInstance(
      id: InstrumentId('amp-fuse'),
      kind: InstrumentKind.ammeter,
      mode: InstrumentMode.currentDc,
      fuseRatingA: rating,
      maximumCurrentA: 10,
      burdenResistanceOhm: 0.01,
      cutConnectionId: ConnectionId('wire-2'),
    );
    return CircuitState(
      circuitId: base.circuitId,
      revision: base.revision,
      mode: base.mode,
      components: base.components,
      sources: base.sources,
      connections: base.connections,
      settings: base.settings,
      metadata: base.metadata,
      instruments: [instrument],
      probes: [
        ProbeConnection(
          id: ProbeId('amp-in'),
          instrumentId: instrument.id,
          port: InstrumentPort.amp,
          terminalId: TerminalId(
            disconnected ? 'lamp-out' :
            swappedLeads ? 'lamp-in' : 'switch-out',
          ),
        ),
        ProbeConnection(
          id: ProbeId('amp-com'),
          instrumentId: instrument.id,
          port: InstrumentPort.common,
          terminalId: TerminalId(
            disconnected ? 'source-neg' :
            swappedLeads ? 'switch-out' : 'lamp-in',
          ),
        ),
      ],
    );
  }

  test('real ~1 A measurement triggers 0.5 A fuse from solver only', () {
    final design = seriesMeter();
    final meter = design.instruments.single;
    final snap = engine.evaluate(design);
    final reading = projection.read(snapshot: snap, instrument: meter);
    expect(reading.status, PhysicalInstrumentStatus.blownFuse,
        reason: reading.message);
    expect(F18AmmeterFuseSafety.shouldTrip(
      circuit: design,
      instrument: meter,
      solverDetectedOvercurrent:
          reading.status == PhysicalInstrumentStatus.blownFuse,
    ), isTrue);
    expect(design.instruments.single.fuseBlown, isFalse);
  });

  test('blown fuse latches persistently and opens runtime electrical graph', () {
    final design = seriesMeter();
    final meter = design.instruments.single;
    final tripped = F18AmmeterFuseSafety.latch(
      circuit: design, instrumentId: meter.id,
    );
    expect(tripped.revision, design.revision + 1);
    expect(tripped.instruments.single.fuseBlown, isTrue);
    expect(tripped.connections, orderedEquals(design.connections));
    expect(tripped.probes, orderedEquals(design.probes));
    expect(tripped.toJsonString(), contains('"fuseBlown":true'));
    final restored = CircuitState.fromJsonString(tripped.toJsonString());
    expect(restored.instruments.single.fuseBlown, isTrue);

    final snapshot = engine.evaluate(restored);
    expect(snapshot.circuit.connections
        .firstWhere((wire) => wire.id.value == 'wire-2').enabled, isTrue);
    final opened = snapshot.effectiveCircuit.connections
        .firstWhere((wire) => wire.id.value == 'wire-2');
    expect(opened.enabled, isFalse);
    expect(snapshot.topology.enabledConnectionIds.contains(opened.id), isFalse);
    expect(snapshot.effectiveCircuit.connections
        .where((wire) => wire.id.value != 'wire-2')
        .every((wire) => wire.enabled), isTrue);
    final displayed = projection.read(
      snapshot: snapshot, instrument: restored.instruments.single,
    );
    expect(displayed.status, PhysicalInstrumentStatus.blownFuse);

    final toggled = F18AmmeterControls.apply(
      restored.instruments.single, F18VoltmeterAction.selector);
    expect(toggled.fuseBlown, isTrue,
        reason: 'Power switching must not replace a physical blown fuse');
    expect(identical(
      F18AmmeterFuseSafety.latch(circuit: restored, instrumentId: meter.id),
      restored,
    ), isTrue);
  });

  test('properly rated 10 A fuse does not trip at ~1 A', () {
    final design = seriesMeter(rating: 10);
    final meter = design.instruments.single;
    final reading = projection.read(
      snapshot: engine.evaluate(design), instrument: meter,
    );
    expect(reading.status, PhysicalInstrumentStatus.valid,
        reason: reading.message);
    expect(reading.result!.reading!.value.abs(), closeTo(24 / 24.01, .025));
    expect(F18AmmeterFuseSafety.shouldTrip(
      circuit: design, instrument: meter,
      solverDetectedOvercurrent: false,
    ), isFalse);
  });

  test('invalid amp/COM wiring cannot trip and does not open any wire', () {
    final design = seriesMeter(disconnected: true);
    final meter = design.instruments.single;
    expect(F18AmmeterFuseSafety.wiredCut(design, meter), isNull);
    expect(F18AmmeterFuseSafety.shouldTrip(
      circuit: design, instrument: meter,
      solverDetectedOvercurrent: true,
    ), isFalse);
    expect(identical(F18AmmeterFuseSafety.latch(
      circuit: design, instrumentId: meter.id,
    ), design), isTrue);
    expect(identical(F18AmmeterFuseSafety.projectOpenFuses(design), design),
        isTrue);
  });

  test('fuse disconnect preserves original conductor and other wires', () {
    final design = seriesMeter();
    final tripped = F18AmmeterFuseSafety.latch(
      circuit: design, instrumentId: design.instruments.single.id,
    );
    final effective = F18AmmeterFuseSafety.projectOpenFuses(tripped);
    final oldWire = tripped.connections
        .firstWhere((w) => w.id.value == 'wire-2');
    final newWire = effective.connections
        .firstWhere((w) => w.id == oldWire.id);
    expect(oldWire.enabled, isTrue);
    expect(newWire.enabled, isFalse);
    expect(newWire.fromTerminalId, oldWire.fromTerminalId);
    expect(newWire.toTerminalId, oldWire.toTerminalId);
    expect(newWire.phase, oldWire.phase);
    expect(newWire.conductorType, oldWire.conductorType);
    expect(newWire.metadata, oldWire.metadata);
    expect(effective.connections.length, design.connections.length);
    expect(effective.sources.length, design.sources.length);
    expect(effective.components.length, design.components.length);
  });

  test('valid reversed lead order still corresponds to cut endpoints', () {
    final design = seriesMeter(swappedLeads: true);
    expect(F18AmmeterFuseSafety.wiredCut(
      design, design.instruments.single,
    ), isNotNull);
  });
}
