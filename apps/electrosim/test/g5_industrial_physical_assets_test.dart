import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

// Geometry is exported from the same public contract used by the wire canvas.
const industrialModels = <String, (String, int)>{
  'breaker_ac1': ('breaker1', 2),
  'push_button_no': ('button-no', 2),
  'push_button_nc': ('button-nc', 2),
  'contactor_ac1': ('contactor1', 4),
  'contactor_3p': ('contactor3', 8),
  'breaker_3p': ('breaker3', 6),
  'thermal_overload_3p': ('overload', 6),
  'motor_3p_6t': ('motor3', 6),
  'isolator_3p': ('isolator3', 6),
  'isolator_4p': ('isolator4', 8),
  'breaker_4p': ('breaker4', 8),
  'lamp': ('lamp', 2),
  'fuse_dc': ('fuse-holder', 2),
  'contactor_aux_no': ('auxiliary-no', 2),
  'contactor_aux_nc': ('auxiliary-nc', 2),
  'relay_coil': ('coil', 2),
  'terminal_block_5': ('terminal5', 10),
  'motor_dc': ('motor-dc', 2),
  'fan_dc': ('fan', 2),
  'buzzer': ('buzzer', 2),
};

void main() {
  testWidgets('physical industrial screw drives coincide with Canvas ports', (
    tester,
  ) async {
    final manifest = <String, Object>{};
    for (final entry in industrialModels.entries) {
      final size = F18ReferenceComponentMetrics.boardSizeFor(entry.key);
      final ports = List.generate(
        entry.value.$2,
        (i) =>
            size.center(Offset.zero) +
            TerminalVisualProfile.terminalOffset(
              modelType: entry.key,
              size: size,
              index: i,
              count: entry.value.$2,
            ),
      );
      manifest[entry.value.$1] = {
        'type': entry.key,
        'size': [size.width, size.height],
        'ports': ports.map((p) => [p.dx, p.dy]).toList(),
      };
    }
    Directory('build').createSync(recursive: true);
    File(
      'build/g5-industrial-geometry.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
    expect(
      jsonDecode(File('assets/g5_industrial/geometry.json').readAsStringSync()),
      manifest,
      reason:
          'Baked housing coordinates must still match the current Canvas contract',
    );
    for (final alias in F18PhysicalPlateAssets.models.entries) {
      final canonical = manifest[alias.value]! as Map<String, Object>;
      final size = F18ReferenceComponentMetrics.boardSizeFor(alias.key);
      expect([size.width, size.height], canonical['size'], reason: alias.key);
      final ports = canonical['ports']! as List<List<double>>;
      for (var i = 0; i < ports.length; i++) {
        final actual =
            size.center(Offset.zero) +
            TerminalVisualProfile.terminalOffset(
              modelType: alias.key,
              size: size,
              index: i,
              count: ports.length,
            );
        expect(
          actual.dx,
          closeTo(ports[i][0], .001),
          reason: '${alias.key} port $i x',
        );
        expect(
          actual.dy,
          closeTo(ports[i][1], .001),
          reason: '${alias.key} port $i y',
        );
      }
    }
    for (final entry in industrialModels.entries) {
      final size = F18ReferenceComponentMetrics.boardSizeFor(entry.key);
      for (final view in ['front', 'palette']) {
        if (entry.key.startsWith('breaker') ||
            entry.key.startsWith('isolator') ||
            entry.key.startsWith('push_button') ||
            entry.key == 'fan_dc') {
          for (final pose in [
            '',
            if (entry.key.startsWith('breaker') ||
                entry.key.startsWith('isolator')) ...[
              '-on',
              '-trip',
            ],
          ]) {
            expect(
              File(
                'assets/g5_industrial/${entry.value.$1}-controls$pose-$view.png',
              ).existsSync(),
              isTrue,
              reason:
                  'Controls must retain physically rendered operating poses',
            );
          }
        }
        final file = File('assets/g5_industrial/${entry.value.$1}-$view.png');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Missing physical housing: ${file.path}',
        );
        if (view != 'front') continue;
        await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(
            await file.readAsBytes(),
          );
          final image = (await codec.getNextFrame()).image;
          try {
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            for (var i = 0; i < entry.value.$2; i++) {
              final p =
                  size.center(Offset.zero) +
                  TerminalVisualProfile.terminalOffset(
                    modelType: entry.key,
                    size: size,
                    index: i,
                    count: entry.value.$2,
                  );
              final x = (p.dx / size.width * image.width).round();
              final y = (p.dy / size.height * image.height).round();
              final index = (y * image.width + x) * 4;
              expect(pixels.getUint8(index + 3), greaterThan(240));
              final luminance =
                  (pixels.getUint8(index) +
                      pixels.getUint8(index + 1) +
                      pixels.getUint8(index + 2)) /
                  3;
              expect(
                luminance,
                lessThan(170),
                reason: '${entry.key} port $i must land inside the screw drive',
              );
            }
          } finally {
            image.dispose();
            codec.dispose();
          }
        });
      }
    }
  });
}
