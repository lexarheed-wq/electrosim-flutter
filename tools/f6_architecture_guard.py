#!/usr/bin/env python3
from __future__ import annotations
import json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PKG=ROOT/'packages/electrosim_solver_ac'
errors=[]; files=[]
for p in sorted((PKG/'lib').rglob('*.dart')):
    files.append(p.relative_to(ROOT).as_posix())
    text=p.read_text(encoding='utf-8')
    for m in re.finditer(r"(?:import|export)\s+['\"]([^'\"]+)['\"]", text):
        uri=m.group(1)
        if uri.startswith('package:flutter') or uri=='dart:ui':
            errors.append(f'ui-dependency:{p.relative_to(ROOT)}:{uri}')
        if uri.startswith('package:electrosim_') and not (
            uri.startswith('package:electrosim_domain') or
            uri.startswith('package:electrosim_topology') or
            uri.startswith('package:electrosim_solver_ac')
        ):
            errors.append(f'forbidden-project-dependency:{p.relative_to(ROOT)}:{uri}')
    lowered=text.lower()
    for token in ('scenarioid','exampleid','teachertruth','package:flutter','dart:ui'):
        if token in lowered:
            errors.append(f'forbidden-cross-layer-token:{p.relative_to(ROOT)}:{token}')
pub=(PKG/'pubspec.yaml').read_text(encoding='utf-8')
if re.search(r'^\s*flutter\s*:',pub,re.M): errors.append('flutter-dependency-in-ac-solver-pubspec')
for dep in ('electrosim_domain:','electrosim_topology:'):
    if dep not in pub: errors.append(f'missing-dependency:{dep}')
solver=(PKG/'lib/src/solver_ac3.dart').read_text(encoding='utf-8')
if re.search(r'\*\s*3(?:\.0)?\b', solver) or re.search(r'3(?:\.0)?\s*\*', solver):
    # sqrt(3) is legitimate; only reject obvious result scaling phrases/tokens below.
    pass
for token in ('phaseTimesThree','singlePhaseTimesThree','multiplyByThree'):
    if token in solver: errors.append(f'forbidden-triphasic-shortcut:{token}')
result={'phase':'F6','status':'PASS' if not errors else 'FAIL','filesScanned':files,'errors':errors}
print(json.dumps(result,indent=2,ensure_ascii=False)); sys.exit(0 if not errors else 1)
