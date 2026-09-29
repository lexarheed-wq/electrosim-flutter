#!/usr/bin/env python3
import json,platform,shutil,subprocess,sys

def cmd(args):
    try:
        p=subprocess.run(args,text=True,capture_output=True,timeout=30)
        return {'exitCode':p.returncode,'stdout':p.stdout.strip()[-4000:],'stderr':p.stderr.strip()[-4000:]}
    except Exception as e:
        return {'exitCode':127,'stdout':'','stderr':str(e)}

probe={
 'schemaVersion':1,
 'host':{'system':platform.system(),'release':platform.release(),'machine':platform.machine()},
 'tools':{},
}
for name in ['flutter','dart','xcodebuild','clang','cmake','ninja','java','adb']:
    probe['tools'][name]=shutil.which(name)
if shutil.which('flutter'):
    probe['flutterVersion']=cmd(['flutter','--version'])
    probe['flutterDoctor']=cmd(['flutter','doctor','-v'])
print(json.dumps(probe,indent=2))
