#!/usr/bin/env python3
from __future__ import annotations
import json,re,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
PKG=ROOT/'packages/electrosim_topology'
errors=[]
files=[]
for p in sorted((PKG/'lib').rglob('*.dart')):
    files.append(p.relative_to(ROOT).as_posix())
    text=p.read_text(encoding='utf-8')
    for m in re.finditer(r"(?:import|export)\s+['\"]([^'\"]+)['\"]", text):
        uri=m.group(1)
        if uri.startswith('package:flutter') or uri=='dart:ui':
            errors.append(f'ui-dependency:{p.relative_to(ROOT)}:{uri}')
        if uri.startswith('package:electrosim_') and not (
            uri.startswith('package:electrosim_domain') or uri.startswith('package:electrosim_topology')
        ):
            errors.append(f'forbidden-project-dependency:{p.relative_to(ROOT)}:{uri}')
        if 'solver' in uri or 'measurement' in uri or 'energy' in uri:
            errors.append(f'forbidden-future-layer-dependency:{p.relative_to(ROOT)}:{uri}')

pub=(PKG/'pubspec.yaml').read_text(encoding='utf-8') if (PKG/'pubspec.yaml').exists() else ''
if re.search(r'^\s*flutter\s*:', pub, re.M):
    errors.append('flutter-dependency-in-topology-pubspec')
if 'electrosim_domain:' not in pub:
    errors.append('missing-domain-dependency')
if not files:
    errors.append('no-topology-source-files')

for p in sorted((PKG/'lib').rglob('*.dart')):
    text=p.read_text(encoding='utf-8').lower()
    for forbidden in ('voltage', 'current', 'kirchhoff', 'mna', 'matrix solve'):
        if forbidden in text and 'message:' not in text:
            errors.append(f'possible-electrical-solve-logic:{p.relative_to(ROOT)}:{forbidden}')

result={'phase':'F2','status':'PASS' if not errors else 'FAIL','filesScanned':files,'errors':errors}
print(json.dumps(result,indent=2,ensure_ascii=False))
sys.exit(0 if not errors else 1)
