import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

final IsentropicOrifice calibrated = IsentropicOrifice(
  effectiveAreaM2: 1e-6,
  dischargeCoefficient: .8,
);

FixedAirChamber _chamber(double pressure) => FixedAirChamber.fromPressure(
  id: 'tank',
  volumeM3: .002,
  pressureAbsPa: pressure,
);

PneumaticPressureBoundary _supply({bool enabled = true}) =>
    PneumaticPressureBoundary(
      id: 'supply',
      pressureAbsPa: 701325,
      orifice: calibrated,
      enabled: enabled,
    );

PneumaticPressureBoundary _vent() => PneumaticPressureBoundary(
  id: 'vent',
  pressureAbsPa: DryAirReference.atmosphericPressurePa,
  orifice: calibrated,
);

void main() {
  group('R2/C ideal open pressure boundaries', () {
    test(
      'PHY-03: air flows into a finite chamber and the mass ledger balances',
      () {
        final OpenIsothermalAirChamber system = OpenIsothermalAirChamber(
          initialChamber: _chamber(101325),
          boundaries: <PneumaticPressureBoundary>[_supply()],
        );
        final OpenAirSnapshot before = system.initialSnapshot;
        final OpenAirSnapshot after = system.advance(before, durationS: .5);
        expect(after.timeS, .5);
        expect(after.chamber.pressureAbsPa, greaterThan(101325));
        expect(after.chamber.pressureAbsPa, lessThan(701325));
        expect(after.externalMassAddedKg, greaterThan(0));
        expect(after.signedBoundaryFlowsKgPerS['supply'], greaterThan(0));
        expect(system.massBalanceResidualKg(after).abs(), lessThan(1e-10));
        expect(before.externalMassAddedKg, 0);
        expect(before.chamber.pressureAbsPa, closeTo(101325, 1e-9));
      },
    );

    test(
      'PHY-03: vent removes real mass without dropping below atmosphere',
      () {
        final OpenIsothermalAirChamber system = OpenIsothermalAirChamber(
          initialChamber: _chamber(701325),
          boundaries: <PneumaticPressureBoundary>[_vent()],
        );
        final OpenAirSnapshot after = system.advance(
          system.initialSnapshot,
          durationS: .5,
        );
        expect(after.chamber.pressureAbsPa, lessThan(701325));
        expect(after.chamber.pressureAbsPa, greaterThanOrEqualTo(101325));
        expect(after.externalMassAddedKg, lessThan(0));
        expect(after.signedBoundaryFlowsKgPerS['vent'], lessThan(0));
        expect(system.massBalanceResidualKg(after).abs(), lessThan(1e-10));
      },
    );

    test(
      'CPL-PRE: supply-off preserves trapped pressure, not reset to zero',
      () {
        final OpenIsothermalAirChamber full = OpenIsothermalAirChamber(
          initialChamber: _chamber(101325),
          boundaries: <PneumaticPressureBoundary>[_supply()],
        );
        final OpenAirSnapshot charged = full.advance(
          full.initialSnapshot,
          durationS: .5,
        );
        final OpenIsothermalAirChamber disabled = OpenIsothermalAirChamber(
          initialChamber: charged.chamber,
          boundaries: <PneumaticPressureBoundary>[_supply(enabled: false)],
        );
        final OpenAirSnapshot retained = disabled.advance(
          disabled.initialSnapshot,
          durationS: 1,
        );
        expect(
          retained.chamber.pressureAbsPa,
          closeTo(charged.chamber.pressureAbsPa, 1e-8),
        );
        expect(retained.externalMassAddedKg, 0);
        expect(retained.signedBoundaryFlowsKgPerS['supply'], 0);
      },
    );

    test(
      'PHY-03: two opposing boundaries sum flows without inventing mass',
      () {
        final OpenIsothermalAirChamber system = OpenIsothermalAirChamber(
          initialChamber: _chamber(300000),
          boundaries: <PneumaticPressureBoundary>[_supply(), _vent()],
        );
        final OpenAirSnapshot after = system.advance(
          system.initialSnapshot,
          durationS: 1,
        );
        expect(after.acceptedSubsteps, greaterThan(1));
        expect(after.chamber.massKg, greaterThan(0));
        expect(system.massBalanceResidualKg(after).abs(), lessThan(1e-10));
      },
    );

    test('ERR-02: invalid boundaries and identities fail explicitly', () {
      expect(
        () => PneumaticPressureBoundary(
          id: 'bad id',
          pressureAbsPa: 100000,
          orifice: calibrated,
        ),
        throwsA(isA<PneumaticPhysicsException>()),
      );
      expect(
        () => OpenIsothermalAirChamber(
          initialChamber: _chamber(101325),
          boundaries: <PneumaticPressureBoundary>[_vent(), _vent()],
        ),
        throwsA(
          isA<PneumaticPhysicsException>().having(
            (e) => e.code,
            'code',
            'duplicate_boundary',
          ),
        ),
      );
      final OpenIsothermalAirChamber limited = OpenIsothermalAirChamber(
        initialChamber: _chamber(101325),
        boundaries: <PneumaticPressureBoundary>[_supply()],
      );
      expect(
        () => limited.advance(
          limited.initialSnapshot,
          durationS: 10,
          maxStepS: 1e-6,
          maxSubsteps: 1,
        ),
        throwsA(
          isA<PneumaticPhysicsException>().having(
            (e) => e.code,
            'code',
            'substep_limit',
          ),
        ),
      );
      expect(limited.initialSnapshot.timeS, 0);
    });
  });
}
