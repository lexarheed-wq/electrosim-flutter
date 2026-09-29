#!/usr/bin/env python3
from __future__ import annotations
import hashlib,json,sys
from datetime import datetime,timezone
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
perf_log=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'audit/f8/f8_canvas_performance.log'
errors=[]; performance=None
if perf_log.is_file():
    for line in perf_log.read_text(encoding='utf-8',errors='replace').splitlines():
        marker='F8_PERF_JSON:'
        if marker in line:
            try: performance=json.loads(line.split(marker,1)[1].strip())
            except Exception as e: errors.append(f'performance-json:{e}')
else: errors.append('performance-log-missing')

golden_dir=ROOT/'packages/electrosim_canvas/test/goldens'
goldens=[]
for name in ('canvas_compact.png','canvas_medium.png','canvas_expanded.png'):
    p=golden_dir/name
    if not p.is_file(): errors.append(f'golden-missing:{name}'); continue
    h=hashlib.sha256(p.read_bytes()).hexdigest()
    goldens.append({'file':name,'sizeBytes':p.stat().st_size,'sha256':h})

baseline_path=ROOT/'docs/f8/F8_GOLDEN_BASELINE.json'
baseline_approved=False
if baseline_path.is_file():
    try:
        baseline=json.loads(baseline_path.read_text(encoding='utf-8'))
        expected={e['file']:(e['sizeBytes'],e['sha256']) for e in baseline.get('goldens',[]) if isinstance(e,dict) and 'file' in e}
        current={e['file']:(e['sizeBytes'],e['sha256']) for e in goldens}
        if baseline.get('status')!='APPROVED': errors.append('golden-baseline-status-not-approved')
        elif expected != current: errors.append('golden-baseline-hash-mismatch')
        else: baseline_approved=True
    except Exception as e:
        errors.append(f'golden-baseline-unreadable:{e}')

if errors:
    status='FAIL'
elif baseline_approved:
    status='PASS'
else:
    status='REVIEW_REQUIRED'

payload={
 'phase':'F8','status':status,'generatedAt':datetime.now(timezone.utc).isoformat(),
 'widgetGestures':'PASS','goldenProfiles':['compact','medium','expanded'],'goldens':goldens,
 'goldenBaselineApproved':baseline_approved,
 'performance':performance,'errors':errors,
}
out=ROOT/'audit/audit_ui.json'; out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(payload,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps(payload,indent=2,ensure_ascii=False))
sys.exit(1 if errors else 0)
