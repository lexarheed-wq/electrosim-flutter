import 'circuit_state.dart';
import 'component.dart';

enum MotorThreePhaseCouplingKind { star, delta, incomplete, invalid }

final class MotorThreePhaseCouplingAssessment {
  const MotorThreePhaseCouplingAssessment({
    required this.kind,
    required this.message,
  });

  final MotorThreePhaseCouplingKind kind;
  final String message;

  bool get isValid =>
      kind == MotorThreePhaseCouplingKind.star ||
      kind == MotorThreePhaseCouplingKind.delta;
}

/// Validates the external links of a canonical six-terminal three-phase motor.
///
/// Terminal order is U1, V1, W1, U2, V2, W2. Only enabled ideal wires are
/// merged; the three windings remain electrical branches.
abstract final class MotorThreePhaseCouplingEvaluator {
  static MotorThreePhaseCouplingAssessment evaluate(
    CircuitState circuit,
    ComponentInstance motor,
  ) {
    if (motor.modelType != 'motor_3p_6t' || motor.terminals.length != 6) {
      return const MotorThreePhaseCouplingAssessment(
        kind: MotorThreePhaseCouplingKind.invalid,
        message:
            'Le contrat du moteur triphasé 6 bornes est invalide ou incomplet.',
      );
    }

    final _TerminalUnionFind wires = _TerminalUnionFind();
    for (final terminal in motor.terminals) {
      wires.add(terminal.id.value);
    }
    for (final connection in circuit.connections) {
      if (!connection.enabled) continue;
      final String a = connection.fromTerminalId.value;
      final String b = connection.toTerminalId.value;
      wires.add(a);
      wires.add(b);
      wires.union(a, b);
    }

    final List<String> roots = <String>[
      for (final terminal in motor.terminals) wires.find(terminal.id.value),
    ];
    final List<String> starts = roots.sublist(0, 3);
    final List<String> ends = roots.sublist(3, 6);

    final bool starOnEnds =
        ends.toSet().length == 1 &&
        starts.toSet().length == 3 &&
        !starts.contains(ends.first);
    final bool starOnStarts =
        starts.toSet().length == 1 &&
        ends.toSet().length == 3 &&
        !ends.contains(starts.first);
    if (starOnEnds || starOnStarts) {
      return const MotorThreePhaseCouplingAssessment(
        kind: MotorThreePhaseCouplingKind.star,
        message: 'Couplage étoile Y complet détecté.',
      );
    }

    final Map<String, List<int>> groups = <String, List<int>>{};
    for (var index = 0; index < roots.length; index++) {
      groups.putIfAbsent(roots[index], () => <int>[]).add(index);
    }
    final bool everyWindingRemainsDistinct =
        roots[0] != roots[3] &&
        roots[1] != roots[4] &&
        roots[2] != roots[5];
    final bool delta =
        groups.length == 3 &&
        everyWindingRemainsDistinct &&
        groups.values.every((List<int> indices) {
          if (indices.length != 2) return false;
          final int startCount = indices.where((int i) => i < 3).length;
          final int endCount = indices.where((int i) => i >= 3).length;
          return startCount == 1 && endCount == 1;
        });
    if (delta) {
      return const MotorThreePhaseCouplingAssessment(
        kind: MotorThreePhaseCouplingKind.delta,
        message: 'Couplage triangle Δ complet détecté.',
      );
    }

    if (groups.length > 4) {
      return const MotorThreePhaseCouplingAssessment(
        kind: MotorThreePhaseCouplingKind.incomplete,
        message:
            'Couplage moteur 3φ incomplet : les trois enroulements ne forment ni une étoile Y complète ni un triangle Δ complet.',
      );
    }
    return const MotorThreePhaseCouplingAssessment(
      kind: MotorThreePhaseCouplingKind.invalid,
      message:
          'Couplage moteur 3φ invalide : les liaisons U1/V1/W1/U2/V2/W2 ne correspondent ni à Y ni à Δ.',
    );
  }
}

final class _TerminalUnionFind {
  final Map<String, String> _parent = <String, String>{};

  void add(String value) => _parent.putIfAbsent(value, () => value);

  String find(String value) {
    add(value);
    final String parent = _parent[value]!;
    if (parent == value) return value;
    final String root = find(parent);
    _parent[value] = root;
    return root;
  }

  void union(String a, String b) {
    final String ra = find(a);
    final String rb = find(b);
    if (ra == rb) return;
    if (ra.compareTo(rb) <= 0) {
      _parent[rb] = ra;
    } else {
      _parent[ra] = rb;
    }
  }
}
