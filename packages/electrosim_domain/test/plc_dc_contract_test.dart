import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:test/test.dart';

void main() {
  test('DC PLC exposes ten terminals and four isolated controlled outputs', () {
    final contract = CoreComponentModelContracts.registry.resolve('plc_dc')!;
    expect(contract.terminalCount, 10);
    expect(contract.supportedModes, <ElectricalMode>{ElectricalMode.dc});
    expect(contract.branches, hasLength(4));
    expect(contract.branches.map((branch) => branch.fromTerminalIndex), everyElement(0));
    expect(contract.branches.map((branch) => branch.toTerminalIndex), <int>[6, 7, 8, 9]);
    expect(contract.branches.map((branch) => branch.role), everyElement(ElectricalBranchRole.plcOutput));
    expect(CoreComponentPhysicsContracts.resolve('plc_dc')!.electricalLaw,
        ComponentElectricalLaw.programmableController);
  });
}
