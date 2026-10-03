# M7 — Mesures intelligentes

Le moteur de mesure conserve les mesures CC existantes et ajoute des lectures AC1/AC3 directement fondées sur les résultats des solveurs.

- tension AC : module du phasor entre les deux nœuds de sonde, valeur RMS ;
- courant AC : module du courant complexe de la branche ;
- fréquence : fréquence validée du résultat solveur ;
- résistance : sécurité moteur conservée ; aucune notion d'interface « mode hors tension » séparé n'est créée.

L'UI ne recalcule aucune grandeur électrique.
