import 'dart:ui' as ui;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final circuit = CircuitState(
    circuitId: CircuitId('metal-material'),
    revision: 0,
    mode: ElectricalMode.dc,
  );

  Future<List<int>> pixel({
    required int x,
    required int y,
    bool schematic = false,
    bool chrome = false,
    CabinetEnvelope? envelope,
    double scale = 1,
    ui.Offset translation = ui.Offset.zero,
    CircuitState? paintedCircuit,
    CircuitVisualLayout? paintedLayout,
  }) async {
    final viewport = ViewportController(scale: scale, translation: translation);
    final recorder = ui.PictureRecorder();
    CircuitScenePainter(
      circuit: paintedCircuit ?? circuit,
      layout:
          paintedLayout ??
          CircuitVisualLayout(
            elementPositions: const {},
            cabinetLayout: CabinetLayout(const [], envelope: envelope),
          ),
      viewport: viewport,
      paintElementChrome: chrome,
      schematicPresentation: schematic,
      smartWireSemantics: true,
    ).paint(ui.Canvas(recorder), const ui.Size(600, 500));
    final picture = recorder.endRecording();
    final image = await picture.toImage(600, 500);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = 4 * (y * 600 + x);
    final result = List.generate(4, (i) => bytes.getUint8(offset + i));
    image.dispose();
    picture.dispose();
    viewport.dispose();
    return result;
  }

  void expectMetal(List<int> rgba) {
    // Satin silver is visibly darker than the old F6F8FB grid or F2F4F6
    // cabinet fill. Checking real pixels catches a lost drawing integration.
    expect(rgba[0], inInclusiveRange(200, 238));
    expect(rgba[1], greaterThanOrEqualTo(rgba[0]));
    expect(rgba[2], greaterThanOrEqualTo(rgba[0]));
    expect(rgba[3], 255);
  }

  test('physical empty plate draws satin silver instead of the grid', () async {
    expectMetal(await pixel(x: 205, y: 203));
    expect(await pixel(x: 205, y: 203), isNot(await pixel(x: 405, y: 303)));
  });

  test('schematic remains white with an authored cabinet', () async {
    expect(
      await pixel(
        x: 205,
        y: 203,
        schematic: true,
        envelope: CabinetEnvelope(widthMm: 500, heightMm: 400, depthMm: 180),
      ),
      [255, 255, 255, 255],
    );
  });

  test('authored cabinet mounting plate uses the satin material', () async {
    expectMetal(
      await pixel(
        x: 205,
        y: 203,
        envelope: CabinetEnvelope(widthMm: 500, heightMm: 400, depthMm: 180),
      ),
    );
  });

  test(
    'standalone sheet follows pan and zoom without filling the workspace',
    () async {
      expect(
        await pixel(
          x: 10,
          y: 150,
          scale: .5,
          translation: const ui.Offset(100, 100),
        ),
        [227, 231, 235, 255],
      );
      expectMetal(
        await pixel(
          x: 205,
          y: 203,
          scale: .5,
          translation: const ui.Offset(100, 100),
        ),
      );
    },
  );

  test('legacy canvas chrome retains its original background', () async {
    expect(await pixel(x: 205, y: 203, chrome: true), [246, 248, 251, 255]);
  });

  for (final cabinet in [false, true]) {
    test(
      'wire crossing gap matches the ${cabinet ? 'cabinet' : 'standalone'} metal',
      () async {
        final nodes = [
          for (final id in ['a', 'b', 'c', 'd'])
            ComponentInstance(
              id: ComponentId(id),
              modelType: 'Node',
              terminals: [
                Terminal(
                  id: TerminalId('t$id'),
                  name: id,
                  role: TerminalRole.generic,
                ),
              ],
            ),
        ];
        final crossed = CircuitState(
          circuitId: CircuitId('crossed-metal'),
          revision: 0,
          mode: ElectricalMode.dc,
          components: nodes,
          connections: [
            Connection(
              id: ConnectionId('h'),
              fromTerminalId: TerminalId('ta'),
              toTerminalId: TerminalId('tb'),
            ),
            Connection(
              id: ConnectionId('v'),
              fromTerminalId: TerminalId('tc'),
              toTerminalId: TerminalId('td'),
            ),
          ],
        );
        final bare = CircuitState(
          circuitId: crossed.circuitId,
          revision: 0,
          mode: ElectricalMode.dc,
          components: nodes,
        );
        final layout = CircuitVisualLayout(
          elementPositions: const {
            'a': ui.Offset(48, 120),
            'b': ui.Offset(300, 120),
            'c': ui.Offset(174, 20),
            'd': ui.Offset(174, 220),
          },
          cabinetLayout: CabinetLayout(
            const [],
            envelope: cabinet
                ? CabinetEnvelope(widthMm: 500, heightMm: 400, depthMm: 180)
                : null,
          ),
        );
        final crossing = const WireSemanticsAnalyzer()
            .analyze(circuit: crossed, layout: layout)
            .nonJunctionCrossings
            .single
            .point;
        final background = await pixel(
          x: crossing.dx.round(),
          y: crossing.dy.round(),
          paintedCircuit: bare,
          paintedLayout: layout,
        );
        final gap = await pixel(
          x: crossing.dx.round(),
          y: crossing.dy.round(),
          paintedCircuit: crossed,
          paintedLayout: layout,
        );
        for (var i = 0; i < 3; i++) {
          expect(
            gap[i],
            closeTo(background[i], 3),
            reason:
                'Crossing must not leave a white or workspace-coloured disk',
          );
        }
      },
    );
  }
}
