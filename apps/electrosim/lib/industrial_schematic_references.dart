import 'package:electrosim_domain/electrosim_domain.dart';

/// A presentation-only registry. It never allocates electrical IDs, renumbers
/// terminals, or changes the authoritative CircuitState.
enum SchematicReferenceIssueKind {
  duplicateReference,
  missingLinkedCoil,
  unknownLinkedCoil,
  invalidLinkedCoil,
}

final class SchematicReferenceIssue {
  const SchematicReferenceIssue({
    required this.kind,
    required this.elementId,
    required this.details,
  });

  final SchematicReferenceIssueKind kind;
  final String elementId;
  final String details;
}

final class IndustrialSchematicReferences {
  IndustrialSchematicReferences._({
    required Map<String, String> labels,
    required Map<String, String> contactToCoil,
    required Map<String, List<String>> coilToContacts,
    required List<SchematicReferenceIssue> issues,
  }) : labels = Map<String, String>.unmodifiable(labels),
       contactToCoil = Map<String, String>.unmodifiable(contactToCoil),
       coilToContacts = Map<String, List<String>>.unmodifiable(
         coilToContacts.map(
           (key, contacts) =>
               MapEntry(key, List<String>.unmodifiable(contacts)),
         ),
       ),
       issues = List<SchematicReferenceIssue>.unmodifiable(issues);

  /// Label lookup is keyed by the stable *element ID*, not by a diagram
  /// position. References already entered by the user take precedence.
  final Map<String, String> labels;

  /// Contact element ID -> physical controlling coil/contact device ID.
  final Map<String, String> contactToCoil;

  /// Physical controlling device ID -> stable sorted contact element IDs.
  final Map<String, List<String>> coilToContacts;
  final List<SchematicReferenceIssue> issues;

  String labelOf(String elementId) => labels[elementId] ?? elementId;

  String? controllingLabelFor(String contactId) {
    final coilId = contactToCoil[contactId];
    return coilId == null ? null : labelOf(coilId);
  }

  List<String> contactsFor(String controllingId) =>
      coilToContacts[controllingId] ?? const <String>[];

  /// Symbol semantics describe the device at rest (not its current runtime
  /// state). The electrical state still comes exclusively from the solver.
  static bool normallyClosed(String modelType) {
    final type = modelType.toLowerCase();
    return type == 'push_button_nc' ||
        type == 'contactor_aux_nc' ||
        type == 'relay_contact_nc' ||
        type.endsWith('_contact_nc') ||
        type.endsWith('_button_nc');
  }

  static IndustrialSchematicReferences build(CircuitState circuit) {
    final components = [...circuit.components]
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    final sources = [...circuit.sources]
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    final labels = <String, String>{};
    final referenceOwners = <String, String>{};
    final issues = <SchematicReferenceIssue>[];

    void addLabel(String id, Map<String, Object?> parameters) {
      // P3 consumes explicit references without performing P4 auto-numbering.
      final explicit = parameters['industrialReference'];
      final value = explicit is String && explicit.trim().isNotEmpty
          ? explicit.trim()
          : id;
      labels[id] = value;
      final first = referenceOwners.putIfAbsent(value, () => id);
      if (first != id) {
        issues.add(
          SchematicReferenceIssue(
            kind: SchematicReferenceIssueKind.duplicateReference,
            elementId: id,
            details: 'Reference shared with ' + first + ': ' + value,
          ),
        );
      }
    }

    for (final source in sources) {
      addLabel(source.id.value, source.parameters);
    }
    for (final component in components) {
      addLabel(component.id.value, component.parameters);
    }

    final contacts = <String, String>{};
    final inverse = <String, List<String>>{};
    final byId = <String, ComponentInstance>{
      for (final item in components) item.id.value: item,
    };

    for (final item in components) {
      final type = item.modelType;
      final isAuxiliary =
          type.startsWith('contactor_aux_') ||
          type.startsWith('relay_contact_');
      if (!isAuxiliary) continue;

      final target = item.parameters['linkedContactorId'];
      if (target is! String || target.trim().isEmpty) {
        issues.add(
          SchematicReferenceIssue(
            kind: SchematicReferenceIssueKind.missingLinkedCoil,
            elementId: item.id.value,
            details: 'Auxiliary contact lacks linkedContactorId',
          ),
        );
        continue;
      }
      final controller = byId[target];
      if (controller == null) {
        issues.add(
          SchematicReferenceIssue(
            kind: SchematicReferenceIssueKind.unknownLinkedCoil,
            elementId: item.id.value,
            details: 'Unknown coil device: ' + target,
          ),
        );
        continue;
      }
      if ((!controller.modelType.startsWith('contactor_') &&
              controller.modelType != 'relay_coil') ||
          controller.modelType.startsWith('contactor_aux_')) {
        issues.add(
          SchematicReferenceIssue(
            kind: SchematicReferenceIssueKind.invalidLinkedCoil,
            elementId: item.id.value,
            details: 'Linked device is not a contactor: ' + target,
          ),
        );
        continue;
      }
      contacts[item.id.value] = target;
      inverse.putIfAbsent(target, () => <String>[]).add(item.id.value);
    }
    for (final elements in inverse.values) {
      elements.sort();
    }
    return IndustrialSchematicReferences._(
      labels: labels,
      contactToCoil: contacts,
      coilToContacts: inverse,
      issues: issues,
    );
  }
}
