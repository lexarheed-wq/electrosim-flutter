import 'domain_error.dart';
import 'electrical_types.dart';

/// Broad electrical responsibility of a component model.
///
/// This classification is deliberately solver-agnostic. It is used to describe
/// the structure of a model, never to compute currents or voltages.
enum ComponentFamily {
  passive,
  receiver,
  switching,
  protection,
  electromechanicalControl,
  measurement,
  conversion,
  junction,
  other,
}

/// Structural role of one internal electrical branch of a component model.
enum ElectricalBranchRole {
  main,
  powerPole,
  controlCoil,
  auxiliaryNormallyOpen,
  auxiliaryNormallyClosed,
  measurement,
}

/// Defines one internal two-terminal branch of a component model.
///
/// Terminal indexes belong to the model contract, not to a legacy runtime.
/// They are resolved to instance terminal IDs by the topology compiler.
final class ComponentBranchDefinition {
  ComponentBranchDefinition({
    required String id,
    required this.fromTerminalIndex,
    required this.toTerminalIndex,
    required this.role,
    this.poleIndex,
  }) : id = _validateBranchId(id) {
    if (fromTerminalIndex < 0 || toTerminalIndex < 0) {
      throw DomainException(
        code: DomainErrorCode.invalidValue,
        message: 'Component branch terminal indexes must be zero or greater.',
        context: <String, Object?>{
          'branchId': this.id,
          'fromTerminalIndex': fromTerminalIndex,
          'toTerminalIndex': toTerminalIndex,
        },
      );
    }
    if (fromTerminalIndex == toTerminalIndex) {
      throw DomainException(
        code: DomainErrorCode.invalidValue,
        message: 'A component branch cannot join a terminal index to itself.',
        context: <String, Object?>{
          'branchId': this.id,
          'terminalIndex': fromTerminalIndex,
        },
      );
    }
    if (poleIndex != null && poleIndex! < 0) {
      throw DomainException(
        code: DomainErrorCode.invalidValue,
        message: 'poleIndex must be zero or greater when provided.',
        context: <String, Object?>{'branchId': this.id, 'poleIndex': poleIndex},
      );
    }
  }

  final String id;
  final int fromTerminalIndex;
  final int toTerminalIndex;
  final ElectricalBranchRole role;
  final int? poleIndex;

  static String _validateBranchId(String value) {
    if (value.isEmpty || value != value.trim()) {
      throw DomainException(
        code: DomainErrorCode.invalidValue,
        message: 'Component branch id must be non-empty and trimmed.',
        context: <String, Object?>{'branchId': value},
      );
    }
    return value;
  }
}

/// Solver-independent structural contract for one canonical component model.
final class ComponentModelContract {
  ComponentModelContract({
    required String modelType,
    required this.family,
    required this.terminalCount,
    required Iterable<ElectricalMode> supportedModes,
    Iterable<ComponentBranchDefinition> branches = const <ComponentBranchDefinition>[],
  }) : modelType = _validateModelType(modelType),
       supportedModes = Set<ElectricalMode>.unmodifiable(supportedModes),
       branches = List<ComponentBranchDefinition>.unmodifiable(branches) {
    if (terminalCount <= 0) {
      throw DomainException(
        code: DomainErrorCode.invalidValue,
        message: 'Component model terminalCount must be greater than zero.',
        context: <String, Object?>{'modelType': this.modelType, 'terminalCount': terminalCount},
      );
    }
    if (this.supportedModes.isEmpty) {
      throw DomainException(
        code: DomainErrorCode.invalidValue,
        message: 'Component model must support at least one electrical mode.',
        context: <String, Object?>{'modelType': this.modelType},
      );
    }

    final Set<String> branchIds = <String>{};
    for (final ComponentBranchDefinition branch in this.branches) {
      if (!branchIds.add(branch.id)) {
        throw DomainException(
          code: DomainErrorCode.duplicateId,
          message: 'Duplicate component branch id ${branch.id}.',
          context: <String, Object?>{'modelType': this.modelType, 'branchId': branch.id},
        );
      }
      if (branch.fromTerminalIndex >= terminalCount || branch.toTerminalIndex >= terminalCount) {
        throw DomainException(
          code: DomainErrorCode.invalidValue,
          message: 'Component branch terminal index exceeds terminalCount.',
          context: <String, Object?>{
            'modelType': this.modelType,
            'branchId': branch.id,
            'terminalCount': terminalCount,
          },
        );
      }
    }
  }

  final String modelType;
  final ComponentFamily family;
  final int terminalCount;
  final Set<ElectricalMode> supportedModes;
  final List<ComponentBranchDefinition> branches;

  bool supportsMode(ElectricalMode mode) => supportedModes.contains(mode);

