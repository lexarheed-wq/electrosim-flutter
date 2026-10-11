import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim/f18_physical_instrument_readouts.dart';
import 'package:electrosim/f18_voltmeter_3d_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final InstrumentInstance voltmeter = InstrumentInstance(
    id: InstrumentId('v-001'),
    kind: InstrumentKind.voltmeter,
    mode: InstrumentMode.voltageDc,
  );
  final InstrumentInstance ammeter = InstrumentInstance(
    id: InstrumentId('a-001'),
    kind: InstrumentKind.ammeter,
    mode: InstrumentMode.currentDc,
  );

  test('voltmeter contract never replaces other instrument kinds', () {
    expect(F18Voltmeter3dAssets.uses3d(voltmeter), isFalse);
    expect(F18Voltmeter3dAssets.uses3d(ammeter), isFalse);
  });

  test('LCD glass and runtime text fit within the Blender geometry', () {
    final Rect body = Offset.zero & F18Voltmeter3dAssets.designSize;
    final Rect lcd = F18Voltmeter3dAssets.projectReadout(body);
    final Rect glass = Rect.fromLTWH(
      body.left + F18Voltmeter3dAssets.glassNormalized.left * body.width,
      body.top + F18Voltmeter3dAssets.glassNormalized.top * body.height,
      F18Voltmeter3dAssets.glassNormalized.width * body.width,
      F18Voltmeter3dAssets.glassNormalized.height * body.height,
    );
    expect(glass.contains(lcd.topLeft), isTrue);
    expect(glass.contains(lcd.bottomRight), isTrue);
    expect(lcd.width, lessThan(50));
    expect(glass.height, 25);
  });

  test('projection respects translation and zoom without mutating probes', () {
    const Rect screenCase = Rect.fromLTWH(45, 75, 224, 304);
    final Rect display = F18Voltmeter3dAssets.projectReadout(screenCase);
    expect(display.left, closeTo(45 + 224 * 0.3060551754, 1e-7));
    expect(display.top, closeTo(75 + 304 * 0.1480263158, 1e-7));
    expect(display.width, closeTo(224 * 0.3878896491, 1e-7));
    expect(display.height, closeTo(38, 1e-7));
  });

  test('readout overlay can paint legacy fallback without a 3D image', () {
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{'v-001': Offset(200, 250)},
      elementSizes: const <String, Size>{'v-001': Size(112, 152)},
    );
    final ViewportController viewport = ViewportController();
    final F18PhysicalInstrumentReadouts painter =
        F18PhysicalInstrumentReadouts(
          layout: layout,
          viewport: viewport,
          readouts: const <String, String>{'v-001': 'ERR'},
        );
    expect(painter.voltmeterFront, isNull);
    expect(painter.voltmeter3dIds, isEmpty);
    expect(painter.screenRect('v-001'), isNotNull);
    expect(painter.screenRect('unknown'), isNull);
    viewport.dispose();
  });
}
