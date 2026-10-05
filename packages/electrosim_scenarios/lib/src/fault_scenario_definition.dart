import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';

final class FaultScenarioId {
  FaultScenarioId(String raw) : value = _validate(raw);
  final String value;

  static String _validate(String raw) {
    final String value = raw.trim();
    if (value.isEmpty ||
        !RegExp(r'^[A-Z0-9][A-Z0-9_-]{2,63}$').hasMatch(value)) {
      throw ArgumentError.value(raw, 'raw', 'Invalid FaultScenarioId.');
    }
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is FaultScenarioId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

enum FaultDifficulty { basic, intermediate, advanced }

enum RootCauseKind { missingConnection, componentOpen }

final class RootCause {
  const RootCause({
    required this.kind,
    required this.targetId,
    required this.description,
  });

  final RootCauseKind kind;
  final String targetId;
  final String description;

  Map<String, Object?> toPrivateJson() => <String, Object?>{
    'kind': kind.name,
    'targetId': targetId,
    'description': description,
  };
}

final class ExpectedBranchMeasurement {
  const ExpectedBranchMeasurement({
    required this.branchId,
    required this.currentA,
    this.toleranceA = 1e-9,
  });

  final String branchId;
  final double currentA;
  final double toleranceA;

  Map<String, Object?> toPrivateJson() => <String, Object?>{
    'branchId': branchId,
    'currentA': currentA,
    'toleranceA': toleranceA,
  };
}

enum RepairActionKind { addConnection, normalizeComponent }

final class RepairAction {
  const RepairAction.addConnection({
    required this.id,
    required Connection connection,
  }) : kind = RepairActionKind.addConnection,
       connection = connection,
       componentId = null;

  const RepairAction.normalizeComponent({
    required this.id,
    required ComponentId componentId,
  }) : kind = RepairActionKind.normalizeComponent,
       connection = null,
       componentId = componentId;

  final String id;
  final RepairActionKind kind;
  final Connection? connection;
  final ComponentId? componentId;

  CircuitState apply(CircuitState circuit) {
    switch (kind) {
      case RepairActionKind.addConnection:
        final Connection value = connection!;
        if (circuit.connections.any((Connection item) => item.id == value.id)) {
          throw StateError(
            'Repair $id would duplicate connection ${value.id.value}.',
          );
        }
        return _rebuild(
          circuit,
          connections: <Connection>[...circuit.connections, value],
        );
      case RepairActionKind.normalizeComponent:
        final ComponentId target = componentId!;
        var found = false;
        final List<ComponentInstance> components = circuit.components
            .map((ComponentInstance item) {
              if (item.id != target) return item;
              found = true;
              return ComponentInstance(
                id: item.id,
                modelType: item.modelType,
                terminals: item.terminals,
                parameters: item.parameters,
                condition: ComponentCondition.normal,
                controlState: item.controlState,
              );
            })
            .toList(growable: false);
        if (!found)
          throw StateError(
            'Repair $id references unknown component ${target.value}.',
          );
        return _rebuild(circuit, components: components);
    }
  }

  Map<String, Object?> toPrivateJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    if (connection != null) 'connection': connection!.toJson(),
    if (componentId != null) 'componentId': componentId!.value,
  };

  static CircuitState _rebuild(
    CircuitState circuit, {
    List<ComponentInstance>? components,
    List<Connection>? connections,
  }) => CircuitState(
    circuitId: circuit.circuitId,
    revision: circuit.revision + 1,
    mode: circuit.mode,
    components: components ?? circuit.components,
    connections: connections ?? circuit.connections,
    sources: circuit.sources,
    settings: circuit.settings,
    metadata: circuit.metadata,
  );
}

final class TeacherTruth {
  TeacherTruth({
    required List<RootCause> rootCauses,
    required List<String> expectedSymptoms,
    required List<ExpectedBranchMeasurement> expectedMeasurements,
    required List<RepairAction> acceptableRepairs,
  }) : rootCauses = List<RootCause>.unmodifiable(rootCauses),
       expectedSymptoms = List<String>.unmodifiable(expectedSymptoms),
       expectedMeasurements = List<ExpectedBranchMeasurement>.unmodifiable(
         expectedMeasurements,
       ),
       acceptableRepairs = List<RepairAction>.unmodifiable(acceptableRepairs) {
    if (this.rootCauses.isEmpty)
      throw ArgumentError('teacherTruth requires at least one root cause.');
    if (this.expectedSymptoms.isEmpty)
      throw ArgumentError('teacherTruth requires expected symptoms.');
    if (this.acceptableRepairs.isEmpty)
      throw ArgumentError(
        'teacherTruth requires at least one acceptable repair.',
      );
  }

