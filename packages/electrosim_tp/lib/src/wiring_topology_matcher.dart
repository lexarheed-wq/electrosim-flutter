import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';

/// Checks physical terminal connectivity independent of generated element,
/// terminal and wire IDs. Failing closed is preferable to false full marks.
abstract final class WiringTopologyMatcher {
  static bool equivalent(CircuitState reference, CircuitState submitted) {
    if (reference.mode != submitted.mode ||
        reference.components.length != submitted.components.length ||
        reference.sources.length != submitted.sources.length ||
        reference.connections.length != submitted.connections.length) {
      return false;
    }
    final _Graph left = _Graph(reference);
    final _Graph right = _Graph(submitted);
    if (left.nodes.length != right.nodes.length) return false;
    final int n = left.nodes.length;
    final List<List<int>> candidates = <List<int>>[
      for (var i = 0; i < n; i++)
        <int>[
          for (var j = 0; j < n; j++)
            if (left.nodes[i] == right.nodes[j] &&
                left.degreeSignature(i) == right.degreeSignature(j))
              j,
        ],
    ];
    if (candidates.any((list) => list.isEmpty)) return false;
    final order = <int>[for (var i = 0; i < n; i++) i]
      ..sort((a, b) => candidates[a].length.compareTo(candidates[b].length));
    final mapping = <int, int>{};
    final occupied = <int>{};
    var visits = 0;

    bool search(int depth) {
      // Avoid pathological factorial searches on highly symmetric models.
      // An inconclusive comparison cannot legitimately earn full marks.
      if (++visits > 50000) return false;
      if (depth == n) {
        return _sameMultiset(
          left.mappedEdges(mapping),
          right.mappedEdges(<int, int>{
            for (var i = 0; i < n; i++) i: i,
          }),
        );
      }
      final i = order[depth];
      for (final j in candidates[i]) {
        if (occupied.contains(j)) continue;
        mapping[i] = j;
        occupied.add(j);
        if (_partialConsistent(left, right, mapping) && search(depth + 1)) {
          return true;
        }
        mapping.remove(i);
        occupied.remove(j);
      }
      return false;
    }

    return search(0);
  }

  static bool _partialConsistent(
    _Graph left,
    _Graph right,
    Map<int, int> mapping,
  ) {
    final leftEdges = left.mappedEdges(mapping);
    final rightEdges = right.edgesWithin(mapping.values.toSet());
    return _sameMultiset(leftEdges, rightEdges);
  }

  static bool _sameMultiset(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    a.sort();
    b.sort();
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final class _Graph {
  _Graph(CircuitState circuit) {
    void register(
      String id,
      String kind,
      String modelType,
      List<Terminal> terminals,
      Map<String, Object?> parameters,
      Object? state,
    ) {
      final node = jsonEncode(<Object?>[
        kind,
        modelType,
        _stable(parameters),
        _stable(state),
        <Object?>[
          for (final terminal in terminals)
            <String>[terminal.name, terminal.role.name, terminal.phase.name],
        ],
      ]);
      final owner = nodes.length;
      nodes.add(node);
      for (var i = 0; i < terminals.length; i++) {
        ports[terminals[i].id] = (owner, i);
      }
    }

    for (final source in circuit.sources) {
      register(
        source.id.value,
        'source',
        source.modelType,
        source.terminals,
        source.parameters,
        source.enabled,
      );
    }
    for (final component in circuit.components) {
      register(
        component.id.value,
        'component',
        component.modelType,
        component.terminals,
        component.parameters,
        <Object?>[component.condition.name, _stable(component.controlState)],
      );
    }
    for (final connection in circuit.connections) {
      final first = ports[connection.fromTerminalId]!;
      final second = ports[connection.toTerminalId]!;
      edges.add((
        first.$1,
        first.$2,
        second.$1,
        second.$2,
        connection.conductorType.name,
        connection.phase.name,
        connection.enabled,
      ));
    }
  }

  final List<String> nodes = <String>[];
  final Map<TerminalId, (int, int)> ports = <TerminalId, (int, int)>{};
  final List<(int, int, int, int, String, String, bool)> edges = [];

  String degreeSignature(int owner) {
    final counts = <String>[];
    for (final e in edges) {
      if (e.$1 == owner) counts.add('${e.$2}:${e.$5}:${e.$6}:${e.$7}');
      if (e.$3 == owner) counts.add('${e.$4}:${e.$5}:${e.$6}:${e.$7}');
    }
    counts.sort();
    return counts.join('|');
  }

  List<String> mappedEdges(Map<int, int> mapping) => <String>[
    for (final edge in edges)
      if (mapping.containsKey(edge.$1) && mapping.containsKey(edge.$3))
        _edgeKey(
          mapping[edge.$1]!,
          edge.$2,
          mapping[edge.$3]!,
          edge.$4,
          edge.$5,
          edge.$6,
          edge.$7,
        ),
  ];

  List<String> edgesWithin(Set<int> chosen) => <String>[
    for (final edge in edges)
      if (chosen.contains(edge.$1) && chosen.contains(edge.$3))
        _edgeKey(
          edge.$1,
          edge.$2,
          edge.$3,
          edge.$4,
          edge.$5,
          edge.$6,
          edge.$7,
        ),
  ];

  static String _edgeKey(
    int firstOwner,
    int firstPin,
    int secondOwner,
    int secondPin,
    String conductor,
    String phase,
    bool enabled,
  ) {
    final a = '${firstOwner.toString().padLeft(7, '0')}:$firstPin';
    final b = '${secondOwner.toString().padLeft(7, '0')}:$secondPin';
    return jsonEncode(<Object?>[
      if (a.compareTo(b) <= 0) ...<String>[a, b] else ...<String>[b, a],
      conductor,
      phase,
      enabled,
    ]);
  }
}

/// Canonicalize map order, since parameter maps can be serialized in different
/// insertion orders across browser and desktop application processes.
Object? _stable(Object? object) {
  if (object is Map) {
    final keys = object.keys.map((e) => e.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _stable(object[key]),
    };
  }
  if (object is List) return <Object?>[for (final value in object) _stable(value)];
  return object;
}
