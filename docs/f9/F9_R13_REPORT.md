# F9-R13 — Panneau contextuel actif

## Constat après revue vidéo R12

La revue physique confirme le correctif de placement automatique : les ajouts rapides successifs sont déposés dans des zones libres et ne recouvrent plus les conducteurs ou les appareils existants. La palette, la navigation et le Canvas restent stables.

## Lot R13

R13 ouvre le lot F9.4 du plan : **panneau contextuel / propriétés**.

- lecture du type, de l'identifiant, des bornes et des paramètres de l'élément sélectionné ;
- distinction source / composant ;
- commande explicite de l'état principal quand elle existe (`closed` pour interrupteurs/disjoncteurs, `enabled` pour sources) ;
- suppression sûre d'un élément avec suppression automatique des connexions qui référencent ses bornes ;
- incrément de `CircuitState.revision` à chaque commande réelle ;
- nettoyage du layout visuel et des routes des fils supprimés ;
- aucun calcul électrique dans l'UI ;
- aucun changement du noyau F1→F8 ou du package Canvas F8.

## Validation attendue

```bash
./validate.sh
```

Marqueur :

```text
F9_R13_GATE_PASS
```

Puis `./run_visual.sh` et vérifier : sélectionner l'interrupteur, ouvrir/fermer depuis Propriétés, sélectionner la source, l'activer/désactiver, supprimer un élément et vérifier que les fils attachés disparaissent avec lui sans crash ni connexion pendante.
