# M13 — Qualification finale et passation

## Critères de fermeture

Le candidat final doit satisfaire simultanément :

1. `Convergence M0-M12 qualification` = PASS.
2. F15 : Linux, Windows, Android, macOS et iOS qualifiés selon le workflow plateforme.
3. macOS release construit depuis la même branche et la même toolchain Flutter 3.38.10 / Dart 3.10.9.
4. archive `.app` conservée dans un ZIP.
5. SHA-256 du ZIP et du contenu applicatif consignés.
6. archive source `git archive` du commit exact.
7. dossier de passation contenant :
   - candidat Mac ;
   - source ;
   - manifeste ;
   - SHA-256 ;
   - contrats M0→M13 ;
   - preuve F15 macOS ;
   - instructions de test physique.

## Test physique final attendu

Le test physique Mac reste court et porte uniquement sur les éléments impossibles à garantir complètement en CI :
- ouverture réelle de l'application sur macOS ;
- trackpad : pan / zoom ;
- lisibilité des composants ;
- drag/drop ;
- création d'une session ;
- accès Tableau de bord / simulateur ;
- liaison professeur/élève sur le LAN local.

Aucune bibliothèque Schémas V1 ou Pannes V1 n'est incluse dans la passation.
