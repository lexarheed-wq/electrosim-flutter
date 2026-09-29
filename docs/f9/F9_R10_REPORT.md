# F9-R10 — stabilisation responsive et tests de palette

## Constat R9

L’enregistrement physique R9 montre cinq échecs widget, mais trois d’entre eux ne sont pas des échecs fonctionnels : le même message d’activité est volontairement rendu dans le panneau Propriétés et dans la barre d’état, alors que les tests exigeaient une occurrence unique. Le drag aboutissait bien à la création de `resistor-1`.

Deux problèmes supplémentaires étaient réels :

- overflow compact de la barre d’état (`RenderFlex overflowed by 256 pixels on the right`) ;
- `Voir plus de composants` placé en fin d’un `ListView`, donc non construit/visible sans défilement dans le test et moins fiable pour l’utilisateur.

## Corrections R10

- barre d’état responsive avec libellé compteur compact ;
- clés stables `status-message`, `context-status-message`, `status-circuit-count` ;
- assertions widget fondées sur ces clés plutôt que sur le nombre d’occurrences visuelles ;
- palette restructurée : recherche/catégories en tête, liste scrollable au centre, `Voir plus/Voir moins` et compteur épinglés en pied ;
- `Draggable` direct conservé ; aucun retour au `LongPressDraggable` ;
- noyau F1→F8 et `electrosim_canvas` inchangés.

## Validation attendue

Le gate physique doit terminer par `F9_R10_GATE_PASS`, puis une revue visuelle doit confirmer le mode compact, le bouton Voir plus et le drag palette → platine.
