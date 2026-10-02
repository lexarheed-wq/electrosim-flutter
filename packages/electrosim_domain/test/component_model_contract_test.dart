import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:test/test.dart';

void main() {
  group('ComponentModelContract', () {
    test('rejects duplicate branch IDs and out-of-range terminal indexes', () {
      expect(
        () => ComponentModelContract(
          modelType: 'bad-duplicate',
          family: ComponentFamily.switching,
          terminalCount: 2,
          supportedModes: <ElectricalMode>{ElectricalMode.dc},
          branches: <ComponentBranchDefinition>[
            ComponentBranchDefinition(
              id: 'main',
              fromTerminalIndex: 0,
              toTerminalIndex: 1,
              role: ElectricalBranchRole.main,
            ),
            ComponentBranchDefinition(
              id: 'main',
              fromTerminalIndex: 0,
              toTerminalIndex: 1,
              role: ElectricalBranchRole.main,
            ),
          ],
        ),
        throwsA(isA<DomainException>()),
      );

      expect(
        () => ComponentModelContract(
          modelType: 'bad-index',
          family: ComponentFamily.switching,
          terminalCount: 2,
          supportedModes: <ElectricalMode>{ElectricalMode.dc},
          branches: <ComponentBranchDefinition>[
            ComponentBranchDefinition(
              id: 'main',
              fromTerminalIndex: 0,
              toTerminalIndex: 2,
              role: ElectricalBranchRole.main,
            ),
          ],
        ),
        throwsA(isA<DomainException>()),
      );
    });

    test('registry rejects duplicate model types', () {
      ComponentModelContract contract() => ComponentModelContract(
        modelType: 'same',
        family: ComponentFamily.other,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{ElectricalMode.dc},
      );

      expect(
        () => ComponentModelRegistry(<ComponentModelContract>[contract(), contract()]),
        throwsA(isA<DomainException>()),
      );
    });
  });

  group('CoreComponentModelContracts', () {
    test('three-phase contactor has three power poles plus one A1/A2 coil branch', () {
      final ComponentModelContract? contract =
          CoreComponentModelContracts.registry.resolve('contactor_3p');

      expect(contract, isNotNull);
      expect(contract!.family, ComponentFamily.electromechanicalControl);
      expect(contract.terminalCount, 8);
      expect(contract.supportedModes, <ElectricalMode>{ElectricalMode.ac3});
      expect(contract.branches, hasLength(4));
      expect(
        contract.branches.where((ComponentBranchDefinition b) => b.role == ElectricalBranchRole.powerPole),
        hasLength(3),
      );
      expect(
        contract.branches.singleWhere(
          (ComponentBranchDefinition b) => b.role == ElectricalBranchRole.controlCoil,
        ).id,
        'control:coil',
      );
    });

    test('canonical registry does not add legacy V1 aliases', () {
      expect(CoreComponentModelContracts.registry.resolve('breakerDC'), isNull);
      expect(CoreComponentModelContracts.registry.resolve('breaker3p'), isNull);
      expect(CoreComponentModelContracts.registry.resolve('contactor3p'), isNull);
      expect(CoreComponentModelContracts.registry.resolve('thermal3p'), isNull);
    });
  });

  group('TerminalRole convergence vocabulary', () {
    test('contains explicit power and coil terminal semantics', () {
      expect(TerminalRole.values, containsAll(<TerminalRole>[
        TerminalRole.lineL1,
        TerminalRole.lineL2,
        TerminalRole.lineL3,
        TerminalRole.loadT1,
        TerminalRole.loadT2,
        TerminalRole.loadT3,
        TerminalRole.coilA1,
        TerminalRole.coilA2,
      ]));
    });
  });
}
