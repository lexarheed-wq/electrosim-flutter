import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'runtime/electrosim_runtime_engine.dart';

class F18PowerConnectionPanel extends StatelessWidget {
  const F18PowerConnectionPanel({
    super.key,
    required this.circuit,
    required this.component,
    required this.onChanged,
    required this.runtimeSnapshot,
  });
  final CircuitState circuit;
  final ElectroSimRuntimeSnapshot runtimeSnapshot;
  final ComponentInstance component;
  final void Function(String mode, String? socketId)? onChanged;
  @override
  Widget build(BuildContext context) {
    final mode = AppliancePowerConnection.mode(component);
    double? chassisVoltage;
    final earth = component.terminals
        .where((t) => t.role == TerminalRole.protectiveEarth)
        .firstOrNull;
    final neutral = component.terminals.length == 3
        ? component.terminals[1]
        : circuit.sources
              .expand((s) => s.terminals)
              .where(
                (t) =>
                    t.phase == PhaseTag.neutral ||
                    t.role == TerminalRole.neutral,
              )
              .firstOrNull;
    final voltages =
        runtimeSnapshot.ac1Result?.nodeVoltages ??
        runtimeSnapshot.ac3Result?.nodeVoltages;
    if (earth != null &&
        neutral != null &&
        runtimeSnapshot.solved &&
        voltages != null) {
      final peNode = runtimeSnapshot.topology.terminalToNode[earth.id];
      final nNode = runtimeSnapshot.topology.terminalToNode[neutral.id];
      final neighbors = <String, Set<String>>{};
      void edge(String a, String b) {
        neighbors.putIfAbsent(a, () => {}).add(b);
        neighbors.putIfAbsent(b, () => {}).add(a);
      }

      for (final b
          in runtimeSnapshot.ac1Result?.branchResults ??
              const <Ac1BranchResult>[]) {
        if (b.kind.name != 'openCircuit') edge(b.fromNodeId, b.toNodeId);
      }
      for (final b
          in runtimeSnapshot.ac3Result?.branchResults ??
              const <Ac3BranchResult>[]) {
        if (b.kind.name != 'openCircuit') edge(b.fromNodeId, b.toNodeId);
      }
      final visited = <String>{};
      final queue = <String>[if (peNode != null) peNode];
      for (var i = 0; i < queue.length; i++) {
        if (!visited.add(queue[i])) continue;
        queue.addAll(
          (neighbors[queue[i]] ?? {}).where((n) => !visited.contains(n)),
        );
      }
      final pe = voltages[peNode];
      final n = voltages[runtimeSnapshot.topology.terminalToNode[neutral.id]];
      if (pe != null && n != null && visited.contains(nNode)) {
        chassisVoltage = (pe - n).magnitude;
      }
    }
    final dc = AppliancePowerConnection.isDc(component);
    final canPlug = AppliancePowerConnection.canPlug(component);
    final sockets = AppliancePowerConnection.compatibleSockets(
      circuit,
      component,
    );
    final savedId = component.controlState['powerSocketId'] as String?;
    final id = sockets.any((s) => s.id.value == savedId) ? savedId : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('power-mode-${component.id.value}-$mode'),
          isExpanded: true,
          initialValue: mode,
          decoration: const InputDecoration(labelText: 'Raccordement'),
          items: [
            const DropdownMenuItem(
              value: 'fixed',
              child: Text('Boîtier / raccordement fixe'),
            ),
            if (canPlug)
              DropdownMenuItem(
                value: dc ? 'dc' : 'plug',
                child: Text(
                  dc ? 'Connecteur courant continu' : 'Cordon avec fiche',
                ),
              ),
          ],
          onChanged: onChanged == null
              ? null
              : (v) {
                  if (v != null) onChanged!(v, null);
                },
        ),
        if (mode != 'fixed')
          DropdownButtonFormField<String>(
            key: ValueKey('power-socket-${component.id.value}-$id'),
            isExpanded: true,
            initialValue: id ?? '',
            decoration: const InputDecoration(
              labelText: 'Prise d’alimentation',
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Fiche débranchée'),
              ),
              ...sockets.map(
                (s) => DropdownMenuItem(
                  value: s.id.value,
                  child: Text(s.id.value),
                ),
              ),
            ],
            onChanged: onChanged == null
                ? null
                : (v) => onChanged!(mode, v == '' ? null : v),
          ),
        if (mode != 'fixed' && sockets.isEmpty)
          const Text('Ajouter une prise compatible depuis « Raccordements ».'),
        if (component.terminals.any(
          (t) => t.role == TerminalRole.protectiveEarth,
        ))
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Défaut d’isolement phase / châssis'),
            subtitle: const Text(
              'Résistance de défaut : 1 kΩ par défaut. PE à raccorder au réseau de terre.',
            ),
            value: component.controlState['insulationFault'] == true,
            onChanged: onChanged == null
                ? null
                : (v) => onChanged!(v ? 'fault-on' : 'fault-off', null),
          ),
        if (chassisVoltage != null)
          Text(
            'Tension châssis / neutre : ${chassisVoltage.toStringAsFixed(1)} V',
            style: TextStyle(
              color: chassisVoltage > 50 ? Colors.red.shade700 : null,
            ),
          ),
        if (earth != null && chassisVoltage == null)
          const Text(
            'Tension châssis / neutre : indéterminée (châssis isolé).',
          ),
        if (!dc && component.terminals.length == 2)
          const Text(
            'Appareil sans borne PE modélisée : ne pas supposer une protection par la terre.',
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
