import 'dart:convert';
import 'dart:math' as math;

import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:test/test.dart';

PneumaticPort _port(String id, String owner, PneumaticPortRole role) =>
    PneumaticPort(id: PneumaticPortId(id), deviceId: owner, role: role);

PneumaticDevice _device(String id, PneumaticDeviceKind kind, List<String> ids) =>
    PneumaticDevice(
      id: id,
      kind: kind,
      ports: <PneumaticPort>[
        for (final String portId in ids)
          _port(portId, id, PneumaticPortRole.work),
      ],
    );

PneumaticPipe _pipe(String id, String from, String to) => PneumaticPipe(
  id: id,
  fromPortId: PneumaticPortId(from),
  toPortId: PneumaticPortId(to),
  lengthM: 1.0,
  innerDiameterM: .006,
);

void main() {
  group('R1: typed pneumatic ports and connections', () {
    test('R1-C01: port is not an electrical TerminalId (explicit types)', () {
      final PneumaticPortId a = PneumaticPortId('port1');
      final PneumaticPortId b = PneumaticPortId('port1');
      expect(a, b);
      expect(a, isNot('port1'));
      expect(PneumaticPortRole.values.length, 4);
    });

    test('R1-C02: implicit third hose on one port is rejected', () {
      expect(
        () => PneumaticNetwork(
          devices: <PneumaticDevice>[
            _device('a', PneumaticDeviceKind.valve52, <String>['a1']),
            _device('b', PneumaticDeviceKind.doubleActingCylinder, <String>['b1']),
            _device('c', PneumaticDeviceKind.idealSource, <String>['c1']),
          ],
          pipes: <PneumaticPipe>[
            _pipe('p1', 'a1', 'b1'),
            _pipe('p2', 'a1', 'c1'),
          ],
        ),
        throwsA(
          isA<PneumaticContractException>().having(
            (e) => e.code, 'code', 'implicit_branch',
          ),
        ),
      );
    });

    test('R1-C03: explicit 3-port tee supports three physical hoses', () {
      final PneumaticNetwork air = PneumaticNetwork(
        devices: <PneumaticDevice>[
          _device('tee1', PneumaticDeviceKind.tee, <String>['t1', 't2', 't3']),
          _device('a', PneumaticDeviceKind.valve32, <String>['a1']),
          _device('b', PneumaticDeviceKind.doubleActingCylinder, <String>['b1']),
          _device('c', PneumaticDeviceKind.manometer, <String>['c1']),
        ],
        pipes: <PneumaticPipe>[
          _pipe('p1', 'a1', 't1'),
          _pipe('p2', 't2', 'b1'),
          _pipe('p3', 't3', 'c1'),
        ],
      );
      expect(air.pipes.length, 3);
      expect(air.devices.first.ports.length, 3);
    });

    test('R1-C04: invalid physical dimensions and finite rules rejected', () {
      expect(
        () => PneumaticPipe(
          id: 'h1',
          fromPortId: PneumaticPortId('a'),
          toPortId: PneumaticPortId('b'),
          lengthM: 0,
          innerDiameterM: .006,
        ),
        throwsA(isA<PneumaticContractException>()),
      );
      expect(
        () => PneumaticPipe(
          id: 'h1',
          fromPortId: PneumaticPortId('a'),
          toPortId: PneumaticPortId('b'),
          lengthM: 1,
          innerDiameterM: double.nan,
        ),
        throwsA(isA<PneumaticContractException>()),
      );
      expect(
        () => PneumaticPort(
          id: PneumaticPortId('a'),
          deviceId: 'd',
          role: PneumaticPortRole.supply,
          maxAbsolutePressurePa: double.infinity,
        ),
        throwsA(isA<PneumaticContractException>()),
      );
      expect(
        () => PneumaticDevice(
          id: 'd',
          kind: PneumaticDeviceKind.regulator,
          ports: <PneumaticPort>[_port('a', 'd', PneumaticPortRole.supply)],
          parametersSi: const <String, double>{'pressureAbsPa': double.nan},
        ),
        throwsA(isA<PneumaticContractException>()),
      );
    });

    test('R1-C05: unknown ports, duplicate devices and port IDs rejected', () {
      expect(
        () => PneumaticNetwork(
          devices: <PneumaticDevice>[
            _device('a', PneumaticDeviceKind.valve32, <String>['a1']),
          ],
          pipes: <PneumaticPipe>[_pipe('p', 'a1', 'missing')],
        ),
        throwsA(isA<PneumaticContractException>().having(
          (e) => e.code, 'code', 'unknown_port',
        )),
      );
      expect(
        () => PneumaticNetwork(
          devices: <PneumaticDevice>[
            _device('a', PneumaticDeviceKind.valve32, <String>['a1']),
            _device('a', PneumaticDeviceKind.valve52, <String>['a2']),
          ],
        ),
        throwsA(isA<PneumaticContractException>().having(
          (e) => e.code, 'code', 'duplicate_device',
        )),
      );
    });

    test('R1-P01: physical tube volume independent of schematic layout', () {
      final PneumaticPipe pipe = _pipe('p', 'a', 'b');
      expect(pipe.internalVolumeM3,
          closeTo(math.pi * .006 * .006 / 4, 1e-15));
    });

    test('R1-M02: JSON roundtrip conserves IDs, roles, units, faults', () {
      final PneumaticNetwork network = PneumaticNetwork(
        devices: <PneumaticDevice>[
          PneumaticDevice(
            id: 'valve',
            kind: PneumaticDeviceKind.valve52,
            ports: <PneumaticPort>[
              PneumaticPort(
                id: PneumaticPortId('P'),
                deviceId: 'valve',
                role: PneumaticPortRole.supply,
                maxAbsolutePressurePa: 1000000,
              ),
            ],
            parametersSi: const <String, double>{'spoolDelayS': .02},
          ),
          _device('cyl', PneumaticDeviceKind.doubleActingCylinder, <String>['A']),
        ],
        pipes: <PneumaticPipe>[
          PneumaticPipe(
            id: 'pipe',
            fromPortId: PneumaticPortId('P'),
            toPortId: PneumaticPortId('A'),
            lengthM: 2,
            innerDiameterM: .008,
            fault: PneumaticPipeFault.leaking,
            lossCoefficient: .2,
          ),
        ],
      );
      final PneumaticNetwork restored =
          PneumaticNetwork.fromJsonString(network.toJsonString());
      expect(restored.toJson(), equals(network.toJson()));
      expect(restored.devices.first.ports.first.role, PneumaticPortRole.supply);
      expect(restored.pipes.first.fault, PneumaticPipeFault.leaking);
    });

    test('R1-M03: future schema and malformed JSON are rejected', () {
      expect(
        () => PneumaticNetwork.fromJson(<String, dynamic>{
          'schemaVersion': 99, 'devices': <Object>[], 'pipes': <Object>[],
        }),
        throwsA(isA<PneumaticContractException>().having(
          (e) => e.code, 'code', 'unsupported_schema',
        )),
      );
      expect(
        () => PneumaticNetwork.fromJsonString(jsonEncode(<String, Object?>{
          'schemaVersion': 1, 'devices': <Object>[], 'pipes': 'not-a-list',
        })),
        throwsA(isA<PneumaticContractException>()),
      );
    });

    test('R1-G01: an empty air network is valid and never adds an electrical mode', () {
      expect(PneumaticNetwork().devices, isEmpty);
      expect(PneumaticNetwork().pipes, isEmpty);
    });
  });
}
