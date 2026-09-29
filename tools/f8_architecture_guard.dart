import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final Directory root = Directory.current;
  final Directory canvas = Directory('${root.path}/packages/electrosim_canvas/lib');
  final List<String> errors = <String>[];
  var scanned = 0;
  if (!canvas.existsSync()) {
    errors.add('missing-package:electrosim_canvas');
  } else {
    await for (final FileSystemEntity entity in canvas.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      scanned++;
      final String source = await entity.readAsString();
      final RegExp directive = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
      for (final RegExpMatch match in directive.allMatches(source)) {
        final String uri = match.group(1)!;
        if (uri.startsWith('package:electrosim_') &&
            !uri.startsWith('package:electrosim_domain') &&
            !uri.startsWith('package:electrosim_canvas')) {
          errors.add('forbidden-project-dependency:${entity.path}:$uri');
        }
      }
      final String lowered = source.toLowerCase();
      for (final String token in <String>[
        'solverengine',
        'solverdc',
        'solverac',
        'solverpv',
        'measurementengine',
        'energyengine',
        'topologyengine',
        'teachertruth',
        'faultengine',
        'faultinjection',
      ]) {
        if (lowered.contains(token)) {
          errors.add('forbidden-cross-layer-token:${entity.path}:$token');
        }
      }
    }
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'phase': 'F8',
      'status': errors.isEmpty ? 'PASS' : 'FAIL',
      'dartFilesScanned': scanned,
      'errors': errors,
    }),
  );
  if (errors.isNotEmpty) {
    exitCode = 1;
  }
}
