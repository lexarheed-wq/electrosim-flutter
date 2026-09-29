#!/usr/bin/env python3
from __future__ import annotations
import json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
packages={
  'electrosim_pv': {'electrosim_domain','electrosim_topology','electrosim_pv'},
  'electrosim_energy': {'electrosim_domain','electrosim_pv','electrosim_energy'},
}
errors=[]; files=[]
for pkg,allowed in packages.items():
    base=ROOT/'packages'/pkg
    if not base.is_dir():
        errors.append(f'missing-package:{pkg}')
        continue
    for p in sorted((base/'lib').rglob('*.dart')):
        files.append(p.relative_to(ROOT).as_posix())
        text=p.read_text(encoding='utf-8')
        for m in re.finditer(r"(?:import|export)\s+['\"]([^'\"]+)['\"]", text):
            uri=m.group(1)
            if uri.startswith('package:flutter') or uri=='dart:ui':
                errors.append(f'ui-dependency:{p.relative_to(ROOT)}:{uri}')
            if uri.startswith('package:electrosim_'):
                dep=uri.split('/')[0].removeprefix('package:')
                if dep not in allowed:
                    errors.append(f'forbidden-project-dependency:{p.relative_to(ROOT)}:{uri}')
        lowered=text.lower()
        for token in ('scenarioid','exampleid','teachertruth','faultengine','faultinjection','package:flutter','dart:ui'):
            if token in lowered:
                errors.append(f'forbidden-cross-layer-token:{p.relative_to(ROOT)}:{token}')
for pkg in packages:
    pub=(ROOT/'packages'/pkg/'pubspec.yaml').read_text(encoding='utf-8')
    if re.search(r'^\s*flutter\s*:',pub,re.M): errors.append(f'flutter-dependency-in-{pkg}-pubspec')
result={'phase':'F7','status':'PASS' if not errors else 'FAIL','filesScanned':files,'errors':errors}
print(json.dumps(result,indent=2,ensure_ascii=False)); sys.exit(0 if not errors else 1)
