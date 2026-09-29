#!/usr/bin/env python3
from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[1]
checks=[]
def add(name, ok): checks.append((name,bool(ok)))
mx=root/'distribution/f15/release_matrix.json'
add('release-matrix-exists',mx.is_file())
data=json.loads(mx.read_text()) if mx.is_file() else {}
add('required-five-targets',set(data.get('requiredTargets',[]))=={'macos','windows','linux','android','ios'})
add('offline-core-required',data.get('offlineCoreRequired') is True)
add('artifact-sha-required',data.get('evidencePolicy',{}).get('artifactSha256Required') is True)
add('smoke-required',data.get('evidencePolicy',{}).get('smokeTestRequired') is True)
for f in ['tools/f15_platform_probe.py','tools/f15_prepare_runner.sh','tools/f15_qualify_target.sh','tools/f15_qualify_current_host.sh','tools/f15_verify_evidence.py','tools/f15_validate_evidence_file.py','tools/f15_import_evidence_bundle.sh','.github/workflows/f15-platform-qualification.yml','tools/run_f15_gate.sh']:
    add(f, (root/f).is_file())
failed=[n for n,ok in checks if not ok]
print(json.dumps({'phase':'F15-R1','status':'PASS' if not failed else 'FAIL','checks':len(checks),'failed':failed},indent=2))
if failed: sys.exit(1)
print(f'F15_STATIC_CONTRACT_PASS {len(checks)}/{len(checks)}')
