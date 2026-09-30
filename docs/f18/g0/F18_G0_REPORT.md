# F18-G0 — Rapport de qualification baseline & parité

## Statut

**PASS — baseline et inventaires qualifiés.**

- Head d’implémentation qualifié : `5715fd244e6f70ce4d8f0764522543b4936dbbca`
- GitHub Actions run : `36720687139`
- Gate : `F18_G0_BASELINE_INVENTORY_GATE_PASS`
- Evidence artifact : `11099130881`
- Digest evidence : `sha256:cdae5aea664ed26b66156225c9b93093d2146f70b8865d6d25f2cf9e0a6ef011`
- Toolchain : Flutter 3.38.10 / Dart 3.10.9
- Suite application : **76/76 PASS**

> Le commit qui contient ce rapport est nécessairement postérieur au head ci-dessus. Un dernier run exact-head est donc exigé après commit du rapport ; son SHA/run est enregistré dans le ledger et la PR, afin d’éviter une impossible auto-référence du fichier à son propre commit.

## Baseline F17 protégée

- VERSION : `ELECTROSIM2-F17-R12-QUALIFIED`
- Base main qualifiée : `554d156839418f2be690980fe8acb941f776a425`
- Référence V1 : `ElectroSim-FIELDFIX01-R1.zip`
- SHA-256 V1 : `569e05908592e6dd615bd80b342f6c7a28249850951d353dac988c5d2e1187bd`
- Drift guard : **PASS**
- Code runtime/core modifié par G0 : **NON**

## Inventaire composants V1

- Total : **217**
- palette-component : **195**
- socket : **4**
- external-appliance : **18**

### Décisions de parité

- REBUILD : **12**
- REPLACE : **11**
- DEFER : **168**
- RETIRE : **26**
- UNREVIEWED : **0**

La règle G0 est conservative : seul un support déjà démontré dans la surface Flutter qualifiée est marqué REBUILD.

## État Flutter courant

- Palette : **12 éléments**
- Exemples sains qualifiés : **5**
- Pannes autonomes qualifiées : **3**

## Matrice de capacités produit

- Capacités tracées : **29**
- PRESENT : **4**
- PARTIAL : **19**
- MISSING : **2**
- INTENTIONALLY_REDESIGNED : **4**

Les manques ou redesigns sont explicites ; aucune absence n’est transformée en faux PASS.

## Vérifications du gate

1. toolchain verrouillée ;
2. référence V1 analysée puis vérifiée ;
3. tests Python G0 ;
4. baseline F17 et drift guard ;
5. matrices de parité ;
6. `pubspec.lock` inchangé après `flutter pub get` ;
7. `flutter analyze` ;
8. suite complète `flutter test` ;
9. marqueur final G0.

## Sortie de G0

G0 fournit la base mesurable pour G1 : Figma et le design system ne devront plus être évalués contre une impression subjective, mais contre les inventaires et critères de parité figés ici.
