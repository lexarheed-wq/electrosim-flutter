#!/usr/bin/env python3
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
lib=root/'packages/electrosim_diagnostics/lib'
text='\n'.join(p.read_text(encoding='utf-8',errors='ignore') for p in lib.rglob('*.dart'))
bad=[]
for token in ('teacherTruth','FaultScenario','exampleId','electrosim_scenarios'):
    if token in text: bad.append(token)
print({'phase':'F13-R1','status':'PASS' if not bad else 'FAIL','forbiddenRuntimeTokens':bad})
if bad: sys.exit(1)
print('F13_SECURITY_STATIC_PASS')
