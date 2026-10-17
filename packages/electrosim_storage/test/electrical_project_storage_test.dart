import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_storage/electrosim_storage.dart';
import 'package:test/test.dart';

SavedCircuitDocument _legacy() {
  final DateTime date = DateTime.utc(2026, 10, 16);
  return SavedCircuitDocument(
    saveId: 'legacy-save', title: 'Old circuit', createdAtUtc: date,
    updatedAtUtc: date, engineVersion: 'g5',
    circuit: CircuitState(circuitId: CircuitId('legacy'), revision: 4, mode: ElectricalMode.dc),
    appState: const <String, Object?>{'workspace': 'schematic'},
  );
}

CircuitState _circuit(String id, ElectricalMode mode) => CircuitState(
  circuitId: CircuitId(id), revision: 0, mode: mode,
);

SavedElectricalProjectDocument _composite() {
  final DateTime date = DateTime.utc(2026, 10, 16);
  return SavedElectricalProjectDocument(
    saveId: 'composite', title: 'Motor starter', createdAtUtc: date,
    updatedAtUtc: date, engineVersion: 'g5',
    project: ElectricalProject(networks: <ElectricalNetwork>[
      ElectricalNetwork(id: 'control', circuit: _circuit('control', ElectricalMode.dc)),
      ElectricalNetwork(id: 'power', circuit: _circuit('power', ElectricalMode.ac3)),
    ]),
  );
}

void main() {
  test('composite envelope round trips without rewriting legacy schema', () {
    final saved = _composite();
    final restored = SavedElectricalProjectDocument.fromJsonString(saved.toJsonString());
    expect(restored.toJson(), equals(saved.toJson()));
    expect(SavedCircuitDocument.currentSchemaVersion, 2);
    expect(saved.toJson()['format'], SavedElectricalProjectDocument.formatName);
  });

  test('v0, v1, and v2 documents wrap through the historic decoder', () {
    for (final int version in <int>[0, 1, 2]) {
      final Map<String, Object?> json = _legacy().toJson();
      json['schemaVersion'] = version;
      if (version == 0) {
        json['name'] = json.remove('title');
        json.remove('appState');
      } else if (version == 1) {
        json.remove('appState');
      }
      final restored = SavedElectricalProjectDocument.fromJson(json);
      expect(restored.project.networks.single.circuit.circuitId.value, 'legacy');
      expect(restored.saveId, 'legacy-save');
    }
  });

  test('rejects future schema versions', () {
    final Map<String, Object?> json = _composite().toJson();
    json['schemaVersion'] = 99;
    expect(() => SavedElectricalProjectDocument.fromJson(json), throwsFormatException);
  });

  test('single-network export preserves legacy JSON and composite export refuses loss', () {
    final SavedCircuitDocument legacy = _legacy();
    final wrapped = SavedElectricalProjectDocument.wrapLegacy(legacy);
    expect(wrapped.toLegacyElectricalJson(), equals(legacy.toJson()));
    expect(() => _composite().toLegacyElectricalJson(), throwsFormatException);
  });
}
