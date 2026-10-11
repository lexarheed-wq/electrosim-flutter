import 'ideal_gas.dart';
import 'isothermal_network.dart';

/// Serializable physics request; executable on both dart2js Web Workers and
/// persistent native isolates by the SAME canonical IsothermalAirNetwork.
final class R6NetworkJob {
  R6NetworkJob({
    required this.projectRevision,
    required this.requestId,
    required this.engineVersion,
    required this.network,
    required this.before,
    required this.durationS,
    required this.maxStepS,
  }) {
    if (projectRevision < 0 ||
        requestId < 1 ||
        engineVersion.isEmpty ||
        !durationS.isFinite ||
        durationS < 0 ||
        !maxStepS.isFinite ||
        maxStepS <= 0) {
      throw ArgumentError('Invalid R6/N worker request');
    }
  }

  final int projectRevision;
  final int requestId;
  final String engineVersion;
  final IsothermalAirNetwork network;
  final IsothermalAirSnapshot before;
  final double durationS;
  final double maxStepS;

  Map<String, Object?> toJson() => <String, Object?>{
    'projectRevision': projectRevision,
    'requestId': requestId,
    'engineVersion': engineVersion,
    'durationS': durationS,
    'maxStepS': maxStepS,
    'chambers': <Map<String, Object?>>[
      for (final FixedAirChamber chamber
          in network.initialSnapshot.chambers.values)
        _chamber(chamber),
    ],
    'boundaries': <Map<String, Object?>>[
      for (final FixedPressureAirNode node in network.boundaries)
        <String, Object?>{
          'id': node.id,
          'pressureAbsPa': node.pressureAbsPa,
          'temperatureK': node.temperatureK,
        },
    ],
    'passages': <Map<String, Object?>>[
      for (final AirPassage pipe in network.passages)
        <String, Object?>{
          'id': pipe.id,
          'from': pipe.firstChamberId,
          'to': pipe.secondChamberId,
          'areaM2': pipe.orifice.effectiveAreaM2,
          'cd': pipe.orifice.dischargeCoefficient,
          'gamma': pipe.orifice.gamma,
          'gasConstantJPerKgK': pipe.orifice.gasConstantJPerKgK,
          'reverseFlowAllowed': pipe.reverseFlowAllowed,
        },
    ],
    'before': <String, Object?>{
      'timeS': before.timeS,
      'acceptedSubsteps': before.acceptedSubsteps,
      'externalMassAddedKg': before.externalMassAddedKg,
      'chambers': <Map<String, Object?>>[
        for (final FixedAirChamber c in before.chambers.values) _chamber(c),
      ],
      'flows': before.passageMassFlowKgPerS,
    },
  };

  static Map<String, Object?> _chamber(FixedAirChamber c) => <String, Object?>{
    'id': c.id,
    'volumeM3': c.volumeM3,
    'massKg': c.massKg,
    'temperatureK': c.temperatureK,
  };

  static Map<String, dynamic> _object(Object? value) =>
      Map<String, dynamic>.from(value! as Map);

  static List<dynamic> _list(Object? value) => value! as List<dynamic>;

  static double _number(Map<String, dynamic> x, String key) =>
      (x[key]! as num).toDouble();

  static FixedAirChamber _readChamber(Object? x) {
    final Map<String, dynamic> j = _object(x);
    return FixedAirChamber(
      id: j['id']! as String,
      volumeM3: _number(j, 'volumeM3'),
      massKg: _number(j, 'massKg'),
      temperatureK: _number(j, 'temperatureK'),
    );
  }

