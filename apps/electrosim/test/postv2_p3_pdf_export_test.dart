import 'dart:convert';

import 'package:electrosim/industrial_schematic_pdf_export.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  test(
    'P3 PDF is a real document generated from the unmodified CC circuit',
    () async {
      final circuit = buildRegressionFixtureCircuit();
      final original = circuit.toJsonString();
      final plate = CircuitVisualLayout(
        elementPositions: const {
          'source-24v': Offset(120, 200),
          'switch-1': Offset(340, 200),
          'lamp-1': Offset(560, 200),
        },
      );
      final pdf = await IndustrialSchematicPdfExport.render(circuit, plate);
      expect(
        ascii.decode(pdf.sublist(0, 8), allowInvalid: true),
        startsWith('%PDF-'),
      );
      expect(pdf.length, greaterThan(1200));
      expect(circuit.toJsonString(), original);
      expect(plate.terminalAnchorOffsets, isEmpty);
    },
  );
}
