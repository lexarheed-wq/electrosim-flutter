#!/usr/bin/env python3
from pathlib import Path
import json,sys,re
root=Path(__file__).resolve().parents[1]
checks=[]
def add(n,v): checks.append((n,bool(v)))
helper=root/'tools/f15_flutter_env.sh'
add('resolver-exists',helper.is_file())
ht=helper.read_text() if helper.is_file() else ''
add('resolver-locks-version','TOOLCHAIN_LOCK.json' in ht and 'REQUIRED_FLUTTER' in ht and 'REQUIRED_DART' in ht)
add('resolver-offline-bootstrap','bootstrap_local_toolchain.sh' in ht)
for rel in ['tools/f15_prepare_runner.sh','tools/f15_qualify_target.sh','tools/f15_qualify_current_host.sh']:
    p=root/rel; t=p.read_text() if p.is_file() else ''
    add(rel+'-sources-resolver','f15_flutter_env.sh' in t)
# Critical target/runner scripts must not invoke bare flutter or dart commands.
for rel in ['tools/f15_prepare_runner.sh','tools/f15_qualify_target.sh']:
    t=(root/rel).read_text()
    bare=bool(re.search(r'(^|[;&|]\s*)flutter\s',t,re.M) or re.search(r'(^|[;&|]\s*)dart\s',t,re.M))
    add(rel+'-no-bare-sdk-command',not bare)

prep=(root/'tools/f15_prepare_runner.sh').read_text()
qual=(root/'tools/f15_qualify_target.sh').read_text()
add('runner-stdout-protocol','F15_RUNNER_PATH=%s' in prep)
add('runner-pub-get-to-stderr','pub get >&2' in prep)
add('runner-removes-generated-widget-test','test/widget_test.dart' in prep and 'MyApp' in prep and 'rm -f test/widget_test.dart' in prep)
add('qualifier-parses-runner-protocol','F15_RUNNER_PATH_PROTOCOL_ERROR' in qual and 'PREP_OUT=' in qual)
add('qualifier-validates-runner-dir','F15_RUNNER_PATH_INVALID' in qual)

failed=[n for n,v in checks if not v]
print(json.dumps({'phase':'F15-R5','status':'PASS' if not failed else 'FAIL','checks':len(checks),'failed':failed},indent=2))
if failed: sys.exit(1)
print(f'F15_TOOLCHAIN_CONTRACT_PASS {len(checks)}/{len(checks)}')
