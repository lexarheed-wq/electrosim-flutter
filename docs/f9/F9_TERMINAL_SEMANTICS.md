# F9 — Grammaire des bornes

**Préparation uniquement.** La grammaire visuelle ne décide pas si une connexion est électriquement valide. La compatibilité est fournie par les règles métier/topologiques ; le Canvas ne fait qu'afficher le résultat de cette validation.

## Principes

- position relative stable dans la géométrie monde ;
- hit-target écran : au moins 32 px à la souris et 44 px en tactile, même si le dessin visible est plus petit ;
- rôle lisible par texte/symbole, pas par couleur seule ;
- phases triphasées toujours ordonnées de façon déterministe ;
- polarité PV explicitement préfixée `PV+` / `PV−` lorsque le contexte peut être ambigu ;
- bornes de commande et de mesure graphiquement distinctes des bornes de puissance ;
- un port de paramètre environnemental n'est jamais rendu comme une borne électrique.

## États de borne

`available`, `wireSource`, `compatibleTarget`, `incompatibleTarget`, `connected`, `disabled`.

Ces états sont UI/topologiques. Ils ne signifient pas à eux seuls qu'une borne est sous tension.

## Matrice

Voir `F9_TERMINAL_ROLE_MATRIX.csv`.
