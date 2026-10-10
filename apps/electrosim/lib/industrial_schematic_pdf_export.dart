import 'dart:typed_data';

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'industrial_schematic_svg_export.dart';

/// A3 landscape vector PDF rendered from exactly the same SVG and electrical
/// graph as P3's standalone SVG. No PNG screenshot or alternate connectivity.
abstract final class IndustrialSchematicPdfExport {
  static Future<Uint8List> render(
    CircuitState circuit,
    CircuitVisualLayout authoredPlate,
  ) async {
    final svg = IndustrialSchematicSvgExport.render(circuit, authoredPlate);
    final doc = pw.Document(
      title: 'ElectroSim - schema electrique',
      author: 'ElectroSim',
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a3.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: <pw.Widget>[
            pw.Text(
              'ElectroSim - Schema electrique multifilaire',
              style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 16),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Circuit: ${circuit.circuitId.value} | Rev: ${circuit.revision}'
              ' | Mode: ${circuit.mode.name}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 12),
            pw.Expanded(
              child: pw.SvgImage(svg: svg, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Symboles de famille indicatifs - conformite IEC non certifiee',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }
}