  final List<RootCause> rootCauses;
  final List<String> expectedSymptoms;
  final List<ExpectedBranchMeasurement> expectedMeasurements;
  final List<RepairAction> acceptableRepairs;

  Map<String, Object?> toPrivateJson() => <String, Object?>{
    'rootCauses': rootCauses
        .map((RootCause item) => item.toPrivateJson())
        .toList(growable: false),
    'expectedSymptoms': expectedSymptoms,
    'expectedMeasurements': expectedMeasurements
        .map((ExpectedBranchMeasurement item) => item.toPrivateJson())
        .toList(growable: false),
    'acceptableRepairs': acceptableRepairs
        .map((RepairAction item) => item.toPrivateJson())
        .toList(growable: false),
  };
}

final class FaultScenarioValidationStamp {
  const FaultScenarioValidationStamp({
    required this.validatorVersion,
    required this.circuitSchemaVersion,
    required this.contentDigestFnv1a64,
  });

  final String validatorVersion;
  final int circuitSchemaVersion;
  final String contentDigestFnv1a64;
}

final class FaultScenarioDefinition {
  FaultScenarioDefinition({
    required this.id,
    required String title,
    required String studentBrief,
    required this.faultyCircuit,
    required this.teacherTruth,
    required this.difficulty,
    required this.estimatedDurationMinutes,
    required String version,
    this.validationStamp,
  }) : title = _clean(title, 'title'),
       studentBrief = _clean(studentBrief, 'studentBrief'),
       version = _clean(version, 'version') {
    if (estimatedDurationMinutes <= 0) {
      throw ArgumentError.value(
        estimatedDurationMinutes,
        'estimatedDurationMinutes',
      );
    }
  }

  final FaultScenarioId id;
  final String title;
  final String studentBrief;
  final CircuitState faultyCircuit;
  final TeacherTruth teacherTruth;
  final FaultDifficulty difficulty;
  final int estimatedDurationMinutes;
  final String version;
  final FaultScenarioValidationStamp? validationStamp;

  FaultScenarioDefinition withValidationStamp(
    FaultScenarioValidationStamp stamp,
  ) => FaultScenarioDefinition(
    id: id,
    title: title,
    studentBrief: studentBrief,
    faultyCircuit: faultyCircuit,
    teacherTruth: teacherTruth,
    difficulty: difficulty,
    estimatedDurationMinutes: estimatedDurationMinutes,
    version: version,
    validationStamp: stamp,
  );

  Map<String, Object?> studentPayload() => <String, Object?>{
    'id': id.value,
    'title': title,
    'studentBrief': studentBrief,
    'electricalMode': faultyCircuit.mode.name,
    'faultyCircuitState': faultyCircuit.toJson(),
    'difficulty': difficulty.name,
    'estimatedDurationMinutes': estimatedDurationMinutes,
    'version': version,
  };

  String canonicalPrivatePayload() => jsonEncode(<String, Object?>{
    ...studentPayload(),
    'teacherTruth': teacherTruth.toPrivateJson(),
  });

  static String _clean(String value, String field) {
    final String clean = value.trim();
    if (clean.isEmpty)
      throw ArgumentError.value(value, field, '$field must not be empty.');
    return clean;
  }
}
