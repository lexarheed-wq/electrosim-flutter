# Correctif de fluidité des connexions — 8 octobre 2026

Base : `core-island01-prebaseline-r3-20261008`, commit `c4ecbcb1b6411a0bc05a2839158d0e10cc621ca9`.

## Cause et correction

Le clic de connexion lançait `routeAll` sur le thread de l'interface : trois ordres de routage pour tous les fils. Il ne route désormais que la connexion ajoutée, conserve les trajets existants et classe les obstacles selon la nouvelle topologie électrique. Les déplacements de composants conservent le routage global.

À partir de 30 composants et sources, un trajet provisoire apparaît immédiatement et le routage final utilise `compute` dans un isolate natif. Une seule tâche travaille à la fois ; une seule demande récente attend. Toutes les connexions encore inachevées sont reprises dans cette demande. Un résultat ancien ne peut pas écraser une modification plus récente ou un écran fermé. Flutter Web exécute `compute` sur le thread principal : cette séparation en isolate concerne les applications natives.

La recherche A* utilise un tas binaire au lieu de trier toute sa liste à chaque étape. Les courants des fils et les index DC sont mémorisés par snapshot immuable : l'animation ne reconstruit plus ces données à chaque image. Les calculs et signes électriques restent couverts par les tests.

## Mesures reproductibles

Flutter 3.38.10, Dart 3.10.9, environnement Linux de développement. Fixtures de résistances disposées en deux colonnes ; un fil pour deux composants. Médiane de huit calculs sur un schéma déjà routé. Avant : ancien `routeAll` ; après : `routeConnection`. Les temps ne comprennent ni rendu complet, ni résolution électrique, ni démarrage d'isolate et ne sont pas une mesure du clic sur l'appareil de l'utilisateur.

| Composants | Fils | Avant (ms) | Après (ms) |
| --- | --- | --- | --- |
| 30 | 15 | 8,498 | 2,386 |
| 60 | 30 | 32,237 | 1,787 |
| 100 | 50 | 111,891 | 2,485 |
| 200 | 100 | 799,236 | 6,154 |

## Vérification

- Suite application : 260 tests réussis.
- Suite canvas finale : 80 tests réussis, dont le benchmark et la conservation des anciens trajets.
- Trois tests ciblés application relancés après nettoyage : cache des courants et isolate natif avec demandes successives.
- `flutter analyze` : aucune anomalie dans l'application ni le canvas.
- `git diff --check` : aucune erreur.

Depuis la racine :

```sh
cd apps/electrosim
flutter pub get
flutter analyze
flutter test
cd ../../packages/electrosim_canvas
flutter pub get
flutter analyze
flutter test
```

## Installation et limites

Le patch s'applique sur la version de base indiquée. Sur une copie de travail propre de cette version : `git apply --check /chemin/electrosim-fluidite.patch`, puis `git apply /chemin/electrosim-fluidite.patch`. L'archive contient l'ensemble des sources corrigées, sans caches ni SDK.

L'application n'a pas été compilée ni profilée sur l'appareil de l'utilisateur. Tester en mode profile/release des schémas représentatifs à 30, 100 et 200 composants, notamment des connexions rapides, des déplacements et des suppressions pendant un routage. Le solveur électrique reste synchrone et peut devenir le prochain coût dominant sur des circuits complexes. Ce correctif traite le coût de routage identifié ; il ne garantit pas une latence nulle pour toute taille ou toute topologie.
