import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final Directory root = Directory.current;
  final Directory domain = Directory('${root.path}/packages/electrosim_domain');
  final List<String> errors = <String>[];
  var scanned = 0;

  if (!domain.existsSync()) {
    stderr.writeln('electrosim_domain not found from ${root.path}');
    exitCode = 2;
    return;
  }

  await for (final FileSystemEntity entity in domain.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    scanned++;
    final String source = await entity.readAsString();
    final RegExp directive = RegExp(
      r'''(?:import|export)\s+['"]([^'"]+)['"]''',
    );
    for (final RegExpMatch match in directive.allMatches(source)) {
      final String uri = match.group(1)!;
      if (uri.startsWith('package:flutter') || uri == 'dart:ui') {
        errors.add('ui-dependency:${entity.path}:$uri');
      }
      if (uri.startsWith('package:electrosim_') &&
          !uri.startsWith('package:electrosim_domain')) {
        errors.add('upward-project-dependency:${entity.path}:$uri');
      }
    }
  }

  final String pubspec = await File(
    '${domain.path}/pubspec.yaml',
  ).readAsString();
  if (RegExp(r'^\s*flutter\s*:', multiLine: true).hasMatch(pubspec)) {
    errors.add('flutter-dependency-in-domain-pubspec');
  }

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'phase': 'F1',
      'status': errors.isEmpty ? 'PASS' : 'FAIL',
      'dartFilesScanned': scanned,
      'errors': errors,
    }),
  );
  if (errors.isNotEmpty) {
    exitCode = 1;
  }
}
