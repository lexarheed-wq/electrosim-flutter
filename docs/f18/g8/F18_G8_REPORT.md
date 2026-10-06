# F18 — G8 TP professeur / élève

## Portée

G8 qualifie le cycle produit TP : création professeur, publication, démarrage collectif,
diagnostic élève, réparation du montage, remise, notation, supervision et clôture.

## Invariants

- Le brouillon professeur reste privé jusqu'à publication.
- L'élève n'obtient aucun bouton de démarrage autonome.
- La fiche diagnostic n'est visible que pour l'élève, en recherche de dérangement,
  pendant l'état `started`.
- La réparation passe par `TpEngine.updateCircuit`; aucune voie parallèle de montage
  élève n'est introduite.
- Une remise produit l'état `submitted` et rend immédiatement le montage en lecture seule.
- Les états `submitted`, `evaluated` et `closed` restent en lecture seule.
- La note professeur est bornée par `maxScore` et la clôture exige un TP évalué.
- La supervision professeur peut ouvrir l'élève, noter et clôturer.
- Les commandes LAN reproduisent publication/démarrage/remise/note/clôture sans exposer
  les vérités professeur au client élève.

## Qualification

Le workflow G8 exécute avec Flutter 3.38.10 / Dart 3.10.9 :

1. contrat statique `tools/f18_g8_contract.py`;
2. `flutter analyze`;
3. test transverse G8 diagnostic → réparation → remise → note → clôture;
4. tests contrôleur et UI TP existants;
5. tests diagnostic/supervision;
6. tests LAN de synchronisation;
7. tests Point 4 gestion professeur/supervision;
8. `dart analyze` et `dart test` du package `electrosim_tp`;
9. non-régression G7 instruments/propriétés.

G8 n'est PASS qu'après un workflow vert sur le SHA exact de la branche G8,
puis une nouvelle qualification verte sur le SHA de fusion de la branche d'intégration.
