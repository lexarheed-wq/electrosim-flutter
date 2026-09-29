# F9-R9 — correction du drag palette → platine

## Symptôme R8

Le gate Flutter terminait avec plusieurs tests en échec, le dernier étant `long-press drag from palette drops a component on the canvas`.

## Cause ciblée

Le `LongPressDraggable` ajoutait une dépendance à une temporisation de reconnaissance de geste dans un `ListView` contenant aussi un `InkWell`. Cette combinaison rendait le test et le geste inutilement sensibles à l'arbitrage de la gesture arena Flutter.

## Correction

La palette utilise désormais `Draggable<F9PaletteDefinition>` :

- clic simple inchangé ;
- drag direct dès déplacement réel ;
- `DragTarget` et conversion écran→monde inchangés ;
- ajout dans `CircuitState` inchangé ;
- allocation d'identifiants anti-collision inchangée ;
- test widget réécrit avec un pointer drag déterministe.

Le noyau électrique F1→F8 et `electrosim_canvas` ne sont pas modifiés.
