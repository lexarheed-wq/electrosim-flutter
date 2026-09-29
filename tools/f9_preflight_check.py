#!/usr/bin/env python3
from __future__ import annotations
import csv, json, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
required=[
'docs/f9/F9_PREPARATION_STATUS.md','docs/f9/F9_DESIGN_SYSTEM_SPEC.md','docs/f9/F9_RESPONSIVE_LAYOUT_SPEC.md',
'docs/f9/F9_COMPONENT_VISUAL_LANGUAGE.md','docs/f9/F9_ACCESSIBILITY_AND_INPUT_SPEC.md','docs/f9/F9_GOLDEN_AND_ACCEPTANCE_PLAN.md',
'docs/f9/F9_IMPLEMENTATION_PLAN.md','docs/f9/F9_VALIDATED_UX_CONTRACT.md','docs/f9/F9_INFORMATION_ARCHITECTURE.md',
'docs/f9/F9_LEGACY_VISUAL_AUDIT.md','docs/f9/F9_UI_STATE_MODEL.md','docs/f9/F9_SCREEN_RESPONSIVE_MATRIX.csv',
'docs/f9/F9_ACCEPTANCE_MATRIX.csv','docs/f9/F9_LEGACY_VISUAL_TAXONOMY.csv','docs/f9/F9_WORK_BREAKDOWN_READY.md',
'docs/f9/reference_screens/legacy_home_reference.png','docs/f9/reference_screens/legacy_workspace_desktop.png',
'docs/f9/reference_screens/legacy_workspace_mobile_student.png',
'docs/f9/F9_REFERENCE_MOCKUPS.md','docs/f9/F9_VISUAL_TOKEN_PROPOSAL.md','docs/f9/F9_COMPONENT_RENDER_CONTRACT.md',
'docs/f9/F9_SCREEN_REFERENCE_MATRIX.md','docs/f9/mockups/01_home_expanded.svg','docs/f9/mockups/01_home_expanded.png',
'docs/f9/mockups/02_workspace_expanded.svg','docs/f9/mockups/02_workspace_expanded.png',
'docs/f9/mockups/03_student_troubleshooting_compact.svg','docs/f9/mockups/03_student_troubleshooting_compact.png',
'docs/f9/mockups/04_component_visual_system.svg','docs/f9/mockups/04_component_visual_system.png',
# R10 detailed component preparation
'docs/f9/F9_COMPONENT_FAMILY_SPEC.md','docs/f9/F9_COMPONENT_FAMILY_MATRIX.csv',
'docs/f9/F9_TERMINAL_SEMANTICS.md','docs/f9/F9_TERMINAL_ROLE_MATRIX.csv',
'docs/f9/F9_COMPONENT_STATE_MATRIX.csv','docs/f9/F9_COMPONENT_PILOT_SET.csv',
'docs/f9/F9_COMPONENT_VISUAL_QA_MATRIX.csv','docs/f9/F9_COMPONENT_IMPLEMENTATION_WAVES.md',
'docs/f9/F8_PRODUCTION_FREEZE_R10.json'
]
errors=[]
for rel in required:
    if not (ROOT/rel).is_file(): errors.append(f'missing:{rel}')

# F9 remains unopened: no Dart production sources in UI kit yet.
ui=ROOT/'packages/electrosim_ui_kit'
if ui.exists():
    dart=[p for p in ui.rglob('*.dart') if p.is_file()]
    if dart: errors.append('f9-opened-prematurely:'+','.join(str(p.relative_to(ROOT)) for p in dart))

# Reference mockups are design artifacts only, never production Dart.
mock=ROOT/'docs/f9/mockups'
if mock.exists():
    dart=[p for p in mock.rglob('*.dart') if p.is_file()]
    if dart: errors.append('dart-in-reference-mockups:'+','.join(str(p.relative_to(ROOT)) for p in dart))

# Taxonomy must account for all historical categories without importing items.
inv=list(csv.DictReader((ROOT/'docs/f0/legacy_component_inventory.csv').open(encoding='utf-8')))
tax=list(csv.DictReader((ROOT/'docs/f9/F9_LEGACY_VISUAL_TAXONOMY.csv').open(encoding='utf-8')))
inv_counts={}
for r in inv:
    k=(r['category'],r['entity_class']); inv_counts[k]=inv_counts.get(k,0)+1
tax_counts={(r['legacy_category'],r['entity_class']):int(r['count']) for r in tax}
if inv_counts!=tax_counts: errors.append('legacy-visual-taxonomy-count-mismatch')
if any(r.get('automatic_import')!='NO' for r in tax): errors.append('legacy-auto-import-must-remain-NO')

