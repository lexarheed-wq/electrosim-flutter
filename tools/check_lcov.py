#!/usr/bin/env python3
from __future__ import annotations
import json,sys
from pathlib import Path
if len(sys.argv) not in (2,3,4):
    print('usage: check_lcov.py <lcov.info> [minimum_percent] [phase]',file=sys.stderr); sys.exit(2)
path=Path(sys.argv[1]); minimum=float(sys.argv[2]) if len(sys.argv)>=3 else 90.0; phase=sys.argv[3] if len(sys.argv)==4 else 'F1'
if not path.is_file():
    print(json.dumps({'phase':phase,'status':'FAIL','reason':'lcov-missing','path':str(path)},indent=2)); sys.exit(1)
covered=0; total=0; current=''
for raw in path.read_text(encoding='utf-8').splitlines():
    if raw.startswith('SF:'): current=raw[3:].replace('\\','/')
    elif raw.startswith('DA:') and ('/lib/' in current or current.startswith('lib/')):
        parts=raw[3:].split(',')
        if len(parts)>=2:
            total+=1
            if int(parts[1])>0: covered+=1
pct=(100.0*covered/total) if total else 0.0
ok=total>0 and pct>=minimum
print(json.dumps({'phase':phase,'status':'PASS' if ok else 'FAIL','coveredLines':covered,'totalLines':total,'lineCoveragePercent':round(pct,2),'minimumPercent':minimum},indent=2))
sys.exit(0 if ok else 1)
