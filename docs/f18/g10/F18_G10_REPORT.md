# F18 — G10 Bibliothèques V2 pures

## Portée

G10 crée la première bibliothèque produit ElectroSim V2 sans migrer ni importer les
schémas ou scénarios de panne V1. Les anciennes collections F10/F11/F16 restent des
fixtures techniques de convergence et ne sont pas promues en contenu produit.

## Architecture

- `v2_product_examples.dart` contient uniquement des schémas sains natifs V2;
- `v2_product_faults.dart` contient uniquement des circuits fautifs autonomes natifs V2;
- le fichier de pannes n'importe jamais le fichier de schémas sains;
- `v2_product_catalog.dart` assemble les deux familles sans utiliser F10/F11/F16;
- la provenance produit est explicite : `library=v2-product`, `origin=v2-native`;
- les schémas et les pannes possèdent des IDs et des `CircuitState` distincts;
- aucune panne ne dépend d'un `exampleId`, d'un circuit sain ou d'un mécanisme
  d'injection cachée;
- la vérité professeur reste absente du payload élève.

## Première vague produit

Schémas sains :
- `V2-SCHEMA-DC-LAMP-01` — voyant CC autonome;
- `V2-SCHEMA-DC-MOTOR-01` — moteur CC en alimentation directe.

Scénarios de panne autonomes :
- `V2-FAULT-DC-LAMP-OPEN-01` — coupure interne du voyant;
- `V2-FAULT-DC-MOTOR-RETURN-01` — retour moteur absent.

Cette première vague sert à verrouiller l'architecture produit V2. Elle n'est pas une
limite au nombre futur de schémas ou de pannes.

## Qualification

Le gate G10 vérifie :

1. politique de reconstruction V2 et absence de références V1/legacy;
2. séparation source des schémas et des pannes;
3. validation automatique des schémas sains;
4. résolution électrique des schémas produit;
5. matérialisation et réparabilité des pannes;
6. confidentialité de `teacherTruth`;
7. absence de collision d'IDs avec les fixtures techniques;
8. non-régression G9.

## Critère de fermeture

G10 est PASS uniquement après workflow vert sur le SHA exact de la branche G10,
puis requalification verte sur le SHA de fusion de la branche d'intégration.
