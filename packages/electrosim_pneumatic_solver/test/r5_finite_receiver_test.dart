import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

void main() {
  final IsentropicOrifice outlet = IsentropicOrifice(
    effectiveAreaM2: 1e-6,
    dischargeCoefficient: .8,
  );

  test('R5/A: finite tank droops under demand without creating gas', () {
    final FiniteIsothermalAirReceiver receiver = FiniteIsothermalAirReceiver(
      volumeM3: .002,
      initialPressureAbsPa: 701325,
      outletOrifice: outlet,
    );
    final FiniteReceiverSnapshot start = receiver.initialSnapshot;
    final FiniteReceiverSnapshot end = receiver.advance(
      start,
      durationS: .1,
      loadPressureAbsPa: 101325,
    );
    expect(end.timeS, closeTo(.1, 1e-12));
    expect(end.massKg, lessThan(start.massKg));
    expect(receiver.pressureAbsPa(end), lessThan(701325));
    expect(receiver.pressureAbsPa(end), greaterThan(101325));
    expect(end.integratedOutletKg, greaterThan(0));
    expect(end.integratedInletKg, 0);
    expect(receiver.massResidualKg(end).abs(), lessThan(1e-11));
    expect(start.massKg, receiver.initialSnapshot.massKg);
  });

  test('R5/A: closed outlet stores compressed mass without time drift', () {
    final FiniteIsothermalAirReceiver receiver = FiniteIsothermalAirReceiver(
      volumeM3: .01,
      initialPressureAbsPa: 601325,
      outletOrifice: outlet,
    );
    final FiniteReceiverSnapshot sealed = receiver.advance(
      receiver.initialSnapshot,
      durationS: .5,
      loadPressureAbsPa: 101325,
      outletOpen: false,
    );
    expect(sealed.timeS, closeTo(.5, 1e-12));
    expect(sealed.massKg, receiver.initialSnapshot.massKg);
    expect(receiver.pressureAbsPa(sealed), closeTo(601325, 1e-8));
    expect(receiver.massResidualKg(sealed), closeTo(0, 1e-12));
  });

  test('R5/A: independent refill tracks signed in/out mass', () {
    final IsentropicOrifice refillOrifice = IsentropicOrifice(
      effectiveAreaM2: 2e-6,
      dischargeCoefficient: .8,
    );
    final FiniteIsothermalAirReceiver receiver = FiniteIsothermalAirReceiver(
      volumeM3: .002,
      initialPressureAbsPa: 401325,
      outletOrifice: outlet,
      refill: PneumaticPressureBoundary(
        id: 'upstream-compressor-ideal-boundary',
        pressureAbsPa: 701325,
        orifice: refillOrifice,
        allowReverseFlow: false,
      ),
    );
    final FiniteReceiverSnapshot end = receiver.advance(
      receiver.initialSnapshot,
      durationS: .1,
      loadPressureAbsPa: 101325,
    );
    expect(end.integratedInletKg, greaterThan(0));
    expect(end.integratedOutletKg, greaterThan(0));
    expect(receiver.massResidualKg(end).abs(), lessThan(1e-11));
    expect(end.acceptedSubsteps, greaterThan(1));
  });

  test('R5/A: backpressure is not a source unless return is allowed', () {
    final FiniteIsothermalAirReceiver receiver = FiniteIsothermalAirReceiver(
      volumeM3: .002,
      initialPressureAbsPa: 201325,
      outletOrifice: outlet,
    );
    final FiniteReceiverSnapshot blocked = receiver.advance(
      receiver.initialSnapshot,
      durationS: .03,
      loadPressureAbsPa: 701325,
    );
    expect(blocked.massKg, receiver.initialSnapshot.massKg);
    final FiniteReceiverSnapshot returnFlow = receiver.advance(
      receiver.initialSnapshot,
      durationS: .03,
      loadPressureAbsPa: 701325,
      allowLoadReturn: true,
    );
    expect(returnFlow.massKg, greaterThan(blocked.massKg));
    expect(returnFlow.integratedOutletKg, lessThan(0));
    expect(receiver.massResidualKg(returnFlow).abs(), lessThan(1e-11));
  });
}
