#!/usr/bin/env python3
import collections, hashlib, json, pathlib, re, sys, zipfile
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASELINE = ROOT / 'reference' / 'REFERENCE_BASELINE.json'
ZIP = ROOT / 'reference' / 'legacy' / 'ElectroSim-FIELDFIX01-R1.zip'
OUT = ROOT / 'audit' / 'legacy_reference_analysis.json'
DOC = ROOT / 'docs' / 'f0' / 'LEGACY_TECHNICAL_BASELINE.md'

TEXT_EXT = {'.js','.ts','.mjs','.html','.css','.json','.md','.txt','.py','.sh','.command'}
CODE_EXT = {'.js','.ts','.mjs'}

def sha256_file(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for c in iter(lambda:f.read(1024*1024), b''):
            h.update(c)
    return h.hexdigest()

def safe_text(zf, name):
    try:
        return zf.read(name).decode('utf-8', 'replace')
    except Exception:
        return ''

def rel(name):
    parts=name.split('/',1)
    return parts[1] if len(parts)>1 else name

def main():
    errors=[]
    baseline=json.loads(BASELINE.read_text(encoding='utf-8'))
    expected=baseline['legacy_zip']['sha256']
    actual=sha256_file(ZIP)
    if expected and expected != actual:
        errors.append(f'reference SHA mismatch: expected {expected}, actual {actual}')

    with zipfile.ZipFile(ZIP) as zf:
        names=[n for n in zf.namelist() if not n.endswith('/')]
        ext_counts=collections.Counter(pathlib.Path(n).suffix.lower() for n in names)
        size_by_ext=collections.Counter()
        for zi in zf.infolist():
            if not zi.is_dir(): size_by_ext[pathlib.Path(zi.filename).suffix.lower()] += zi.file_size

        package_files=[n for n in names if n.endswith('/package.json')]
        package={}
        if package_files:
            try: package=json.loads(safe_text(zf,package_files[0]))
            except Exception as exc: errors.append(f'package.json parse: {exc}')

        html={}
        for base in ('teacher.html','student.html','mobile.html','index.html'):
            matches=[n for n in names if rel(n)==base]
            if matches:
                text=safe_text(zf,matches[0])
                srcs=re.findall(r'<script[^>]+src=["\']([^"\']+)["\']',text,re.I)
                html[base]={'path':rel(matches[0]),'script_count':len(srcs),'scripts':srcs}

        global_assign=collections.Counter()
        prototype_mutations=[]
        storage_keys=collections.Counter()
        event_listeners=collections.Counter()
        named_functions=collections.Counter()
        classes=collections.Counter()
        import_specs=collections.Counter()
        code_files=[]
        json_files=[]
        schema_hints=collections.Counter()
        f1_forbidden_tokens=collections.Counter()

        patterns_global=[
            re.compile(r'\b(?:window|globalThis)\.([A-Za-z_$][\w$]*)\s*='),
            re.compile(r'\b(?:window|globalThis)\[["\']([^"\']+)["\']\]\s*=')
        ]
        p_proto=re.compile(r'([A-Za-z_$][\w$]*)\.prototype\.([A-Za-z_$][\w$]*)\s*=')
        p_storage=re.compile(r'\b(?:localStorage|sessionStorage)\.(?:getItem|setItem|removeItem)\s*\(\s*["\']([^"\']+)["\']')
        p_listener=re.compile(r'\.addEventListener\s*\(\s*["\']([^"\']+)["\']')
        p_func=re.compile(r'\bfunction\s+([A-Za-z_$][\w$]*)\s*\(')
        p_class=re.compile(r'\bclass\s+([A-Za-z_$][\w$]*)\b')
        p_import=re.compile(r'\b(?:import\s+(?:[^;]*?\s+from\s+)?|require\s*\()\s*["\']([^"\']+)["\']')

        for n in names:
            ext=pathlib.Path(n).suffix.lower()
            r=rel(n)
            if ext == '.json':
                json_files.append(r)
                txt=safe_text(zf,n)
                try:
                    obj=json.loads(txt)
                    if isinstance(obj,dict):
                        for k in ('schemaVersion','version','circuitId','components','connections','faults','examples','sessions','activities'):
                            if k in obj: schema_hints[k]+=1
                except Exception:
                    pass
            if ext not in CODE_EXT: continue
            txt=safe_text(zf,n)
            code_files.append({'path':r,'bytes':len(txt.encode("utf-8")),'lines':txt.count('\n')+1})
            for p in patterns_global:
                for m in p.finditer(txt): global_assign[m.group(1)] += 1
            for m in p_proto.finditer(txt): prototype_mutations.append({'file':r,'target':m.group(1),'member':m.group(2)})
            for m in p_storage.finditer(txt): storage_keys[m.group(1)] += 1
            for m in p_listener.finditer(txt): event_listeners[m.group(1)] += 1
            for m in p_func.finditer(txt): named_functions[m.group(1)] += 1
            for m in p_class.finditer(txt): classes[m.group(1)] += 1
            for m in p_import.finditer(txt): import_specs[m.group(1)] += 1
            for token in ('FaultEngine','ExampleCircuit','faultId','exampleId','globalThis.app','window.app'):
                if token in txt: f1_forbidden_tokens[token]+=txt.count(token)

        code_files.sort(key=lambda x:(-x['lines'],x['path']))
        report={
            'schemaVersion':1,
            'generatedAt':datetime.now(timezone.utc).isoformat(),
            'reference':{
                'filename':ZIP.name,'sha256':actual,'shaMatchesBaseline':not bool(errors),
                'packageName':package.get('name'),'packageVersion':package.get('version'),
                'typescriptVersion':(package.get('devDependencies') or {}).get('typescript')
            },
            'archive':{
                'fileCount':len(names),
                'extensions':dict(ext_counts.most_common()),
                'bytesByExtension':dict(size_by_ext.most_common()),
                'codeFileCount':len(code_files),
                'jsonFileCount':len(json_files)
            },
            'htmlEntrypoints':html,
            'architectureSignals':{
                'globalAssignmentCount':sum(global_assign.values()),
                'globalAssignmentNames':global_assign.most_common(80),
                'prototypeMutationCount':len(prototype_mutations),
                'prototypeMutations':prototype_mutations[:100],
                'eventListenerCount':sum(event_listeners.values()),
                'eventTypes':event_listeners.most_common(40),
                'importSpecs':import_specs.most_common(80),
                'legacyCouplingTokenCounts':dict(f1_forbidden_tokens)
            },
            'persistenceSignals':{
                'storageKeyUsages':storage_keys.most_common(120),
                'schemaHints':dict(schema_hints)
            },
            'codeInventory':{
                'largestByLines':code_files[:40],
                'namedFunctionCountApprox':sum(named_functions.values()),
                'classDeclarationCountApprox':sum(classes.values()),
                'topFunctionNames':named_functions.most_common(50),
                'topClassNames':classes.most_common(50)
            },
            'errors':errors,
            'status':'PASS' if not errors else 'FAIL'
        }
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

        top_globals=', '.join(f'`{k}` ({v})' for k,v in global_assign.most_common(12)) or 'aucun'
        top_storage=', '.join(f'`{k}` ({v})' for k,v in storage_keys.most_common(12)) or 'aucun'
        largest='\n'.join(f"- `{x['path']}` — {x['lines']} lignes" for x in code_files[:15])
        rows='\n'.join(f"| `{k}` | {v} |" for k,v in ext_counts.most_common(15))
        entryrows='\n'.join(f"| `{k}` | {v['script_count']} |" for k,v in html.items())
        doc=f'''# F0 — Baseline technique automatisée de la référence historique\n\nGénérée depuis `{ZIP.name}` sans modifier ni convertir le code historique.\n\n## Intégrité\n\n- SHA-256 : `{actual}`\n- Correspondance baseline : **{'OUI' if not errors else 'NON'}**\n- Version package : `{package.get('version','?')}`\n- TypeScript déclaré : `{(package.get('devDependencies') or {}).get('typescript','?')}`\n\n## Taille et composition\n\n- {len(names)} fichiers dans l'archive.\n- {len(code_files)} fichiers JS/TS/MJS analysés statiquement.\n- {len(json_files)} fichiers JSON repérés.\n\n| Extension | Nombre |\n|---|---:|\n{rows}\n\n## Entrées HTML\n\n| Entrée | Scripts externes |\n|---|---:|\n{entryrows}\n\nCes nombres quantifient la dépendance historique à l'ordre de chargement et justifient la reconstruction autour de dépendances Dart explicites.\n\n## Signaux de dette architecturale\n\n- Affectations globales `window/globalThis` détectées approximativement : **{sum(global_assign.values())}**.\n- Mutations de prototypes détectées approximativement : **{len(prototype_mutations)}**.\n- Listeners DOM détectés approximativement : **{sum(event_listeners.values())}**.\n- Globals les plus fréquents : {top_globals}.\n- Clés de stockage les plus fréquentes : {top_storage}.\n\nCes métriques sont des **signaux statiques**, pas une preuve de comportement runtime. Elles servent à décider quoi ne pas reproduire dans Flutter.\n\n## Fichiers de code les plus volumineux\n\n{largest}\n\n## Décisions de migration issues de cette baseline\n\n1. Ne pas reproduire l'ordre de chargement de dizaines/centaines de scripts comme mécanisme de composition.\n2. Ne pas transformer les globals historiques en singletons Dart globaux.\n3. Ne pas migrer les mutations de prototypes ; les extensions doivent devenir des contrats/modules explicites.\n4. Les clés de stockage observées sont uniquement un inventaire de formats à comprendre ; aucune donnée legacy n'est importée automatiquement.\n5. Les occurrences de `FaultEngine`, `faultId`, `exampleId` ou équivalents ne définissent pas la nouvelle architecture : exemples et pannes restent strictement indépendants.\n\nLe détail machine-lisible est dans `audit/legacy_reference_analysis.json`.\n'''
        DOC.write_text(doc,encoding='utf-8')

    print(json.dumps({'status':'PASS' if not errors else 'FAIL','errors':errors,'output':str(OUT.relative_to(ROOT)),'doc':str(DOC.relative_to(ROOT))},indent=2))
    return 0 if not errors else 1

if __name__=='__main__':
    raise SystemExit(main())
