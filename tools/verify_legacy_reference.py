#!/usr/bin/env python3
import hashlib,json,pathlib,re,sys,zipfile,collections,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]
ZIP=ROOT/'reference/legacy/ElectroSim-FIELDFIX01-R1.zip'
BASE=ROOT/'reference/REFERENCE_BASELINE.json'
AUD=ROOT/'audit/legacy_reference_analysis.json'
errors=[]

def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for c in iter(lambda:f.read(1024*1024),b''): h.update(c)
    return h.hexdigest()
base=json.loads(BASE.read_text())
expected=base['legacy_zip']['sha256']
actual=sha(ZIP)
if actual!=expected: errors.append('legacy-sha-mismatch')

# The distributable/source package may omit generated audit outputs. Rebuild the
# deterministic audit from the frozen legacy ZIP when it is absent, then verify
# the regenerated data against the immutable reference below.
if not AUD.is_file():
    analyzer=ROOT/'tools/analyze_legacy_reference.py'
    completed=subprocess.run([sys.executable,str(analyzer)],capture_output=True,text=True)
    if completed.returncode!=0:
        errors.append(
            f'audit-regeneration-failed:{completed.returncode}:'
            f'{completed.stdout}{completed.stderr}'
        )
try: stored=json.loads(AUD.read_text())
except Exception as exc:
    stored={}; errors.append(f'audit-unreadable:{exc}')
with zipfile.ZipFile(ZIP) as zf:
    names=[n for n in zf.namelist() if not n.endswith('/')]
    ext=collections.Counter(pathlib.Path(n).suffix.lower() for n in names)
    entry={}
    for base_name in ('teacher.html','student.html','mobile.html'):
        match=next((n for n in names if n.split('/',1)[-1]==base_name),None)
        if match:
            txt=zf.read(match).decode('utf-8','replace')
            entry[base_name]=len(re.findall(r'<script[^>]+src=["\']([^"\']+)["\']',txt,re.I))
checks={
    'sha256':actual,
    'fileCount':len(names),
    'js':ext['.js'],'ts':ext['.ts'],'json':ext['.json'],'png':ext['.png'],
    'teacherScripts':entry.get('teacher.html'),
    'studentScripts':entry.get('student.html'),
}
try:
    if stored['reference']['sha256']!=actual: errors.append('stored-audit-sha-mismatch')
    if stored['archive']['fileCount']!=len(names): errors.append('stored-audit-filecount-mismatch')
    if stored['archive']['extensions'].get('.js')!=ext['.js']: errors.append('stored-audit-js-count-mismatch')
    if stored['archive']['extensions'].get('.ts')!=ext['.ts']: errors.append('stored-audit-ts-count-mismatch')
    if stored['htmlEntrypoints']['teacher.html']['script_count']!=entry.get('teacher.html'): errors.append('stored-audit-teacher-count-mismatch')
    if stored['htmlEntrypoints']['student.html']['script_count']!=entry.get('student.html'): errors.append('stored-audit-student-count-mismatch')
except Exception as exc: errors.append(f'stored-audit-shape:{exc}')
print(json.dumps({'status':'PASS' if not errors else 'FAIL','errors':errors,'checks':checks},indent=2))
sys.exit(0 if not errors else 1)
