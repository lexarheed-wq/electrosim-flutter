#!/usr/bin/env python3
from __future__ import annotations
import json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CANVAS=ROOT/'packages/electrosim_canvas'
errors=[]; files=[]
if not CANVAS.is_dir(): errors.append('missing-package:electrosim_canvas')
for p in sorted((CANVAS/'lib').rglob('*.dart')) if CANVAS.is_dir() else []:
    rel=p.relative_to(ROOT).as_posix(); files.append(rel)
    text=p.read_text(encoding='utf-8')
    for m in re.finditer(r"(?:import|export)\s+['\"]([^'\"]+)['\"]",text):
        uri=m.group(1)
        if uri.startswith('package:electrosim_') and not uri.startswith('package:electrosim_domain') and not uri.startswith('package:electrosim_canvas'):
            errors.append(f'forbidden-project-dependency:{rel}:{uri}')
    lowered=text.lower()
    for token in ('solverengine','solverdc','solverac','solverpv','measurementengine','energyengine','topologyengine','teachertruth','faultengine','faultinjection'):
        if token in lowered: errors.append(f'forbidden-cross-layer-token:{rel}:{token}')
pub=(CANVAS/'pubspec.yaml')
if pub.is_file():
    text=pub.read_text(encoding='utf-8')
    for dep in ('electrosim_solver_dc','electrosim_solver_ac','electrosim_topology','electrosim_measurements','electrosim_pv','electrosim_energy','electrosim_scenarios','electrosim_storage','electrosim_diagnostics'):
        if re.search(rf'^\s*{re.escape(dep)}\s*:',text,re.M): errors.append(f'forbidden-pubspec-dependency:{dep}')
else: errors.append('missing-pubspec')
result={'phase':'F8','status':'PASS' if not errors else 'FAIL','filesScanned':files,'errors':errors}
print(json.dumps(result,indent=2,ensure_ascii=False)); sys.exit(0 if not errors else 1)
