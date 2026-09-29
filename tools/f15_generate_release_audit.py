#!/usr/bin/env python3
from pathlib import Path
import json,datetime
root=Path(__file__).resolve().parents[1]
mx=json.loads((root/'distribution/f15/release_matrix.json').read_text())
evdir=root/'docs/f15/evidence'
rows=[]
for target in mx['requiredTargets']+mx.get('complementaryTargets',[]):
    p=evdir/f'{target}.json'
    if p.is_file():
        try:
            d=json.loads(p.read_text())
            rows.append((target,d.get('status','UNKNOWN'),d.get('host',{}).get('system','?'),d.get('artifactSha256','')[:12]))
        except Exception:
            rows.append((target,'INVALID','?',''))
    else:
        rows.append((target,'PENDING','-',''))
lines=['# F15 release qualification audit','',f"Generated UTC: {datetime.datetime.now(datetime.timezone.utc).isoformat()}",'', '| Target | Status | Host | Artifact SHA-256 prefix |','|---|---|---|---|']
for r in rows: lines.append('| ' + ' | '.join(r) + ' |')
lines += ['', 'F15_GATE_PASS is permitted only when all required targets are PASS with verified evidence.', 'Web is complementary and does not block the release gate.']
(root/'docs/f15/audit_release.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(root/'docs/f15/audit_release.md')
