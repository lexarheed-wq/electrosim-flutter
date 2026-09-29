import 'dart:convert';
import 'dart:io';

import 'package:electrosim_scenarios/electrosim_scenarios.dart';

void main(List<String> args) {
  final QualifiedCatalog catalog = buildF16QualifiedCatalog();
  final Map<String, Object?> report = <String, Object?>{
    'phase': 'F16-R1',
    'status': catalog.allItemsSigned ? 'PASS' : 'FAIL',
    'catalogVersion': catalog.catalogVersion,
    'examples': <String, Object?>{
      'count': catalog.examples.length,
      'ids': catalog.examples.map((item) => item.id.value).toList(growable: false),
      'signed': catalog.examples
          .where((item) => item.validationStamp != null)
          .length,
    },
    'faultScenarios': <String, Object?>{
      'count': catalog.faultScenarios.length,
      'ids': catalog.faultScenarios
          .map((item) => item.id.value)
          .toList(growable: false),
      'signed': catalog.faultScenarios
          .where((item) => item.validationStamp != null)
          .length,
    },
    'legacyImported': false,
    'exampleFaultCoupling': false,
  };

  final String json = const JsonEncoder.withIndent('  ').convert(report);
  if (args.isEmpty) {
    stdout.writeln(json);
    return;
  }
  final File output = File(args.first);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync('$json\n');
}