  static String _validateModelType(String value) {
    if (value.isEmpty || value != value.trim()) {
      throw DomainException(
        code: DomainErrorCode.invalidValue,
        message: 'Component model contract modelType must be non-empty and trimmed.',
        context: <String, Object?>{'modelType': value},
      );
    }
    return value;
  }
}

/// Immutable lookup registry for canonical component structural contracts.
final class ComponentModelRegistry {
  ComponentModelRegistry(Iterable<ComponentModelContract> contracts)
    : _byModelType = _buildMap(contracts);

  final Map<String, ComponentModelContract> _byModelType;

  ComponentModelContract? resolve(String modelType) => _byModelType[modelType];

  Iterable<ComponentModelContract> get contracts => _byModelType.values;

  static Map<String, ComponentModelContract> _buildMap(
    Iterable<ComponentModelContract> contracts,
  ) {
    final Map<String, ComponentModelContract> result = <String, ComponentModelContract>{};
    for (final ComponentModelContract contract in contracts) {
      if (result.containsKey(contract.modelType)) {
        throw DomainException(
          code: DomainErrorCode.duplicateId,
          message: 'Duplicate component model contract ${contract.modelType}.',
          context: <String, Object?>{'modelType': contract.modelType},
        );
      }
      result[contract.modelType] = contract;
    }
    return Map<String, ComponentModelContract>.unmodifiable(result);
  }
}

/// Canonical structural contracts introduced by the convergence work.
///
/// Names are new Flutter contracts. Historical V1 names are intentionally not
/// registered as aliases. This prevents legacy model strings from silently
/// becoming part of the new architecture.
final class CoreComponentModelContracts {
  CoreComponentModelContracts._();

