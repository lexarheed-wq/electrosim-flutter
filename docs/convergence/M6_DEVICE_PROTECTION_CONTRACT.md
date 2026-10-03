# M6 — États appareils et protections

## Contrats validés

### Récepteur

La charge d'un récepteur utilise uniquement `receiverNominalCurrentA`.

- OFF : courant <= tolérance numérique
- UNDERLOAD : ratio < 0,75
- NORMAL : 0,75 <= ratio <= 1,05
- OVERLOAD : 1,05 < ratio <= 1,50
- SEVERE_OVERLOAD : ratio > 1,50

Le courant nominal du récepteur n'est jamais le calibre de la protection.

### Protection

Le calibre utilise uniquement `protectionRatedCurrentA`.

Les courbes sont des approximations pédagogiques bornées et testées :
- disjoncteurs B/C/D : partie thermique commune, bande magnétique distincte ;
- fusible : courbe propre ;
- relais thermique : temporisation thermique sans ouverture magnétique.

Le solveur électrique ne gère pas l'accumulation thermique. `ProtectionDynamicsEngine` produit un état immuable d'exposition à partir du temps de simulation explicite.

## Règles de sécurité architecturale

1. Aucun alias V1 `Imax` n'est accepté comme contrat V2.
2. Le déclenchement s'appuie sur le courant réellement résolu.
3. La source limitée réduit d'abord le courant disponible ; la protection ne voit que ce courant réel.
4. Les bibliothèques Schémas/Pannes V1 restent exclues.
