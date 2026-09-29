# ElectroSim Flutter — F15-R5

Correctif de qualification multi-plateforme :
- préflight explicite par cible ;
- iOS n'est tenté que si le SDK iphoneos est disponible ;
- une plateforme absente est annoncée `F15_TARGET_UNAVAILABLE` sans faux PASS ;
- la qualification macOS déjà réussie n'est pas invalidée par l'absence du runtime iOS ;
- le gate global continue d'exiger les preuves réelles de toutes les cibles bloquantes.