  static final ComponentModelRegistry registry = ComponentModelRegistry(
    <ComponentModelContract>[
      ComponentModelContract(
        modelType: 'resistor',
        family: ComponentFamily.passive,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{
          ElectricalMode.dc,
          ElectricalMode.ac1,
          ElectricalMode.ac3,
          ElectricalMode.pv,
        },
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'main',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.main,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'inductor',
        family: ComponentFamily.passive,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{ElectricalMode.ac1, ElectricalMode.ac3},
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'main',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.main,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'capacitor',
        family: ComponentFamily.passive,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{ElectricalMode.ac1, ElectricalMode.ac3},
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'main',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.main,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'impedance',
        family: ComponentFamily.passive,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{ElectricalMode.ac1, ElectricalMode.ac3},
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'main',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.main,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'lamp',
        family: ComponentFamily.receiver,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{
          ElectricalMode.dc,
          ElectricalMode.ac1,
          ElectricalMode.ac3,
          ElectricalMode.pv,
        },
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'main',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.main,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'push_button_no',
        family: ComponentFamily.switching,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{
          ElectricalMode.dc,
          ElectricalMode.ac1,
          ElectricalMode.ac3,
        },
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'main',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.main,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'push_button_nc',
        family: ComponentFamily.switching,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{
          ElectricalMode.dc,
          ElectricalMode.ac1,
          ElectricalMode.ac3,
        },
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'main',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.main,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'buzzer',
        family: ComponentFamily.receiver,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{ElectricalMode.dc},
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'main',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.main,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'fan_dc',
        family: ComponentFamily.receiver,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{ElectricalMode.dc},
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'main',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.main,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'motor_dc',
        family: ComponentFamily.receiver,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{ElectricalMode.dc},
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'main',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.main,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'relay_coil',
        family: ComponentFamily.electromechanicalControl,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{ElectricalMode.dc},
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'control:coil',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.controlCoil,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'switch',
        family: ComponentFamily.switching,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{ElectricalMode.dc, ElectricalMode.ac1, ElectricalMode.ac3},
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'main',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.main,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'switch_spst',
        family: ComponentFamily.switching,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{ElectricalMode.dc, ElectricalMode.ac1, ElectricalMode.ac3},
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'main',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.main,
          ),
        ],
      ),
      ..._singlePoleProtectionContracts,
      ComponentModelContract(
        modelType: 'breaker_3p',
        family: ComponentFamily.protection,
        terminalCount: 6,
        supportedModes: <ElectricalMode>{ElectricalMode.ac3},
        branches: _threePowerPoles,
      ),
      ComponentModelContract(
        modelType: 'thermal_overload_3p',
        family: ComponentFamily.protection,
        terminalCount: 6,
        supportedModes: <ElectricalMode>{ElectricalMode.ac3},
        branches: _threePowerPoles,
      ),
      ComponentModelContract(
        modelType: 'contactor_aux_no',
        family: ComponentFamily.electromechanicalControl,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{
          ElectricalMode.ac1,
          ElectricalMode.ac3,
        },
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'aux:no',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.auxiliaryNormallyOpen,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'contactor_aux_nc',
        family: ComponentFamily.electromechanicalControl,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{
          ElectricalMode.ac1,
          ElectricalMode.ac3,
        },
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'aux:nc',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.auxiliaryNormallyClosed,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'contactor_ac1',
        family: ComponentFamily.electromechanicalControl,
        terminalCount: 4,
        supportedModes: <ElectricalMode>{ElectricalMode.ac1},
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'power:1',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.powerPole,
            poleIndex: 0,
          ),
          ComponentBranchDefinition(
            id: 'control:coil',
            fromTerminalIndex: 2,
            toTerminalIndex: 3,
            role: ElectricalBranchRole.controlCoil,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'contactor_3p',
        family: ComponentFamily.electromechanicalControl,
        terminalCount: 8,
        supportedModes: <ElectricalMode>{ElectricalMode.ac3},
        branches: <ComponentBranchDefinition>[
          ..._threePowerPoles,
          ComponentBranchDefinition(
            id: 'control:coil',
            fromTerminalIndex: 6,
            toTerminalIndex: 7,
            role: ElectricalBranchRole.controlCoil,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'pv_inverter',
        family: ComponentFamily.conversion,
        terminalCount: 4,
        supportedModes: <ElectricalMode>{ElectricalMode.pv},
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'dc:input',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.main,
          ),
          ComponentBranchDefinition(
            id: 'ac:output',
            fromTerminalIndex: 2,
            toTerminalIndex: 3,
            role: ElectricalBranchRole.main,
          ),
        ],
      ),
      ComponentModelContract(
        modelType: 'pv_resistive_load',
        family: ComponentFamily.receiver,
        terminalCount: 2,
        supportedModes: <ElectricalMode>{ElectricalMode.pv},
        branches: <ComponentBranchDefinition>[
          ComponentBranchDefinition(
            id: 'main',
            fromTerminalIndex: 0,
            toTerminalIndex: 1,
            role: ElectricalBranchRole.main,
          ),
        ],
      ),
    ],
  );

  static final List<ComponentModelContract> _singlePoleProtectionContracts =
      <ComponentModelContract>[
        ComponentModelContract(
          modelType: 'breaker_dc',
          family: ComponentFamily.protection,
          terminalCount: 2,
          supportedModes: <ElectricalMode>{ElectricalMode.dc, ElectricalMode.pv},
          branches: <ComponentBranchDefinition>[
            ComponentBranchDefinition(
              id: 'power:1',
              fromTerminalIndex: 0,
              toTerminalIndex: 1,
              role: ElectricalBranchRole.powerPole,
              poleIndex: 0,
            ),
          ],
        ),
        ComponentModelContract(
          modelType: 'breaker_ac1',
          family: ComponentFamily.protection,
          terminalCount: 2,
          supportedModes: <ElectricalMode>{ElectricalMode.ac1},
          branches: <ComponentBranchDefinition>[
            ComponentBranchDefinition(
              id: 'power:1',
              fromTerminalIndex: 0,
              toTerminalIndex: 1,
              role: ElectricalBranchRole.powerPole,
              poleIndex: 0,
            ),
          ],
        ),
        ComponentModelContract(
          modelType: 'fuse_dc',
          family: ComponentFamily.protection,
          terminalCount: 2,
          supportedModes: <ElectricalMode>{ElectricalMode.dc, ElectricalMode.pv},
          branches: <ComponentBranchDefinition>[
            ComponentBranchDefinition(
              id: 'power:1',
              fromTerminalIndex: 0,
              toTerminalIndex: 1,
              role: ElectricalBranchRole.powerPole,
              poleIndex: 0,
            ),
          ],
        ),
        ComponentModelContract(
          modelType: 'fuse_ac1',
          family: ComponentFamily.protection,
          terminalCount: 2,
          supportedModes: <ElectricalMode>{ElectricalMode.ac1},
          branches: <ComponentBranchDefinition>[
            ComponentBranchDefinition(
              id: 'power:1',
              fromTerminalIndex: 0,
              toTerminalIndex: 1,
              role: ElectricalBranchRole.powerPole,
              poleIndex: 0,
            ),
          ],
        ),
      ];

  static final List<ComponentBranchDefinition> _threePowerPoles =
      <ComponentBranchDefinition>[
        ComponentBranchDefinition(
          id: 'power:L1',
          fromTerminalIndex: 0,
          toTerminalIndex: 3,
          role: ElectricalBranchRole.powerPole,
          poleIndex: 0,
        ),
        ComponentBranchDefinition(
          id: 'power:L2',
          fromTerminalIndex: 1,
          toTerminalIndex: 4,
          role: ElectricalBranchRole.powerPole,
          poleIndex: 1,
        ),
        ComponentBranchDefinition(
          id: 'power:L3',
          fromTerminalIndex: 2,
          toTerminalIndex: 5,
          role: ElectricalBranchRole.powerPole,
          poleIndex: 2,
        ),
      ];
}
