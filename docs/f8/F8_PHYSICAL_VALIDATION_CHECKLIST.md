# Checklist physique F8 — Mac Monterey

Cette checklist accompagne `F8_GATE_PASS`. Elle ne remplace pas les tests automatiques.

## Préconditions

- Flutter 3.38.10 / Dart 3.10.9 ;
- `./validate.sh` exécuté ;
- si demandé, trois goldens inspectés puis approuvés ;
- lancement via `./run_visual.sh`.

## Contrôles manuels

| # | Action | Résultat attendu |
|---|---|---|
| 1 | Clic simple sur composant | Sélection visible, aucune modification de position |
| 2 | Clic simple sur fil | Fil visuellement sélectionné |
| 3 | Appui long puis glisser | Composant suit la prévisualisation et est déplacé au relâchement |
| 4 | Clic borne A puis borne B | Une demande de connexion est affichée ; le Canvas ne modifie pas seul le circuit |
| 5 | Clic borne A puis clic fond | Câblage annulé, aucun callback de connexion |
| 6 | Clic borne A puis re-clic A | Câblage annulé |
| 7 | Double-clic composant | Action contextuelle composant |
| 8 | Double-clic fil | Action contextuelle fil |
| 9 | Glisser sur fond | Pan uniquement ; aucun composant déplacé |
| 10 | Molette / pinch | Zoom centré sur le point d'interaction |
| 11 | Zoom min / max | Bornes et fils restent raisonnablement faciles à cibler |
| 12 | Recentrer | Viewport revient à la position prévue sans toucher au circuit |
| 13 | Séquence 20+ gestes mixtes | Aucun crash, aucune sélection fantôme, aucun câblage fantôme |
| 14 | Redimensionner fenêtre | Pas de crash ; Canvas continue à peindre correctement |

## Contrôles visuels des goldens

Inspecter les profils :

- compact 390×700 ;
- medium 800×900 ;
- expanded 1280×800.

Vérifier : éléments visibles, pas de clipping anormal, bornes lisibles, fils raccordés aux bornes, grille cohérente, texte non tronqué de façon critique.

## Décision manuelle

- **PASS** : tous les contrôles critiques 1–13 sont conformes ;
- **FAIL** : crash, déplacement au simple clic, connexion fantôme, zoom/pan incohérent, cible impossible à sélectionner ou divergence visible du layout.
