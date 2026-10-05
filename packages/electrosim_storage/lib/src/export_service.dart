import 'dart:convert';
import 'dart:typed_data';

import 'storage_models.dart';

final class ExportService {
  const ExportService();

  String toCsv(SavedCircuitDocument document) {
    final List<List<Object?>> rows = <List<Object?>>[
      <Object?>['saveId', document.saveId],
      <Object?>['title', document.title],
      <Object?>['engineVersion', document.engineVersion],
      <Object?>['circuitId', document.circuit.circuitId.value],
      <Object?>['revision', document.circuit.revision],
      <Object?>['mode', document.circuit.mode.name],
      <Object?>['components', document.circuit.components.length],
      <Object?>['sources', document.circuit.sources.length],
      <Object?>['connections', document.circuit.connections.length],
    ];
    return rows
            .map((List<Object?> row) => row.map(_csvCell).join(','))
            .join('\n') +
        '\n';
  }

  Uint8List toPdf(SavedCircuitDocument document) {
    final List<String> lines = <String>[
      'ElectroSim - Saved circuit',
      'Title: ${document.title}',
      'Save ID: ${document.saveId}',
      'Circuit: ${document.circuit.circuitId.value}',
      'Revision: ${document.circuit.revision}',
      'Mode: ${document.circuit.mode.name}',
      'Engine: ${document.engineVersion}',
    ];
    return _simplePdf(lines);
  }

  static String _csvCell(Object? value) {
    final String text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  static Uint8List _simplePdf(List<String> lines) {
    String escape(String value) => value
        .replaceAll('\\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
    final StringBuffer stream = StringBuffer('BT\n/F1 12 Tf\n50 790 Td\n');
    for (var index = 0; index < lines.length; index += 1) {
      if (index > 0) stream.write('0 -18 Td\n');
      stream.write('(${escape(lines[index])}) Tj\n');
    }
    stream.write('ET\n');
    final List<String> objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
      '<< /Length ${utf8.encode(stream.toString()).length} >>\nstream\n${stream}endstream',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    ];
    final StringBuffer pdf = StringBuffer('%PDF-1.4\n');
    final List<int> offsets = <int>[0];
    for (var index = 0; index < objects.length; index += 1) {
      offsets.add(utf8.encode(pdf.toString()).length);
      pdf.write('${index + 1} 0 obj\n${objects[index]}\nendobj\n');
    }
    final int xrefOffset = utf8.encode(pdf.toString()).length;
    pdf.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final int offset in offsets.skip(1)) {
      pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    pdf.write(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n',
    );
    return Uint8List.fromList(utf8.encode(pdf.toString()));
  }
}
