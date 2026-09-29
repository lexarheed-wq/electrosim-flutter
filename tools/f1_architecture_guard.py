#!/usr/bin/env python3
from __future__ import annotations
import json,re,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DOMAIN=ROOT/'packages/electrosim_domain'
errors=[]
files=[]
for p in sorted((DOMAIN/'lib').rglob('*.dart')):
    files.append(p.relative_to(ROOT).as_posix())
    text=p.read_text(encoding='utf-8')
    for m in re.finditer(r"(?:import|export)\s+['\"]([^'\"]+)['\"]", text):
        uri=m.group(1)
        if uri.startswith('package:flutter') or uri=='dart:ui':
            errors.append(f'ui-dependency:{p.relative_to(ROOT)}:{uri}')
        if uri.startswith('package:electrosim_') and not uri.startswith('package:electrosim_domain'):
            errors.append(f'project-upward-dependency:{p.relative_to(ROOT)}:{uri}')
pub=(DOMAIN/'pubspec.yaml').read_text(encoding='utf-8')
if re.search(r'^\s*flutter\s*:', pub, re.M): errors.append('flutter-dependency-in-domain-pubspec')
if not files: errors.append('no-domain-source-files')
result={'phase':'F1','status':'PASS' if not errors else 'FAIL','filesScanned':files,'errors':errors}
print(json.dumps(result,indent=2,ensure_ascii=False))
sys.exit(0 if not errors else 1)
