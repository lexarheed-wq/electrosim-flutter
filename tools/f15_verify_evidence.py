#!/usr/bin/env python3
from pathlib import Path
import json,sys,re
root=Path(__file__).resolve().parents[1]
mx=json.loads((root/'distribution/f15/release_matrix.json').read_text())
required=mx['requiredTargets']; errors=[]; evidence={}
for target in required:
    p=root/'docs/f15/evidence'/f'{target}.json'
    if not p.is_file(): errors.append(f'missing-evidence:{target}'); continue
    try: d=json.loads(p.read_text())
    except Exception as e: errors.append(f'invalid-json:{target}:{e}'); continue
    evidence[target]=d
    if d.get('target')!=target: errors.append(f'target-mismatch:{target}')
    if d.get('status')!='PASS': errors.append(f'not-pass:{target}')
    if d.get('smokeTest')!='PASS': errors.append(f'smoke-not-pass:{target}')
    if d.get('offlineCoreSmoke')!='PASS': errors.append(f'offline-not-pass:{target}')
    if not re.fullmatch(r'[0-9a-f]{64}',str(d.get('artifactSha256',''))): errors.append(f'bad-sha:{target}')
    sysname=d.get('host',{}).get('system')
    if target in {'macos','ios'} and sysname!='Darwin': errors.append(f'wrong-host:{target}:{sysname}')
    if target=='linux' and sysname!='Linux': errors.append(f'wrong-host:{target}:{sysname}')
    if target=='windows' and sysname!='Windows': errors.append(f'wrong-host:{target}:{sysname}')
status='PASS' if not errors else 'INCOMPLETE'
print(json.dumps({'phase':'F15-R7','status':status,'required':required,'present':sorted(evidence),'errors':errors},indent=2))
if errors:
    print('F15_GATE_CROSS_PLATFORM_EVIDENCE_REQUIRED')
    sys.exit(4)
print('F15_CROSS_PLATFORM_EVIDENCE_PASS')
