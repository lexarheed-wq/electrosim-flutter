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
}
