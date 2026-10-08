import 'dart:ui';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'an aligned thermal relay and panel adapters share the lower support',
    () {
      final viewport = ViewportController();
      addTearDown(viewport.dispose);
      final circuit = CircuitState(
        circuitId: CircuitId('supports'),
        revision: 0,
        mode: ElectricalMode.ac3,
        components: [
          for (final type in [
            'breaker_3p',
            'thermal_overload_3p',
            'push_button_no',
            'push_button_nc',
          ])
            ComponentInstance(
              id: ComponentId(type),
              modelType: type,
              terminals: [],
            ),
        ],
      );
      final layout = CircuitVisualLayout(
        elementPositions: const {
          'breaker_3p': Offset(140, 165),
          'thermal_overload_3p': Offset(455, 455),
          'push_button_no': Offset(135, 455),
          'push_button_nc': Offset(255, 455),
        },
      );
      final painter = CircuitScenePainter(
        circuit: circuit,
        layout: layout,
        viewport: viewport,
        paintElementChrome: false,
      );
      expect(painter.dinSupportsAtBuild, hasLength(2));
      final lower = painter.dinSupportsAtBuild.singleWhere(
        (r) => r.center.dy == 455,
      );
      expect(lower.left, lessThan(100));
      expect(lower.right, greaterThan(500));
    },
  );
  test('aligned housings share a rail without moving their bounds', () {
    const mounts = [
      Rect.fromLTWH(40, 20, 60, 160),
      Rect.fromLTWH(160, 0, 100, 200),
    ];
    final rails = layoutDinRails(mounts);
    expect(rails, hasLength(1));
    expect(rails.single.center.dy, 100);
    expect(rails.single.left, lessThan(40));
    expect(rails.single.right, greaterThan(260));
    expect(mounts.first.left, 40);
  });
  test('different rows and distant devices retain separate supports', () {
    final rails = layoutDinRails(const [
      Rect.fromLTWH(0, 0, 60, 160),
      Rect.fromLTWH(0, 250, 60, 160),
      Rect.fromLTWH(1000, 0, 60, 160),
    ]);
    expect(rails, hasLength(3));
  });
}
