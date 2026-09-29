#!/usr/bin/env python3
from pathlib import Path
import json,re,sys
if len(sys.argv)!=3:
    raise SystemExit('usage: f15_validate_evidence_file.py TARGET FILE')
target, raw = sys.argv[1:]
p=Path(raw)
if not p.is_file(): raise SystemExit(f'F15_EVIDENCE_FILE_MISSING {p}')
d=json.loads(p.read_text(encoding='utf-8'))
errors=[]
if d.get('target')!=target: errors.append('target-mismatch')
if d.get('status')!='PASS': errors.append('status-not-pass')
if d.get('smokeTest')!='PASS': errors.append('smoke-not-pass')
if d.get('offlineCoreSmoke')!='PASS': errors.append('offline-not-pass')
if not re.fullmatch(r'[0-9a-f]{64}',str(d.get('artifactSha256',''))): errors.append('bad-sha')
sysname=d.get('host',{}).get('system')
if target in {'macos','ios'} and sysname!='Darwin': errors.append(f'wrong-host:{sysname}')
if target=='linux' and sysname!='Linux': errors.append(f'wrong-host:{sysname}')
if target=='windows' and sysname!='Windows': errors.append(f'wrong-host:{sysname}')
if target not in {'macos','windows','linux','android','ios'}: errors.append('unsupported-target')
if errors:
    raise SystemExit('F15_EVIDENCE_FILE_INVALID '+target+' '+','.join(errors))
print('F15_EVIDENCE_FILE_PASS '+target)