  factory R6NetworkJob.fromJson(Map<String, dynamic> j) {
    final IsothermalAirNetwork network = IsothermalAirNetwork(
      chambers: _list(j['chambers']).map(_readChamber).toList(),
      boundaries: <FixedPressureAirNode>[
        for (final dynamic value in _list(j['boundaries']))
          FixedPressureAirNode(
            id: _object(value)['id']! as String,
            pressureAbsPa: _number(_object(value), 'pressureAbsPa'),
            temperatureK: _number(_object(value), 'temperatureK'),
          ),
      ],
      passages: <AirPassage>[
        for (final dynamic value in _list(j['passages']))
          AirPassage(
            id: _object(value)['id']! as String,
            firstChamberId: _object(value)['from']! as String,
            secondChamberId: _object(value)['to']! as String,
            orifice: IsentropicOrifice(
              effectiveAreaM2: _number(_object(value), 'areaM2'),
              dischargeCoefficient: _number(_object(value), 'cd'),
              gamma: _number(_object(value), 'gamma'),
              gasConstantJPerKgK: _number(_object(value), 'gasConstantJPerKgK'),
            ),
            reverseFlowAllowed: _object(value)['reverseFlowAllowed']! as bool,
          ),
      ],
    );
    final Map<String, dynamic> b = _object(j['before']);
    return R6NetworkJob(
      projectRevision: j['projectRevision']! as int,
      requestId: j['requestId']! as int,
      engineVersion: j['engineVersion']! as String,
      network: network,
      before: IsothermalAirSnapshot(
        timeS: _number(b, 'timeS'),
        chambers: <String, FixedAirChamber>{
          for (final dynamic raw in _list(b['chambers']))
            _readChamber(raw).id: _readChamber(raw),
        },
        passageMassFlowKgPerS: <String, double>{
          for (final MapEntry<String, dynamic> e in _object(b['flows']).entries)
            e.key: (e.value as num).toDouble(),
        },
        acceptedSubsteps: b['acceptedSubsteps']! as int,
        externalMassAddedKg: _number(b, 'externalMassAddedKg'),
      ),
      durationS: _number(j, 'durationS'),
      maxStepS: _number(j, 'maxStepS'),
    );
  }

  R6NetworkOutcome execute() {
    final IsothermalAirSnapshot after = network.advance(
      before,
      durationS: durationS,
      maxStepS: maxStepS,
    );
    final double residual =
        after.totalMassKg -
        before.totalMassKg -
        (after.externalMassAddedKg - before.externalMassAddedKg);
    if (!residual.isFinite ||
        residual.abs() > 1e-9 ||
        after.timeS < before.timeS) {
      throw const PneumaticPhysicsException(
        'worker_result_rejected',
        'Worker did not produce a conservative accepted gas snapshot.',
      );
    }
    return R6NetworkOutcome(
      projectRevision: projectRevision,
      requestId: requestId,
      engineVersion: engineVersion,
      snapshot: after,
    );
  }
}

final class R6NetworkOutcome {
  const R6NetworkOutcome({
    required this.projectRevision,
    required this.requestId,
    required this.engineVersion,
    required this.snapshot,
  });
  final int projectRevision;
  final int requestId;
  final String engineVersion;
  final IsothermalAirSnapshot snapshot;

  Map<String, Object?> toJson() => <String, Object?>{
    'projectRevision': projectRevision,
    'requestId': requestId,
    'engineVersion': engineVersion,
    'timeS': snapshot.timeS,
    'acceptedSubsteps': snapshot.acceptedSubsteps,
    'externalMassAddedKg': snapshot.externalMassAddedKg,
    'chambers': <Map<String, Object?>>[
      for (final FixedAirChamber c in snapshot.chambers.values)
        R6NetworkJob._chamber(c),
    ],
    'flows': snapshot.passageMassFlowKgPerS,
  };

  factory R6NetworkOutcome.fromJson(Map<String, dynamic> j) => R6NetworkOutcome(
    projectRevision: j['projectRevision']! as int,
    requestId: j['requestId']! as int,
    engineVersion: j['engineVersion']! as String,
    snapshot: IsothermalAirSnapshot(
      timeS: R6NetworkJob._number(j, 'timeS'),
      acceptedSubsteps: j['acceptedSubsteps']! as int,
      externalMassAddedKg: R6NetworkJob._number(j, 'externalMassAddedKg'),
      chambers: <String, FixedAirChamber>{
        for (final dynamic c in R6NetworkJob._list(j['chambers']))
          R6NetworkJob._readChamber(c).id: R6NetworkJob._readChamber(c),
      },
      passageMassFlowKgPerS: <String, double>{
        for (final MapEntry<String, dynamic> e in R6NetworkJob._object(
          j['flows'],
        ).entries)
          e.key: (e.value as num).toDouble(),
      },
    ),
  );
}
