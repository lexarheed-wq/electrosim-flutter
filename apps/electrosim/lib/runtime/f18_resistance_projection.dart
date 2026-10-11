import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'electrosim_instrument_projection.dart';
import 'electrosim_runtime_engine.dart';
import 'f18_ohm_test_circuit.dart';

/// Reads a passive network with a real 1 V / 1 kΩ temporary test injection.
abstract final class F18ResistanceProjection {
  static PhysicalInstrumentReading read({
    required ElectroSimRuntimeEngine engine,
    required CircuitState circuit,
    required InstrumentInstance instrument,
    required TerminalId? first,
    required TerminalId? second,
  }) {
    PhysicalInstrumentReading fail(PhysicalInstrumentStatus s, String m) =>
        PhysicalInstrumentReading(instrumentId: instrument.id, status: s, message: m);
    if (first == null || second == null || first == second) {
      return fail(PhysicalInstrumentStatus.invalidWiring,
          'Place V/Ω and COM on two different terminals.');
    }
    if (instrument.kind != InstrumentKind.voltmeter) {
      return fail(PhysicalInstrumentStatus.unsupportedMode,
          'Ω mode is supported by the physical voltmeter only.');
    }
    final disposable = F18OhmTestCircuit.build(circuit, first, second);
    if (disposable == null) {
      return fail(PhysicalInstrumentStatus.unsupportedMode,
          'Disconnect all sources and use only passive supported elements.');
    }
    if (!F18OhmTestCircuit.hasConductivePath(circuit, first, second)) {
      return fail(PhysicalInstrumentStatus.overRange,
          'Open circuit between V/Ω and COM: OL.');
    }
    final ElectroSimRuntimeSnapshot solved;
    try {
      solved = engine.evaluate(disposable);
    } on Object {
      return fail(PhysicalInstrumentStatus.unavailable,
          'Passive resistance projection could not be solved.');
    }
    if (!solved.solved) {
      return fail(PhysicalInstrumentStatus.unavailable,
          'Passive resistance projection did not converge.');
    }
    final observed = solved.measureVoltage(
      positiveProbe: first, negativeProbe: second,
    );
    final double? drop = observed.reading?.value;
    if (!observed.isValid || drop == null || !drop.isFinite ||
        drop < -1e-6 || drop > 1.000001) {
      return fail(PhysicalInstrumentStatus.unavailable,
          'Probe differential under test is unavailable.');
    }
    final double referenceDrop = 1 - drop;
    if (referenceDrop <= 1e-8) {
      return fail(PhysicalInstrumentStatus.overRange,
          'Open circuit or resistance beyond range.');
    }
    final double ohms = 1000 * (drop < 0 ? 0 : drop) / referenceDrop;
    if (!ohms.isFinite || ohms < 0 || ohms > 2000000) {
      return fail(PhysicalInstrumentStatus.overRange,
          'Resistance exceeds 2 MΩ.');
    }
    return PhysicalInstrumentReading(
      instrumentId: instrument.id,
      status: PhysicalInstrumentStatus.valid,
      result: MeasurementResult.valid(
        kind: MeasurementKind.resistance,
        value: ohms,
        unit: ElectricalUnit.ohm,
        evidenceIds: [
          'probe:' + first.value, 'probe:' + second.value,
          'ohm:reference-1000ohm', 'ohm:test-1volt',
        ],
      ),
    );
  }
}
