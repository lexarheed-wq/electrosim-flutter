import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final Directory root = Directory.current;
  final Directory package = Directory('${root.path}/packages/electrosim_solver_ac');
  final List<String> errors = <String>[];
  var scanned = 0;
  if (!package.existsSync()) {
    stderr.writeln('electrosim_solver_ac not found from ${root.path}');
    exitCode = 2;
    return;
  }
  await for (final FileSystemEntity entity in package.list(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    scanned++;
    final String source = await entity.readAsString();
    final RegExp directive = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
    for (final RegExpMatch match in directive.allMatches(source)) {
      final String uri = match.group(1)!;
      if (uri.startsWith('package:flutter') || uri == 'dart:ui') {
        errors.add('ui-dependency:${entity.path}:$uri');
      }
      if (uri.startsWith('package:electrosim_') &&
          !uri.startsWith('package:electrosim_domain') &&
          !uri.startsWith('package:electrosim_topology') &&
          !uri.startsWith('package:electrosim_solver_ac')) {
        errors.add('forbidden-project-dependency:${entity.path}:$uri');
      }
    }
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'phase': 'F6',
    'status': errors.isEmpty ? 'PASS' : 'FAIL',
    'dartFilesScanned': scanned,
    'errors': errors,
  }));
  if (errors.isNotEmpty) {
    exitCode = 1;
  }
}
