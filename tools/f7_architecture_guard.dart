import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final Directory root = Directory.current;
  final Map<String, Set<String>> packages = <String, Set<String>>{
    'electrosim_pv': <String>{
      'electrosim_domain',
      'electrosim_topology',
      'electrosim_pv',
    },
    'electrosim_energy': <String>{
      'electrosim_domain',
      'electrosim_pv',
      'electrosim_energy',
    },
  };
  final List<String> errors = <String>[];
  var scanned = 0;
  for (final MapEntry<String, Set<String>> entry in packages.entries) {
    final Directory package = Directory('${root.path}/packages/${entry.key}');
    if (!package.existsSync()) {
      errors.add('missing-package:${entry.key}');
      continue;
    }
    await for (final FileSystemEntity entity in package.list(
      recursive: true,
      followLinks: false,
    )) {
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
        if (uri.startsWith('package:electrosim_')) {
          final String dependency = uri.substring('package:'.length).split('/').first;
          if (!entry.value.contains(dependency)) {
            errors.add('forbidden-project-dependency:${entity.path}:$uri');
          }
        }
      }
    }
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'phase': 'F7',
      'status': errors.isEmpty ? 'PASS' : 'FAIL',
      'dartFilesScanned': scanned,
      'errors': errors,
    }),
  );
  if (errors.isNotEmpty) {
    exitCode = 1;
  }
}
