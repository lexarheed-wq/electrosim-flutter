import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim/runtime/electrosim_simulation_controller.dart';
import 'package:electrosim/runtime/energy_meter_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'g5_lot_16_26_fixtures.dart';

void main() {
  test(
    'PV meter inspector uses metered evidence rather than missing-load warnings',
    () {
      final s = NativeApplianceGeometry.catalogue['energy-meter-pv']!;
      final r = const ElectroSimRuntimeEngine().evaluate(lastLotFixture(s));
      final state = r.componentOperatingState(ComponentId(s.key))!;
      expect(state.code, ComponentOperatingCode.energized);
      expect(state.warnings, isEmpty);
      expect(state.powerW, closeTo(1000, .01));
    },
  );
  const engine = ElectroSimRuntimeEngine();
  for (final key in [
    'energy-meter-ac1',
    'energy-meter-ac3',
    'energy-meter-pv',
  ]) {
    final s = NativeApplianceGeometry.catalogue[key]!;
    for (final reverse in [false, true]) {
      test(
        '$key integrates signed active power into separate registers, reverse=$reverse',
        () {
          final c = lastLotFixture(s, reverseMeter: reverse),
              before = c.toJson();
          final r = engine.advance(c, elapsed: const Duration(hours: 1));
          expect(r.solved, isTrue);
          final m = r.energyMeters[ComponentId(key)]!;
          final watts = key == 'energy-meter-ac3'
              ? 3450.0
              : key == 'energy-meter-pv'
              ? 1000.0
              : 1150.0;
          expect(m.available, isTrue);
          expect(
            r.componentOperatingState(ComponentId(key))!.code,
            ComponentOperatingCode.energized,
          );
          expect(m.powerW, closeTo(reverse ? -watts : watts, .01));
          expect(m.importWh, closeTo(reverse ? 0 : watts, .01));
          expect(m.exportWh, closeTo(reverse ? watts : 0, .01));
          expect(c.toJson(), before);
          final paused = engine
              .advance(
                c,
                elapsed: Duration.zero,
                previousEnergyMeters: r.energyMeters,
              )
              .energyMeters[ComponentId(key)]!;
          expect(paused.importWh, m.importWh);
          expect(paused.exportWh, m.exportWh);
        },
      );
    }
    test('$key serializes registers without changing graph IDs', () {
      final c = lastLotFixture(s);
      final r = engine.advance(c, elapsed: const Duration(minutes: 10));
      final saved = EnergyMeterRuntime.persist(c, r.energyMeters);
      expect(
        saved.connections.map((w) => w.id),
        c.connections.map((w) => w.id),
      );
      expect(saved.components.map((w) => w.id), c.components.map((w) => w.id));
      final restored = engine.evaluate(CircuitState.fromJson(saved.toJson()));
      expect(
        restored.energyMeters[ComponentId(key)]!.importWh,
        r.energyMeters[ComponentId(key)]!.importWh,
      );
    });
  }
  test('AC meter counts active W, not apparent VA, on inductive load', () {
    final c = lastLotFixture(
      NativeApplianceGeometry.catalogue['energy-meter-ac1']!,
    );
    final j = c.toJson();
    for (final x in j['components'] as List) {
      if (x['id'] == 'proof-load') {
        x['parameters'] = {'resistanceOhm': 20.0, 'reactanceOhm': 10.0};
      }
    }
    final r = engine.advance(
      CircuitState.fromJson(j),
      elapsed: const Duration(hours: 1),
    );
    final m = r.energyMeters[ComponentId('energy-meter-ac1')]!;
    expect(m.powerW, closeTo(230 * 230 * 20 / (20 * 20 + 10 * 10), 1e-6));
    expect(m.importWh, closeTo(2116, 1e-6));
  });
  test(
    'controller preserves registers across edits and resets on a different circuit',
    () {
      final c = lastLotFixture(
        NativeApplianceGeometry.catalogue['energy-meter-ac1']!,
      );
      final controller = ElectroSimSimulationController(circuit: c);
      addTearDown(controller.dispose);
      controller.advance(const Duration(seconds: 10));
      final before = controller
          .snapshot
          .energyMeters[ComponentId('energy-meter-ac1')]!
          .importWh;
      controller.pause();
      controller.updateCircuit(c);
      expect(
        controller
            .snapshot
            .energyMeters[ComponentId('energy-meter-ac1')]!
            .importWh,
        before,
      );
      final j = c.toJson();
      j['circuitId'] = 'different-circuit';
      controller.updateCircuit(CircuitState.fromJson(j));
      expect(
        controller
            .snapshot
            .energyMeters[ComponentId('energy-meter-ac1')]!
            .importWh,
        0,
      );
    },
  );
  test('unsolved or disconnected meter never accumulates invented energy', () {
    final c = lastLotFixture(
      NativeApplianceGeometry.catalogue['energy-meter-ac1']!,
    );
    final prior = engine.advance(c, elapsed: const Duration(seconds: 10));
    final j = c.toJson();
    j['connections'] = [];
    final r = engine.advance(
      CircuitState.fromJson(j),
      elapsed: const Duration(hours: 1),
      previousEnergyMeters: prior.energyMeters,
    );
    expect(
      r.energyMeters[ComponentId('energy-meter-ac1')]!.importWh,
      prior.energyMeters[ComponentId('energy-meter-ac1')]!.importWh,
    );
  });
  test('PV projection rejects a reserved internal wire collision', () {
    final c = lastLotFixture(
      NativeApplianceGeometry.catalogue['energy-meter-pv']!,
    );
    final j = c.toJson();
    final w = (j['connections'] as List).first as Map<String, dynamic>;
    w['id'] = 'energy-meter-feed:energy-meter-pv:0';
    expect(
      () => engine.evaluate(CircuitState.fromJson(j)),
      throwsArgumentError,
    );
  });
}
