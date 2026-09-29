#!/usr/bin/env python3
from __future__ import annotations
import json,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
checks={
  'publicLibrary': ROOT/'packages/electrosim_topology/lib/electrosim_topology.dart',
  'topologyEngine': ROOT/'packages/electrosim_topology/lib/src/topology_engine.dart',
  'topologyGraph': ROOT/'packages/electrosim_topology/lib/src/topology_graph.dart',
  'topologyFinding': ROOT/'packages/electrosim_topology/lib/src/topology_finding.dart',
  'tests': ROOT/'packages/electrosim_topology/test/topology_engine_test.dart',
}
errors=[]
for name,path in checks.items():
    if not path.exists() or path.stat().st_size == 0:
        errors.append(f'missing:{name}:{path.relative_to(ROOT)}')

if not errors:
    engine=checks['topologyEngine'].read_text(encoding='utf-8')
    graph=checks['topologyGraph'].read_text(encoding='utf-8')
    findings=checks['topologyFinding'].read_text(encoding='utf-8')
    tests=checks['tests'].read_text(encoding='utf-8')
    required_engine=['class TopologyEngine','TopologyGraph compile','unionFind.union','conflictingPhases']
    required_graph=['class TopologyGraph','terminalToNode','componentNodeIds','sourceNodeIds']
    required_findings=['floatingNode','disabledConnection','isolatedComponent','isolatedSource','conflictingPhases']
    required_tests=['compile never mutates CircuitState','connection input order does not change canonical topology','public collections cannot be mutated']
    for token in required_engine:
        if token not in engine: errors.append(f'engine-contract-missing:{token}')
    for token in required_graph:
        if token not in graph: errors.append(f'graph-contract-missing:{token}')
    for token in required_findings:
        if token not in findings: errors.append(f'finding-contract-missing:{token}')
    for token in required_tests:
        if token not in tests: errors.append(f'test-contract-missing:{token}')

    # Regression F2-R2: never pipe `flutter --version` into `head`. On Flutter
    # 3.38.10/macOS 12 the producer may still write status text after `head`
    # closes the pipe, which raises a Broken pipe exception inside flutter_tools.
    for gate_name in ['run_f0_gate.sh', 'run_f1_gate.sh', 'run_f2_gate.sh']:
        gate=(ROOT/'tools'/gate_name).read_text(encoding='utf-8')
        if 'flutter --version | head' in gate or 'head -1' in gate:
            errors.append(f'unsafe-flutter-version-pipe:{gate_name}')
        if 'FLUTTER_VERSION_OUTPUT="$(flutter --version)"' not in gate:
            errors.append(f'missing-safe-flutter-version-capture:{gate_name}')

    f2gate=(ROOT/'tools'/'run_f2_gate.sh').read_text(encoding='utf-8')
    normalize='f1-dart-format-normalize'
    strict='f1-dart-format-check'
    if normalize not in f2gate or strict not in f2gate:
        errors.append('missing-f1-format-normalization-regression')
    elif f2gate.index(normalize) > f2gate.index(strict):
        errors.append('f1-format-normalization-after-strict-check')

result={'phase':'F2','status':'PASS' if not errors else 'FAIL','errors':errors}
print(json.dumps(result,indent=2,ensure_ascii=False))
sys.exit(0 if not errors else 1)
