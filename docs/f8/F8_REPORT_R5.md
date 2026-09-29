# Rapport F8-R5 — Stabilisation des gestes sur Flutter 3.38.10

## Déclencheur

L'exécution physique de F8-R4 sur le Mac Monterey a franchi `flutter analyze` puis a exécuté la suite de gestes. Sept tests ont passé et deux ont échoué :

- `click selects component without moving it` ;
- `background drag pans viewport but leaves layout unchanged`.

La trace observée passe par les invariants du binding de test et les recognizers de gestes. Les tests concernés utilisent un `GestureDetector` qui combinait clic simple, appui long, scale/pan et `onDoubleTap`.

## Cause racine

Le recognizer Flutter de double tap entre en compétition avec le tap simple. Sous le toolchain verrouillé Flutter 3.38.10 / Dart 3.10.9, il peut retarder l'acceptation du clic simple et maintenir son délai de reconnaissance au-delà d'un test court. Cela rend la sélection simple moins immédiate et fragilise également les invariants de fin de test lors d'un drag de fond.

## Correction

- suppression de `onDoubleTap` et `onDoubleTapDown` du `GestureDetector` de production ;
- le clic simple reste géré immédiatement par `onTapUp` ;
- détection explicite du double-clic contextuel après le tap normal, uniquement pour composant/source/fil ;
- double-clic reconnu sur la même cible, dans une fenêtre de 400 ms et une distance maximale de 24 px ;
- aucun timer de reconnaissance n'est créé par ElectroSim ;
- les tests de clic et de pan utilisent `pumpAndSettle()` après l'interaction pour vérifier un état stabilisé ;
- garde statique interdisant la réintroduction du recognizer double-tap concurrent.

## Invariants préservés

- clic = sélection sans déplacement ;
- appui long + glisser = demande de déplacement ;
- borne → borne = demande de connexion ;
- double-clic = action contextuelle ;
- pan/zoom ne modifient pas `CircuitState` ni `CircuitVisualLayout` ;
- aucune dépendance du Canvas vers les solveurs.

## Statut

F8 reste **CANDIDAT** jusqu'à obtention de `F8_GATE_PASS` sur le Mac Monterey de validation.
