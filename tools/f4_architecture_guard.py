#!/usr/bin/env python3
from __future__ import annotations
import json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PKG=ROOT/'packages/electrosim_measurements'
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
            uri.startswith('package:electrosim_solver_dc') or
            uri.startswith('package:electrosim_solver_ac') or
            uri.startswith('package:electrosim_measurements')
        ):
            errors.append(f'forbidden-project-dependency:{p.relative_to(ROOT)}:{uri}')
    lowered=text.lower()
    for token in ('scenarioid','exampleid','teachertruth','package:flutter','dart:ui'):
        if token in lowered:
            errors.append(f'forbidden-cross-layer-token:{p.relative_to(ROOT)}:{token}')
pub=(PKG/'pubspec.yaml').read_text(encoding='utf-8')
if re.search(r'^\s*flutter\s*:',pub,re.M): errors.append('flutter-dependency-in-measurement-pubspec')
for dep in ('electrosim_domain:','electrosim_topology:','electrosim_solver_dc:','electrosim_solver_ac:'):
    if dep not in pub: errors.append(f'missing-dependency:{dep}')
result={'phase':'F4','status':'PASS' if not errors else 'FAIL','filesScanned':files,'errors':errors}
print(json.dumps(result,indent=2,ensure_ascii=False)); sys.exit(0 if not errors else 1)
