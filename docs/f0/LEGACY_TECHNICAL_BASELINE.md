# F0 — Baseline technique automatisée de la référence historique

Générée depuis `ElectroSim-FIELDFIX01-R1.zip` sans modifier ni convertir le code historique.

## Intégrité

- SHA-256 : `569e05908592e6dd615bd80b342f6c7a28249850951d353dac988c5d2e1187bd`
- Correspondance baseline : **OUI**
- Version package : `14.31.15-eie08-r1-eie08ux04-r1-eie-mon03-r1-tp-sync01-r1-deenergized01-r3-meter01-energytime01-eiers14-tpflow03-r1-uic01-r1-palette01-r2-canvasactions01-r2-tpflow04-r1-sup04-r1-rpr03-r1-risk01-r1-pal04-r1-act03-r1-uic04-r1-propedit01-r1-nf03-r1-eie20mode01-r1-contact01-r1-contact02-r1-eie01r4-r1-eie0405-r1-eie08m-r1-eie03i-r2-eie07a-r1-fieldfix01-r1`
- TypeScript déclaré : `5.8.3`

## Taille et composition

- 1535 fichiers dans l'archive.
- 461 fichiers JS/TS/MJS analysés statiquement.
- 70 fichiers JSON repérés.

| Extension | Nombre |
|---|---:|
| `.js` | 348 |
| `.py` | 332 |
| `.md` | 320 |
| `.png` | 213 |
| `.ts` | 109 |
| `.txt` | 106 |
| `.json` | 70 |
| `.log` | 15 |
| `.gif` | 4 |
| `.command` | 4 |
| `.html` | 4 |
| `.mjs` | 4 |
| `.patch` | 2 |
| `.sh` | 1 |
| `` | 1 |

## Entrées HTML

| Entrée | Scripts externes |
|---|---:|
| `teacher.html` | 137 |
| `student.html` | 128 |
| `mobile.html` | 0 |

Ces nombres quantifient la dépendance historique à l'ordre de chargement et justifient la reconstruction autour de dépendances Dart explicites.

## Signaux de dette architecturale

- Affectations globales `window/globalThis` détectées approximativement : **291**.
- Mutations de prototypes détectées approximativement : **20**.
- Listeners DOM détectés approximativement : **200**.
- Globals les plus fréquents : `ElectroSimModules` (15), `addEventListener` (13), `setInterval` (8), `ElectroSimContext` (7), `ElectroSimB5` (7), `document` (7), `localStorage` (7), `ELECTROSIM_HOST_ROLE` (7), `window` (6), `removeEventListener` (6), `innerWidth` (6), `innerHeight` (6).
- Clés de stockage les plus fréquentes : `electrosim_teacher_unlocked` (9), `electrosim.b10.rendererMode` (6), `electrosim-v1-circuit` (6), `electrosim-sync-client-v1` (6), `electrosim_teacher_pin_v1` (6), `electrosim_role` (6), `electrosim.v3.canvasOnly` (3), `electrosim_reduce_motion` (3), `electrosim_student_sheet_collapsed` (3), `electrosim-v3-reduce-motion` (2).

Ces métriques sont des **signaux statiques**, pas une preuve de comportement runtime. Elles servent à décider quoi ne pas reproduire dans Flutter.

## Fichiers de code les plus volumineux

- `electrosim_interface.js` — 2336 lignes
- `electrosim_shared_late.js` — 1619 lignes
- `.ts-build/electrosim_b7_core_electrical.js` — 1563 lignes
- `electrosim_b7_core_electrical.js` — 1563 lignes
- `.ts-build/electrosim_b7_core_runtime.js` — 1557 lignes
- `electrosim_b7_core_runtime.js` — 1557 lignes
- `.ts-build/electrosim_c31_visual_engine.js` — 1512 lignes
- `electrosim_c31_visual_engine.js` — 1512 lignes
- `.ts-build/electrosim_c31_palette_animation.js` — 1319 lignes
- `electrosim_c31_palette_animation.js` — 1319 lignes
- `src-ts/electrosim_b7_core_electrical.ts` — 1235 lignes
- `.ts-build/electrosim_b7_pedagogy_core.js` — 1131 lignes
- `electrosim_b7_pedagogy_core.js` — 1131 lignes
- `src-ts/electrosim_b7_core_runtime.ts` — 1127 lignes
- `.ts-build/electrosim_b10_canvas_renderer.js` — 1058 lignes

## Décisions de migration issues de cette baseline

1. Ne pas reproduire l'ordre de chargement de dizaines/centaines de scripts comme mécanisme de composition.
2. Ne pas transformer les globals historiques en singletons Dart globaux.
3. Ne pas migrer les mutations de prototypes ; les extensions doivent devenir des contrats/modules explicites.
4. Les clés de stockage observées sont uniquement un inventaire de formats à comprendre ; aucune donnée legacy n'est importée automatiquement.
5. Les occurrences de `FaultEngine`, `faultId`, `exampleId` ou équivalents ne définissent pas la nouvelle architecture : exemples et pannes restent strictement indépendants.

Le détail machine-lisible est dans `audit/legacy_reference_analysis.json`.
