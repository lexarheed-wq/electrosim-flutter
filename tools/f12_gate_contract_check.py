#!/usr/bin/env python3
from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[1]
text=(root/'tools/run_f12_gate.sh').read_text(encoding='utf-8')
needle='run_step "F10-F11-scenarios-pub-get" dart pub get'
analyze='run_step "F10-F11-scenarios-analyze" dart analyze'
errors=[]
if needle not in text: errors.append('missing-scenarios-pub-get')
if analyze not in text: errors.append('missing-scenarios-analyze')
if needle in text and analyze in text and text.index(needle) > text.index(analyze): errors.append('pub-get-after-analyze')
print(json.dumps({'phase':'F12-R3','status':'PASS' if not errors else 'FAIL','checks':3,'errors':errors},indent=2))
if errors: sys.exit(1)
print('F12_GATE_CONTRACT_PASS 3/3')
