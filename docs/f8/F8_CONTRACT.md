# F8 — Contrat Canvas Flutter et interactions de base

## Objectif

F8 introduit la première couche graphique Flutter interactive sans déplacer l'autorité électrique hors du noyau. Le Canvas n'est pas un solveur : il reçoit un `CircuitState`, un état graphique séparé et traduit les gestes en callbacks métier.

## Frontières obligatoires

- `CircuitState` reste immuable et n'est jamais modifié par le Canvas.
- `CircuitVisualLayout` porte uniquement positions, tailles visuelles et points de routage.
- `ViewportController` sépare coordonnées monde et écran ; zoom/pan ne modifient jamais le circuit.
- `HitTestEngine` centralise la détection des bornes, composants, sources et fils.
- `CircuitScenePainter` dessine uniquement des informations déjà présentes dans `CircuitState` et le layout ; aucun calcul de tension, courant, puissance, topologie ou état appareil n'est autorisé.
- F8 n'importe aucun solveur, `TopologyEngine`, `MeasurementEngine`, `EnergyEngine` ou module PV.

## Gestes F8

- clic composant/source : sélection sans déplacement ;
- appui long + glisser : prévisualisation puis callback de déplacement graphique ;
- clic borne : début de connexion ;
- clic seconde borne : callback de demande de connexion ;
- clic fond ou re-clic sur la borne de départ : annulation explicite du câblage ;
- double-clic/double-tap composant ou fil : callback d'action contextuelle ;
- glisser sur fond : pan ;
- pincement / molette : zoom centré sur le point d'interaction.

## Goldens

Trois profils de référence sont requis : compact 390×700, medium 800×900 et expanded 1280×800. Si les PNG n'existent pas encore, la porte les génère puis exécute immédiatement leur test de reproductibilité, mais **ne peut pas déclarer F8 validée sur cette seule base**. Elle termine alors par `F8_GATE_GOLDEN_REVIEW_REQUIRED`. Après inspection humaine, `tools/approve_f8_goldens.py --approve` verrouille taille et SHA-256 des trois images dans `docs/f8/F8_GOLDEN_BASELINE.json`. Les exécutions suivantes vérifient à la fois la comparaison pixel et les hashes approuvés. Toute modification silencieuse de la baseline est bloquée.

## Performance

La scène nominale de référence contient 24 composants et 23 connexions. Le benchmark du painter exécute 120 rendus après échauffement. Le p95 doit rester inférieur à 16 667 µs, correspondant au budget théorique de 60 fps pour le rendu de la scène F8.

## Critère de passage

`F8_GATE_PASS` uniquement si : régressions F1→F7 vertes, analyse Flutter verte, tests de gestes verts, trois goldens vérifiés **et approuvés**, benchmark p95 sous 16 667 µs, audit UI généré et garde d'architecture F8 verte. Une première génération non approuvée produit `F8_GATE_GOLDEN_REVIEW_REQUIRED`, jamais `F8_GATE_PASS`.
