import 'package:electrosim/f18_ammeter_controls.dart';
import 'package:electrosim/f18_ammeter_3d_assets.dart';
import 'package:electrosim/f18_voltmeter_controls.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  InstrumentInstance meter() => InstrumentInstance(
    id: InstrumentId('fused-current'),
    kind: InstrumentKind.ammeter,
    mode: InstrumentMode.currentDc,
    burdenResistanceOhm: 0.01,
    fuseRatingA: 10,
    maximumCurrentA: 10,
    cutConnectionId: ConnectionId('wire-under-test'),
  );
  test('ammeter readout projection is inside its own physical LCD', () {
    const body = Rect.fromLTWH(50, 60, 224, 304);
    final display = F18Ammeter3dAssets.projectReadout(body);
    final glass = Rect.fromLTWH(
      body.left + 224 * (31 / 112),
      body.top + 304 * (21 / 152),
      224 * (50 / 112),
      304 * (24 / 152),
    );
    expect(glass.contains(display.topLeft), isTrue);
    expect(glass.contains(display.bottomRight), isTrue);
    expect(display.width, closeTo(88, 0.00001));
    expect(display.height, closeTo(36, 0.00001));
  });

  test('physical assets cannot disguise ammeter as voltmeter', () {
    final m = meter();
    expect(F18Ammeter3dAssets.uses3d(m), F18Ammeter3dAssets.ready);
    final v = InstrumentInstance(
      id: InstrumentId('voltage'),
      kind: InstrumentKind.voltmeter,
      mode: InstrumentMode.voltageDc,
    );
    expect(F18Ammeter3dAssets.uses3d(v), isFalse);
    expect(F18Ammeter3dAssets.frontPath, contains('ammeter-front'));
    expect(F18Ammeter3dAssets.palettePath, contains('ammeter-palette'));
  });

  test('HOLD only freezes valid current; FUSE overrides HOLD', () {
    var a = meter();
    expect(
      identical(
        F18AmmeterControls.apply(
          a,
          F18VoltmeterAction.hold,
          text: 'ERR',
          valid: false,
        ),
        a,
      ),
      isTrue,
    );
    a = F18AmmeterControls.apply(
      a,
      F18VoltmeterAction.hold,
      text: '0.98 A',
      value: 0.98,
      valid: true,
    );
    expect(F18AmmeterControls.display(a, '1.01 A', 1.01, true), '0.98 A');
    a = F18AmmeterControls.apply(a, F18VoltmeterAction.hold);
    expect(F18AmmeterControls.held(a), isFalse);
    expect(F18AmmeterControls.display(a, 'ERR', null, false), 'ERR');
  });

  test('mode, light and ranges preserve the amp series connection', () {
    var a = meter();
    final originalCut = a.cutConnectionId;
    a = F18AmmeterControls.apply(a, F18VoltmeterAction.light);
    expect(F18AmmeterControls.lit(a), isTrue);
    a = F18AmmeterControls.apply(a, F18VoltmeterAction.select);
    expect(a.mode, InstrumentMode.currentAcRms);
    expect(F18AmmeterControls.rangeLabel(a), 'AUTO');
    a = F18AmmeterControls.apply(a, F18VoltmeterAction.range);
    expect(F18AmmeterControls.rangeIndex(a), 1);
    expect(F18AmmeterControls.rangeLabel(a), '200 mA');
    expect(F18AmmeterControls.display(a, '0.75 A', 0.75, true), 'OL');
    a = F18AmmeterControls.apply(a, F18VoltmeterAction.range);
    expect(F18AmmeterControls.rangeLabel(a), '2.0 A');
    expect(F18AmmeterControls.display(a, '0.75 A', 0.75, true), '0.75 A');
    a = F18AmmeterControls.apply(a, F18VoltmeterAction.range);
    expect(F18AmmeterControls.rangeLabel(a), '10 A');
    a = F18AmmeterControls.apply(a, F18VoltmeterAction.range);
    expect(F18AmmeterControls.rangeLabel(a), 'AUTO');
    expect(a.burdenResistanceOhm, 0.01);
    expect(a.fuseRatingA, 10);
    expect(a.cutConnectionId, originalCut);
  });

  test('fuse hatch does not intercept ammeter selector hit region', () {
    const size = Size(112, 152);
    expect(
      F18AmmeterControls.actionAt(const Offset(53, 86), size),
      F18VoltmeterAction.selector,
    );
    expect(F18AmmeterControls.actionAt(const Offset(53, 114), size), isNull);
    expect(
      F18AmmeterControls.actionAt(const Offset(35, 56), size),
      F18VoltmeterAction.hold,
    );
    expect(
      F18AmmeterControls.actionAt(const Offset(77, 56), size),
      F18VoltmeterAction.light,
    );
  });

  test('selector never creates a new electrical terminal or meter type', () {
    var a = meter();
    a = F18AmmeterControls.apply(a, F18VoltmeterAction.selector);
    expect(a.mode, InstrumentMode.currentAcRms);
    a = F18AmmeterControls.apply(a, F18VoltmeterAction.selector);
    expect(a.poweredOn, isFalse);
    expect(F18AmmeterControls.display(a, '3 A', 3, true), 'OFF');
    a = F18AmmeterControls.apply(a, F18VoltmeterAction.selector);
    expect(a.mode, InstrumentMode.currentDc);
    expect(a.kind, InstrumentKind.ammeter);
  });
}
