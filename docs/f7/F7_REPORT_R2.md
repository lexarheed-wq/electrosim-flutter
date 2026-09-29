# Rapport F7-R2 — Correctif contrat d'identifiants PV

## Défaut reproduit

La porte F7-R1 atteignait les tests `electrosim_pv`, puis les 12 tests échouaient pendant la construction de la fixture avant l'exécution du solveur. L'exception était :

`DomainException(invalidId): Identifier contains unsupported characters.`

La cause racine était l'utilisation du caractère `+` dans trois identifiants techniques de test : `inv-dc+`, `pv+` et `dc+`.

## Cause racine

Le contrat F1 `ValueId` accepte la forme :

`^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$`

Le signe `+` est donc volontairement exclu. La polarité électrique ne doit pas être encodée dans la syntaxe libre de l'identifiant ; elle est déjà portée par `TerminalRole.positive` et `PhaseTag.dcPositive`.

## Correction

- `inv-dc+` -> `inv-dc-pos`
- `pv+` -> `pv-pos`
- `dc+` -> `dc-pos`
- conservation des libellés visibles `DC+` et `+` ;
- aucune modification du contrat F1 ni du solveur PV ;
- ajout d'un contrôle statique des identifiants littéraux utilisés par les fixtures et benchmarks PV.

## Non-régression

Le contrôle F7 échoue désormais avant les tests Dart si un littéral passé à `CircuitId`, `ComponentId`, `SourceId`, `TerminalId`, `ConnectionId` ou aux helpers `_wire(...)` du package PV ne respecte pas le contrat F1.

## Statut

CANDIDAT. F7 reste non validé tant que `F7_GATE_PASS` n'a pas été obtenu sur le SDK Flutter/Dart Monterey verrouillé.
