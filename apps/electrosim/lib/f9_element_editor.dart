import 'package:electrosim_domain/electrosim_domain.dart';

enum F9ElementKind { component, source }

final class F9ElementDetails {
  const F9ElementDetails({
    required this.kind,
    required this.id,
    required this.modelType,
    required this.terminalLabels,
    required this.parameters,
    required this.stateLabel,
    this.primaryToggleLabel,
    this.primaryToggleValue,
  });

  final F9ElementKind kind;
  final String id;
  final String modelType;
  final List<String> terminalLabels;
  final Map<String, Object?> parameters;
  final String stateLabel;
  final String? primaryToggleLabel;
  final bool? primaryToggleValue;
}

abstract final class F9ElementEditor {
  static F9ElementDetails? describe(CircuitState circuit, String? elementId) {
    if (elementId == null) {
      return null;
    }
    for (final ComponentInstance component in circuit.components) {
      if (component.id.value != elementId) {
        continue;
      }
      final Object? closed = component.controlState['closed'];
      final Object? pressed = component.controlState['pressed'];
      final bool isPushButton =
          component.modelType == 'push_button_no' ||
          component.modelType == 'push_button_nc';
      final bool? primaryValue = isPushButton
          ? (pressed is bool ? pressed : null)
          : (closed is bool ? closed : null);
      return F9ElementDetails(
        kind: F9ElementKind.component,
        id: component.id.value,
        modelType: component.modelType,
        terminalLabels: component.terminals
            .map((Terminal item) => item.name)
            .toList(growable: false),
        parameters: component.parameters,
        stateLabel: component.condition != ComponentCondition.normal
            ? component.condition.name
            : isPushButton && pressed is bool
                ? (pressed ? 'appuyé' : 'relâché')
                : closed is bool
                    ? (closed ? 'fermé' : 'ouvert')
                    : component.condition.name,
        primaryToggleLabel: isPushButton
            ? (pressed is bool ? 'Appuyé' : null)
            : (closed is bool ? 'Fermé' : null),
        primaryToggleValue: primaryValue,
      );
    }
    for (final SourceInstance source in circuit.sources) {
      if (source.id.value != elementId) {
        continue;
      }
      return F9ElementDetails(
        kind: F9ElementKind.source,
        id: source.id.value,
        modelType: source.modelType,
        terminalLabels: source.terminals.map((Terminal item) => item.name).toList(growable: false),
        parameters: source.parameters,
        stateLabel: source.enabled ? 'active' : 'inactive',
        primaryToggleLabel: 'Activée',
        primaryToggleValue: source.enabled,
      );
    }
    return null;
  }

  static CircuitState togglePrimaryState(CircuitState circuit, String elementId) {
    var changed = false;
    final List<ComponentInstance> components = circuit.components.map((ComponentInstance component) {
      if (component.id.value != elementId) {
        return component;
      }
      final bool isPushButton =
          component.modelType == 'push_button_no' ||
          component.modelType == 'push_button_nc';
      if (isPushButton) {
        final Object? pressed = component.controlState['pressed'];
        if (pressed is! bool) {
          return component;
        }
        changed = true;
        return ComponentInstance(
          id: component.id,
          modelType: component.modelType,
          terminals: component.terminals,
          parameters: component.parameters,
          condition: component.condition,
          controlState: <String, Object?>{
            ...component.controlState,
            'pressed': !pressed,
          },
        );
      }
      final Object? closed = component.controlState['closed'];
      if (closed is! bool) {
        return component;
      }
      changed = true;
      return ComponentInstance(
        id: component.id,
        modelType: component.modelType,
        terminals: component.terminals,
        parameters: component.parameters,
        condition: component.condition,
        controlState: <String, Object?>{
          ...component.controlState,
          'closed': !closed,
        },
      );
    }).toList(growable: false);

    final List<SourceInstance> sources = circuit.sources.map((SourceInstance source) {
      if (source.id.value != elementId) {
        return source;
      }
      changed = true;
      return SourceInstance(
        id: source.id,
        modelType: source.modelType,
        terminals: source.terminals,
        parameters: source.parameters,
        enabled: !source.enabled,
      );
    }).toList(growable: false);

    if (!changed) {
      return circuit;
    }
    return _rebuild(circuit, components: components, sources: sources);
  }


  static CircuitState replaceComponent(
    CircuitState circuit,
    String elementId, {
    required String modelType,
    Map<String, Object?> parameters = const <String, Object?>{},
    Map<String, Object?> controlState = const <String, Object?>{},
    List<Terminal>? replacementTerminals,
  }) {
    var changed = false;
    final List<ComponentInstance> components = circuit.components.map((ComponentInstance component) {
      if (component.id.value != elementId) {
        return component;
      }
      changed = true;
      return ComponentInstance(
        id: component.id,
        modelType: modelType,
        terminals: replacementTerminals ?? component.terminals,
        parameters: parameters,
        condition: ComponentCondition.normal,
        controlState: controlState,
      );
    }).toList(growable: false);
    if (!changed) {
      return circuit;
    }
    return _rebuild(circuit, components: components);
  }

  static CircuitState deleteElement(CircuitState circuit, String elementId) {
    final Set<TerminalId> removedTerminals = <TerminalId>{};
    var found = false;

    final List<ComponentInstance> components = <ComponentInstance>[];
    for (final ComponentInstance component in circuit.components) {
      if (component.id.value == elementId) {
        found = true;
        removedTerminals.addAll(component.terminals.map((Terminal item) => item.id));
      } else {
        components.add(component);
      }
    }

    final List<SourceInstance> sources = <SourceInstance>[];
    for (final SourceInstance source in circuit.sources) {
      if (source.id.value == elementId) {
        found = true;
        removedTerminals.addAll(source.terminals.map((Terminal item) => item.id));
      } else {
        sources.add(source);
      }
    }

    if (!found) {
      return circuit;
    }

    final List<Connection> connections = circuit.connections
        .where(
          (Connection connection) =>
              !removedTerminals.contains(connection.fromTerminalId) &&
              !removedTerminals.contains(connection.toTerminalId),
        )
        .toList(growable: false);

    return _rebuild(
      circuit,
      components: components,
      sources: sources,
      connections: connections,
    );
  }

  static CircuitState _rebuild(
    CircuitState circuit, {
    List<ComponentInstance>? components,
    List<SourceInstance>? sources,
    List<Connection>? connections,
  }) => CircuitState(
    circuitId: circuit.circuitId,
    revision: circuit.revision + 1,
    mode: circuit.mode,
    components: components ?? circuit.components,
    connections: connections ?? circuit.connections,
    sources: sources ?? circuit.sources,
    settings: circuit.settings,
    metadata: circuit.metadata,
  );
}
