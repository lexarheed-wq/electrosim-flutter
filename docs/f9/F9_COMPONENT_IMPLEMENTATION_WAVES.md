# F9 — Vagues futures d'implémentation du système graphique

**Ce plan ne démarre pas F9.** Il ordonne le travail à exécuter uniquement après `F8_GATE_PASS`.

## Vague 1 — pilotes structurants

Objectif : prouver la grammaire commune avec un petit jeu couvrant DC, AC1, AC3, PV et mesure.

- source CC, résistance, lampe, interrupteur NO, protection ;
- source AC1, prise ;
- instrument de mesure ;
- source AC3, contacteur, moteur 3φ ;
- module PV, onduleur, batterie, environnement PV.

La vague 1 doit démontrer identité palette/Canvas, bornes stables, états UI séparés, états physiques pilotés par résultats et adaptation compact/medium/expanded.

## Vague 2 — familles proches

Étendre aux RLC, semi-conducteurs CC, protections PV, distribution 3φ et récepteurs/actionneurs restants en réutilisant les renderers/factories de famille plutôt qu'en créant un widget autonome par composant.

## Vague 3 — appareils externes

Industrialiser les appareils visuels (pompe, ventilateur, convoyeur, réfrigération, etc.) avec silhouettes réalistes mais cohérentes. Les détails mécaniques ne doivent jamais masquer bornes, connexion ou état pédagogique.

## Vague 4 — couverture et goldens

- goldens par famille et breakpoint ;
- variations d'états UI/physiques ;
- contrôle contraste et Semantics ;
- vérification overflow ;
- test de stabilité de position des bornes ;
- test que le renderer ne dépend d'aucun solveur.

## Critère de sortie

La beauté graphique n'est jamais un motif pour modifier la topologie ou contourner `SimulationResult`.
