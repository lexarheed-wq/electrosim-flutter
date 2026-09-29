# F9 — Spécification responsive

## Breakpoints de référence

| Profil | Largeur | Organisation |
|---|---:|---|
| Compact | `< 600 px` | Canvas prioritaire, panneaux en tiroirs/bottom sheets, barre d'actions basse |
| Medium | `600–1000 px` | Canvas + panneau secondaire escamotable |
| Expanded | `> 1000 px` | Palette + Canvas + panneau contextuel simultanés |

## Compact

Priorité absolue au simulateur. Les panneaux lourds ne doivent pas réduire le Canvas à une zone inutilisable. Les actions primaires restent atteignables au pouce. Toute fonction hors écran doit avoir un mécanisme explicite de tiroir, feuille ou défilement.

Structure proposée :

1. app bar compacte ;
2. Canvas plein espace ;
3. action bar basse ;
4. palette en bottom sheet ;
5. propriétés/EIE en sheet secondaire ;
6. statut de simulation non intrusif.

## Medium

Structure proposée : Canvas dominant + panneau latéral unique, repliable. La palette et les propriétés ne doivent pas occuper simultanément une largeur excessive.

## Expanded

Structure proposée :

`Palette | Canvas | Propriétés / EIE`

Le Canvas conserve la plus grande surface et ne doit pas être redimensionné par des animations de panneau non bornées.

## Contraintes

- pas d'overflow sur les écrans critiques ;
- pas de contrôle indispensable uniquement accessible au survol ;
- targets tactiles adaptées ;
- zoom/pan du Canvas inchangés d'un profil à l'autre ;
- coordonnées monde indépendantes de la taille de fenêtre ;
- passage d'un breakpoint à l'autre sans mutation de `CircuitState`.
