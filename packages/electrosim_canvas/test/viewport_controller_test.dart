import 'dart:ui' show Size;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('world/screen transforms are inverse and zoom stays centered', () {
    final ViewportController controller = ViewportController(
      scale: 1.5,
      translation: const Offset(40, 25),
    );
    const Offset world = Offset(120, 80);
    final Offset screen = controller.worldToScreen(world);
    expect(controller.screenToWorld(screen), world);

    const Offset focal = Offset(300, 200);
    final Offset before = controller.screenToWorld(focal);
    controller.zoomAt(focal, 1.8);
    final Offset after = controller.screenToWorld(focal);
    expect((before - after).distance, lessThan(1e-9));
  });

  test('pan and reset affect only viewport coordinates', () {
    final ViewportController controller = ViewportController();
    controller.panBy(const Offset(20, -15));
    expect(controller.translation, const Offset(20, -15));
    controller.reset(scale: 2, translation: const Offset(5, 7));
    expect(controller.scale, 2);
    expect(controller.translation, const Offset(5, 7));
  });
  test('resize preserves world center without changing scale', () {
    final c = ViewportController(scale: 1.5, translation: const Offset(70, 20));
    addTearDown(c.dispose);
    final before = c.screenToWorld(const Offset(500, 350));
    var notifications = 0;
    c.addListener(() => notifications++);
    c.preserveWorldCenterOnResize(const Size(1000, 700), const Size(700, 700));
    expect(
      (c.screenToWorld(const Offset(350, 350)) - before).distance,
      lessThan(1e-6),
    );
    expect(c.scale, 1.5);
    expect(notifications, 1);
    c.preserveWorldCenterOnResize(const Size(700, 700), const Size(700, 700));
    c.preserveWorldCenterOnResize(Size.zero, const Size(800, 700));
    c.preserveWorldCenterOnResize(
      const Size(700, 700),
      const Size(double.infinity, 700),
    );
    expect(notifications, 1);
  });
}
