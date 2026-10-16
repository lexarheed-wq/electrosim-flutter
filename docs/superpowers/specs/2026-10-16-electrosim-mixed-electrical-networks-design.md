# ElectroSim — circuits électriques mixtes AC3 et 24 V CC

**Date :** 16 octobre 2026  
**Statut :** spécification de conception — revue utilisateur requise avant le plan d’implémentation.

## 1. But et critères de réussite

Permettre de simuler un démarrage moteur sur une platine qui comporte un réseau de puissance triphasé AC3 et un réseau de commande 24 V CC. Chaque réseau conserve son solveur physique homogène; les composants communiquent au travers de couplages électriques ou logiques explicitement déclarés. Aucun circuit DC ne doit être interprété par le solveur AC3, ni l’inverse.

Le premier parcours réussi est : une alimentation 24 V CC alimente un PLC et ses capteurs; le PLC exécute un Ladder; une sortie pilote un relais d’interface dont la bobine est réellement résolue en DC; le contact sec de ce relais est câblé dans le circuit AC3; la bobine AC3 du contacteur ne colle que si le circuit de puissance/commande AC3 lui fournit sa tension; les contacts auxiliaires peuvent renvoyer le retour d’état au réseau de commande.

Critères de réussite :

1. AC3 et DC ont des topologies, résultats et diagnostics distincts.
2. Une perte de 24 V libère les relais DC et fait retomber la commande AC3 au cycle de simulation suivant.
3. Une bobine de contacteur AC3 sans tension ne colle pas même si le Ladder demande Q=true.
4. Les changements de mode ou de branche n’effacent, ne fusionnent et ne réinterprètent pas l’autre réseau.
5. Un ancien `CircuitState` simple reste ouvrable et exportable sans changement de schéma.
6. Une sauvegarde/restauration conserve les réseaux, leurs identités, leurs liens et leurs états de conception.

## 2. Décisions d’architecture

### 2.1 Projet multi-réseaux, pas mode composite dans `CircuitState`

`CircuitState.mode` demeure un domaine unique. Les solveurs existants reçoivent chacun un `CircuitState` homogène inchangé. Un nouvel agrégat versionné, provisoirement `ElectricalProject`, contient une collection de réseaux nommés (`ElectricalNetwork`), chacun avec un identifiant stable et un `CircuitState`.

La première tranche produit accepte exactement le couple `power: ac3` et `control: dc`. Le conteneur est conçu pour accepter d’autres réseaux homogènes à l’avenir, mais AC1/PV ne font pas partie de cette qualification. Les composants et bornes gardent leur identité dans leur réseau; les références inter-réseaux sont des couples `(networkId, componentId/terminalId)`, jamais des IDs seuls.

### 2.2 Couplage par relais d’interface

Le PLC commande une bobine de relais 24 V CC dans le réseau de contrôle. Cette bobine est résolue normalement par le solveur DC et son état découle de la tension réelle, du seuil de collage et du seuil de retombée. Le contact sec correspondant est un composant du réseau AC3 et agit sur le circuit de bobine du contacteur. Un `CrossNetworkRelayLink` associe explicitement les deux sous-parties qui représentent le même relais physique.

La sortie PLC n’est pas reliée directement à une bobine 230 V AC3. Le modèle pédagogique impose un relais d’interface isolé : c’est le montage sûr et réaliste pour transférer un ordre 24 V CC vers une commande AC3. La commande électrique AC3 du contacteur reste câblée dans son réseau; le relais d’interface n’invente pas une tension.

Les retours auxiliaires NO/NC du contacteur AC3 vers le PLC sont traités comme des signaux isolés explicites du projet. Leur état est l’état calculé du contacteur, tandis que l’entrée PLC est comparée au commun et à la plage logique DC configurée. Le premier palier peut fournir des liens de retour directs; il ne crée pas de fil physique entre les graphes.

### 2.3 Runtime à horloge commune et scans séquencés

Un `ElectricalProjectRuntimeEngine` coordonne un pas de temps commun, réutilise `ElectroSimRuntimeEngine` séparément pour DC et AC3, et conserve un état runtime par `(networkId, componentId)`. Pour chaque pas :

1. projeter les états mémorisés des sorties PLC et relais d’interface dans le circuit de commande;
2. résoudre le circuit DC et évaluer les tensions d’entrées PLC;
3. exécuter un scan Ladder avec `elapsed` une seule fois, sans intégrer le temps dans les résolutions correctives;
4. mettre à jour les relais DC et les contacts AC3 via les liens de relais;
5. résoudre le réseau AC3, puis publier les états des contacteurs et auxiliaires;
6. préparer les retours de contacts pour le prochain scan DC.

La causalité est discrète et déterministe : les retours AC3 issus d’un cycle deviennent entrées DC au scan suivant. Un solve correctif éventuel est à temps nul. Une panne ou une erreur de programme désactive les sorties au scan et laisse les circuits physiques provoquer le relâchement des relais.

### 2.4 UI et persistance

