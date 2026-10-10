import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';

final class ElectropneumaticRuntimeException implements Exception {
  const ElectropneumaticRuntimeException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ElectropneumaticRuntimeException($code): $message';
}

/// Measured operating voltage of an explicitly linked 24 V DC solenoid.
///
/// R3/A uses the existing *resistive* DC element as the electrical winding
/// surrogate. Inductance, winding temperature and magnetic field are not yet
/// modeled. A disconnected element is never promoted to an active coil.
final class CoilElectricalReading {
  const CoilElectricalReading({
    required this.linkId,
    required this.voltageV,
    required this.currentA,
    required this.powerW,
  });

  final String linkId;
  final double voltageV;
  final double currentA;
  final double powerW;
}

/// Read the existing nodal solver result; do not invent a 24 V bus or
/// infer an electrical connection from the front-view position of a symbol.
abstract final class DcCoilMeter {
  static CoilElectricalReading read({
    required MultiphysicsProject project,
    required ElectropneumaticLink link,
    required DcSolveResult result,
  }) {
    if (link.role != ElectropneumaticLinkRole.solenoidCoil ||
        !project.links.any((ElectropneumaticLink item) =>
            item.id == link.id &&
            item.electricalComponentId == link.electricalComponentId &&
            item.pneumaticDeviceId == link.pneumaticDeviceId &&
            item.role == link.role)) {
      throw const ElectropneumaticRuntimeException(
        'invalid_coil_link',
        'Coil measurement must reference an explicit existing solenoid link.',
      );
    }
    final CircuitState circuit = project.electricalCircuit;
    if (circuit.mode != ElectricalMode.dc ||
        !result.isSolved ||
        result.circuitId != circuit.circuitId ||
        result.circuitRevision != circuit.revision) {
      throw const ElectropneumaticRuntimeException(
        'stale_or_invalid_electrical_result',
        'Electrical solve must be valid for the exact DC circuit revision.',
      );
    }
    ComponentInstance? component;
    for (final ComponentInstance current in circuit.components) {
      if (current.id.value == link.electricalComponentId) {
        component = current;
        break;
      }
    }
    if (component == null ||
        component.modelType != 'resistor' ||
        component.condition != ComponentCondition.normal) {
      throw const ElectropneumaticRuntimeException(
        'unsupported_electrical_coil',
        'R3/A only meters a healthy two-terminal resistive winding surrogate.',
      );
    }
    final String branchId = 'component:${link.electricalComponentId}';
    DcBranchResult? branch;
    for (final DcBranchResult current in result.branchResults) {
      if (current.id == branchId) {
        branch = current;
        break;
      }
    }
    if (branch == null ||
        branch.kind != DcBranchKind.resistor ||
        branch.currentA == null ||
        !branch.voltageV.isFinite ||
        !branch.currentA!.isFinite ||
        branch.powerW == null ||
        !branch.powerW!.isFinite) {
      throw ElectropneumaticRuntimeException(
        'unmeasurable_coil',
        'The linked DC winding $branchId has no valid conductive branch.',
      );
    }
    return CoilElectricalReading(
      linkId: link.id,
      voltageV: branch.voltageV.abs(),
      currentA: branch.currentA!.abs(),
      powerW: branch.powerW!.abs(),
    );
  }
}
