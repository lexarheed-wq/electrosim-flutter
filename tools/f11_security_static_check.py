#!/usr/bin/env python3
from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[1]
pkg=root/'packages'/'electrosim_scenarios'
scenario=(pkg/'lib/src/f11_fault_scenarios.dart').read_text(encoding='utf-8')
test=(pkg/'test/fault_scenario_repository_test.dart').read_text(encoding='utf-8')
checks={
  'scenario-corpus-no-exampleId': 'exampleId' not in scenario and 'ExampleId' not in scenario,
  'scenario-corpus-no-hidden-injection': 'hiddenFaultInjection' not in scenario,
  'student-payload-leak-test-present': all(x in test for x in ['teacherTruth','rootCauses','expectedMeasurements','acceptableRepairs']),
  'student-payload-no-example-test': "contains('exampleid')" in test,
}
failed=[k for k,v in checks.items() if not v]
report={'phase':'F11-R1','status':'PASS' if not failed else 'FAIL','teacherTruthLeakStaticCount':len(failed),'checks':checks}
print(json.dumps(report,indent=2))
if failed: sys.exit(1)
print('F11_SECURITY_STATIC_PASS')