# R10 family registry must cover every proposed visual family exactly once.
fam=list(csv.DictReader((ROOT/'docs/f9/F9_COMPONENT_FAMILY_MATRIX.csv').open(encoding='utf-8')))
fam_ids=[r['family_id'] for r in fam]
if len(fam_ids)!=len(set(fam_ids)): errors.append('duplicate-family-id')
tax_by_family={r['proposed_visual_family']:int(r['count']) for r in tax}
fam_by_id={r['family_id']:r for r in fam}
if set(fam_by_id)!=set(tax_by_family):
    errors.append('family-registry-taxonomy-set-mismatch')
else:
    for family_id,count in tax_by_family.items():
        row=fam_by_id[family_id]
        if int(row['legacy_reference_count'])!=count:
            errors.append('family-legacy-count-mismatch:'+family_id)
        if row.get('automatic_import')!='NO':
            errors.append('family-auto-import-must-remain-NO:'+family_id)
        if family_id=='legacy-reference-only':
            if row.get('status')!='excluded': errors.append('legacy-family-must-be-excluded')
        elif row.get('status')!='active':
            errors.append('active-family-status-invalid:'+family_id)
        if family_id!='legacy-reference-only':
            for key in ['canonical_silhouette','footprint_token','terminal_schema','compact_policy','medium_policy','expanded_policy','result_driven_states']:
                if not row.get(key,'').strip(): errors.append(f'family-required-field-empty:{family_id}:{key}')

# Terminal roles are unique and include core electrical labels.
term=list(csv.DictReader((ROOT/'docs/f9/F9_TERMINAL_ROLE_MATRIX.csv').open(encoding='utf-8')))
term_ids=[r['terminal_role'] for r in term]
if len(term_ids)!=len(set(term_ids)): errors.append('duplicate-terminal-role')
core={'dc_pos','dc_neg','ac_l','ac_n','pe','l1','l2','l3','a1','a2','pv_pos','pv_neg','measure_com'}
if not core.issubset(set(term_ids)): errors.append('missing-core-terminal-role')

# State matrix must cover each family.
states=list(csv.DictReader((ROOT/'docs/f9/F9_COMPONENT_STATE_MATRIX.csv').open(encoding='utf-8')))
state_fams={r['family_id'] for r in states}
if state_fams!=set(fam_ids): errors.append('state-matrix-family-coverage-mismatch')

# Pilot set covers all main domains and uses known active families only.
pilots=list(csv.DictReader((ROOT/'docs/f9/F9_COMPONENT_PILOT_SET.csv').open(encoding='utf-8')))
pilot_ids=[r['pilot_id'] for r in pilots]
if len(pilot_ids)!=len(set(pilot_ids)): errors.append('duplicate-pilot-id')
for r in pilots:
    if r['family_id'] not in fam_by_id or fam_by_id[r['family_id']]['status']!='active':
        errors.append('pilot-unknown-or-excluded-family:'+r['pilot_id'])
coverage=';'.join(r['domain'] for r in pilots)
for domain in ['DC','AC1','AC3','PV']:
    if domain not in coverage: errors.append('pilot-domain-missing:'+domain)
if not any(r['family_id']=='measurement' for r in pilots): errors.append('pilot-measurement-missing')

# QA registry must provide the core checks for every active family.
qa=list(csv.DictReader((ROOT/'docs/f9/F9_COMPONENT_VISUAL_QA_MATRIX.csv').open(encoding='utf-8')))
qa_map={}
for r in qa: qa_map.setdefault(r['family_id'],set()).add(r['criterion_id'])
expected_qa={'identity','terminal_stability','input_target','ui_electrical_separation','result_driven_state','responsive','accessibility','no_auto_import'}
for family_id,row in fam_by_id.items():
    if row['status']=='active' and qa_map.get(family_id,set())!=expected_qa:
        errors.append('qa-family-coverage-mismatch:'+family_id)

# Acceptance IDs unique.
acc=list(csv.DictReader((ROOT/'docs/f9/F9_ACCEPTANCE_MATRIX.csv').open(encoding='utf-8')))
ids=[r['id'] for r in acc]
if len(ids)!=len(set(ids)): errors.append('duplicate-acceptance-id')

# Production code must stay frozen while F9 is preparation-only.
freeze=subprocess.run([sys.executable,str(ROOT/'tools/f8_production_freeze_check.py')],cwd=ROOT,text=True,capture_output=True)
if freeze.returncode!=0: errors.append('f8-production-freeze-failed')

status='PASS' if not errors else 'FAIL'
print(json.dumps({
    'phase':'F9-PREP','status':status,'requiredArtifacts':len(required),'legacyInventoryItems':len(inv),
    'visualFamilies':len(fam),'terminalRoles':len(term),'componentPilots':len(pilots),'qaRows':len(qa),
    'acceptanceCriteria':len(acc),'productionFreezeStatus':'PASS' if freeze.returncode==0 else 'FAIL','errors':errors
},indent=2,ensure_ascii=False))
sys.exit(0 if not errors else 1)
