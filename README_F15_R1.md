# ElectroSim Flutter — F15-R1

Phase F15 : distribution et qualification multi-plateforme.

## Objectif

Qualifier les builds réels d'ElectroSim sans modifier le noyau F0→F14. F15-R1 ajoute uniquement l'infrastructure de packaging, les probes de plateforme, les smoke tests, les preuves de build et le gate de qualification.

## Cibles bloquantes

- macOS desktop
- Windows desktop
- Linux desktop
- Android
- iOS

Le Web reste complémentaire et est audité séparément.

## Règles

- Une preuve `PASS` doit provenir d'un build réel sur une plateforme compatible.
- Une preuve contient versions Flutter/Dart, OS hôte, commande de build, SHA-256 de l'artefact et résultat du smoke test.
- Une preuve provenant d'un autre OS pour un build desktop natif est refusée.
- iOS doit être qualifié sur macOS; Windows sur Windows; Linux sur Linux.
- Aucun `F15_GATE_PASS` n'est émis tant que les cinq cibles bloquantes ne possèdent pas une preuve vérifiée.
- Les fonctions principales doivent être testables hors ligne après préparation locale des dépendances.

## Commandes

Qualification de la machine courante :

```bash
./tools/f15_qualify_current_host.sh
```

Gate global :

```bash
./validate.sh
```

Le gate peut terminer par `F15_GATE_CROSS_PLATFORM_EVIDENCE_REQUIRED` tant que toutes les preuves n'ont pas été réunies. Cela n'est pas un échec fonctionnel du noyau mais une porte de release volontaire.
