#!/usr/bin/env python3
from __future__ import annotations
import json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PKG=ROOT/'packages/electrosim_domain'
errors=[]
required_files=[
 'pubspec.yaml','analysis_options.yaml','lib/electrosim_domain.dart',
 'lib/src/circuit_state.dart','lib/src/component.dart','lib/src/connection.dart',
 'lib/src/domain_error.dart','lib/src/electrical_types.dart','lib/src/ids.dart',
 'lib/src/json_support.dart','lib/src/source.dart','lib/src/terminal.dart',
 'test/domain_contract_test.dart'
]
for rel in required_files:
    if not (PKG/rel).is_file(): errors.append(f'missing:{rel}')
text='\n'.join(p.read_text(encoding='utf-8') for p in (PKG/'lib').rglob('*.dart'))
for symbol in ['CircuitState','ComponentInstance','SourceInstance','Terminal','Connection','DomainException','ElectricalMode','ElectricalUnit','CircuitId','TerminalId']:
    if not re.search(rf'\b(?:class|enum)\s+{re.escape(symbol)}\b', text): errors.append(f'missing-symbol:{symbol}')
if 'schemaVersion' not in text or 'currentSchemaVersion' not in text: errors.append('missing-schema-version-contract')
if 'package:flutter' in text or "'dart:ui'" in text or '"dart:ui"' in text: errors.append('ui-dependency-in-domain')
if re.search(r'\bTopologyEngine\b|\bSolverEngine\b|\bCustomPainter\b', text): errors.append('future-phase-implementation-detected')
result={'phase':'F1','status':'PASS' if not errors else 'FAIL','errors':errors,'dartSourceFiles':len(list((PKG/'lib').rglob('*.dart'))),'testFiles':len(list((PKG/'test').rglob('*.dart')))}
print(json.dumps(result,indent=2,ensure_ascii=False)); sys.exit(0 if not errors else 1)
