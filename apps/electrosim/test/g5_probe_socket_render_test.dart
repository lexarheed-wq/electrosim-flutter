import 'dart:ui' as ui;
import 'package:electrosim/f18_physical_instrument_readouts.dart';
import 'package:electrosim/f18_voltmeter_3d_assets.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'connected red banana plug remains visible over its actual socket',
    (t) async {
      expect(await t.runAsync(F18Voltmeter3dAssets.preload), isTrue);
      final viewport = ViewportController();
      addTearDown(viewport.dispose);
      final meter = InstrumentInstance(
        id: InstrumentId('M'),
        kind: InstrumentKind.voltmeter,
        mode: InstrumentMode.resistance,
      );
      final circuit = CircuitState(
        circuitId: CircuitId('plug-proof'),
        revision: 0,
        mode: ElectricalMode.dc,
        components: [
          ComponentInstance(
            id: ComponentId('R'),
            modelType: 'resistor',
            terminals: [
              Terminal(id: TerminalId('a'), name: 'A'),
              Terminal(id: TerminalId('b'), name: 'B'),
            ],
            parameters: const {'resistanceOhm': 120},
          ),
        ],
        instruments: [meter],
        probes: [
          ProbeConnection(
            id: ProbeId('p'),
            instrumentId: meter.id,
            port: InstrumentPort.voltOhm,
            terminalId: TerminalId('a'),
          ),
        ],
      );
      final layout = CircuitVisualLayout(
        elementPositions: const {'M': Offset(120, 140), 'R': Offset(280, 70)},
        elementSizes: const {'M': Size(112, 152), 'R': Size(60, 30)},
      );
      final recorder = ui.PictureRecorder();
      F18PhysicalInstrumentReadouts(
        layout: layout,
        viewport: viewport,
        readouts: const {},
        circuit: circuit,
        voltmeter3dIds: const {'M'},
        voltmeterFront: F18Voltmeter3dAssets.front,
      ).paint(Canvas(recorder), const Size(360, 400));
      final picture = recorder.endRecording();
      final rgba = (await t.runAsync(() async {
        final image = await picture.toImage(360, 400);
        try {
          return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        } finally {
          image.dispose();
        }
      }))!;
      // Original mesh: A/V socket=(70,128) in the 112x152 logical front.
      // Meter top-left=(64,64), giving the actual screen contact=(134,192).
      final index = (192 * 360 + 134) * 4;
      expect(
        rgba.getUint8(index),
        206,
        reason: 'Plug must not be hidden by the baked front image',
      );
      expect(rgba.getUint8(index + 1), 40);
      final cordIndex = (205 * 360 + 134) * 4;
      expect(
        rgba.getUint8(cordIndex),
        greaterThan(180),
        reason:
            'The cable below the front plug must also remain in front of the enclosure',
      );
      picture.dispose();
    },
  );
}