Le workspace composite présente deux réseaux sélectionnables dans le même projet : « Commande 24 V CC » et « Puissance AC3 ». La palette se filtre sur le réseau actif; un élément d’un domaine incompatible ne peut pas être déposé dans l’autre. Une vue des liaisons de projet permet de créer/retirer les couples bobine DC ↔ contact sec AC3 et retours auxiliaires.

Le projet est enveloppé dans un nouveau format de document versionné, séparé de l’ancien format simple. Le décodeur actuel des documents simples reste inchangé; un document simple peut être enveloppé comme projet à un seul réseau. L’export legacy est refusé si plusieurs réseaux ou des liens inter-réseaux seraient perdus.

## 3. Modèles PLC et relais

Le PLC de projet mixte est un modèle de commande compatible DC (`plc_dc` ou nom final équivalent), avec les entrées et sorties nécessaires et un état Ladder séparé du dessin. Les opérations Ladder partagent une implémentation pure avec les programmes PLC AC3 existants : contacts NO/NC, bits M, SET/RESET, TON et DN, bobines Q.

Les sorties Q ont une projection physique vers le circuit DC : elles ferment les sorties internes/contacts de sortie du PLC dans leur plage de tension nominale. Le solveur DC doit voir le trajet d’alimentation de la bobine du relais d’interface et ne pas forcer son collage par une commande logicielle qui contournerait sa tension. Les entrées se basent sur des niveaux électriques calculés, avec seuils configurables dans les paramètres du PLC; une entrée flottante ou hors plage est fausse et diagnostiquée.

Les variantes existantes `plc_ac3` et `timer_star_delta` restent lisibles pour compatibilité. La création d’un projet composite n’effectue pas une migration silencieuse des composants, fils ou réglages d’un schéma existant. Une migration guidée pourra être spécifiée après le premier parcours fonctionnel.

## 4. Validation et erreurs

La validation du projet vérifie : identifiants uniques par réseau et références complètes; modes réseau conformes; compatibilité des modèles dans chaque réseau; relais lié de type bobine DC et contact AC; liens non ambigus; tension PLC et seuils finis/positifs; absence de liaisons qui confondent des nœuds AC et DC; et absence d’export destructif vers le format simple.

Un réseau invalide garde son résultat/diagnostic propre et ne corrompt pas les autres réseaux. Une perte d’alimentation de commande fait tomber les sorties Q et relais DC, puis le contact AC3 associé s’ouvre. Un cycle de simulation en erreur ne conserve jamais une sortie excitée par un scan antérieur.

Les diagnostics affichés distinguent au minimum : défaut de réseau DC, alimentation PLC absente/hors plage, entrée flottante/hors plage, programme Ladder invalide, liaison bobine/contact manquante ou ambiguë, défaut de réseau AC3 et contacteur non alimenté malgré une sortie Q active.

## 5. Périmètre par phases

### Phase A — contrat et persistance

- ajouter `ElectricalProject`, `ElectricalNetwork` et liens typés avec validation/JSON;
- introduire le nouveau document de stockage versionné avec lecture des anciens documents;
- ajouter tests de round-trip, références cassées, modes mélangés et interdiction de perte à l’export.

### Phase B — solve et couplage runtime

- ajouter la projection physique `plc_dc` et ses I/O DC;
- extraire le scan Ladder dans une unité pure réutilisable;
- ajouter le coordinateur multi-réseaux et le lien bobine/relais;
- tester la chaîne bouton/capteur → I PLC → Ladder → bobine relais DC → contact sec → bobine contacteur AC3 → auxiliaire retour;
- tester pertes de source, fils ouverts, court-circuit, TON, interverrouillage et arrêt d’urgence.

### Phase C — interface et candidat

- ouvrir/enregistrer un projet composite depuis le workspace;
- offrir les onglets Commande et Puissance, palette et états propres à chaque réseau;
- exposer le panneau des liaisons inter-réseaux et leurs diagnostics;
- qualifier l’application Flutter, les tests d’intégration et le build Mac avant de livrer un candidat.

Les phases s’exécutent séquentiellement. Le design actuel ne prétend pas achever un transformateur 230/24 V AC, redresseur et alimentation stabilisée DC à travers plusieurs réseaux. Ce convertisseur est une phase ultérieure distincte; en phase A–C, le réseau de commande est alimenté par une source 24 V CC explicitement dessinée et résolue par DC.

## 6. Stratégies examinées

1. **Tout ramener dans un graphe AC3 ou DC** : rejetée, car elle attribue un seul modèle électrique à des composants ayant des domaines distincts et invalide les résultats.
2. **Deux réseaux indépendants sans lien runtime** : conserve les solveurs mais ne permet pas une commande moteur de bout en bout.
3. **Projet multi-réseaux avec solveurs séparés et liens d’interface typés** : retenue; elle garde les solveurs spécialisés et modélise la séparation 24 V/AC3 d’une platine réelle.

## 7. Vérification attendue

La qualification exige tests unitaires du projet, Ladder et seuils d’entrée; tests runtime de l’horloge et des transitions causales; tests de persistance versionnée et de lecture legacy; tests widget des deux réseaux et des liens; analyse statique; puis build et lancement sur macOS Intel. Aucun statut PASS ne peut être annoncé tant que la commande correspondante n’a pas été exécutée avec succès.
