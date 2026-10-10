import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'f18_industrial_physical_plate.dart';
import 'main.dart' show F9WorkspaceDemoPage;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await F18PhysicalPlateAssets.preload();
  final source = SourceInstance(
    id: SourceId('source'),
    modelType: 'dc_voltage_source',
    terminals: [
      Terminal(
        id: TerminalId('positive'),
        name: '+',
        role: TerminalRole.positive,
      ),
      Terminal(
        id: TerminalId('negative'),
        name: '−',
        role: TerminalRole.negative,
      ),
    ],
    parameters: {'voltageV': 24.0},
  );
  final types = ['motor_dc', 'fan_dc', 'buzzer'];
  final circuit = CircuitState(
    circuitId: CircuitId('audio-motion-proof'),
    revision: 0,
    mode: ElectricalMode.dc,
    sources: [source],
    components: [
      for (var i = 0; i < types.length; i++)
        ComponentInstance(
          id: ComponentId('receiver-$i'),
          modelType: types[i],
          terminals: [
            Terminal(id: TerminalId('in-$i'), name: '+'),
            Terminal(id: TerminalId('out-$i'), name: '−'),
          ],
          parameters: {
            'resistanceOhm': [8.0, 12.0, 48.0][i],
            'nominalVoltageV': 24.0,
          },
        ),
    ],
    connections: [
      for (var i = 0; i < types.length; i++) ...[
        Connection(
          id: ConnectionId('supply-$i'),
          fromTerminalId: source.terminals[0].id,
          toTerminalId: TerminalId('in-$i'),
        ),
        Connection(
          id: ConnectionId('return-$i'),
          fromTerminalId: TerminalId('out-$i'),
          toTerminalId: source.terminals[1].id,
        ),
      ],
    ],
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ElectroSimTheme.light(),
      home: F9WorkspaceDemoPage(initialCircuit: circuit),
    ),
  );
}
