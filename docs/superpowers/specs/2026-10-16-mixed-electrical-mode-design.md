# Mode de conception électrique mixte

## Objectif

Permettre de concevoir un montage sur une seule platine en plaçant et reliant des composants issus des modes CC, AC, AC3 et photovoltaïque. L’interface présente un mode « Mixte » au même niveau que les modes existants. Le moteur conserve les domaines électriques et appelle le solveur approprié à chaque sous-réseau.

Le premier parcours de référence est une commande PLC 24 V CC sur la même platine qu’un départ moteur AC3 : la sortie du PLC commande le contacteur de puissance et son état de simulation ouvre ou ferme les pôles. Le parcours photovoltaïque doit également permettre de montrer les côtés PV, CC de stockage et AC d’un système avec leurs composants de conversion.

## État actuel

- `ElectricalMode` contient `dc`, `ac1`, `ac3` et `pv`; `CircuitState` porte un mode unique.
- Le runtime applicatif sélectionne un solveur par mode et ne résout pas un `CircuitState` hétérogène.
- `ElectricalProject` sait orchestrer plusieurs réseaux homogènes, mais limite la forme prise en charge à un réseau CC et un réseau AC3.
- Le parcours mixte actuel affiche un seul réseau à la fois dans un éditeur complet, avec une mise en page distincte par réseau. Il relie la sortie PLC à une bobine relais CC et un contact auxiliaire AC3, au lieu de permettre la commande directe du contacteur de puissance.
- Le solveur PV existe, mais l’orchestrateur de projet n’exécute pas encore un assemblage PV/CC/AC couplé.

## Architecture retenue

### Platine et modèle de conception

Le mode « Mixte » représente une platine projet contenant des réseaux électriques homogènes internes. Le modèle enregistré conserve le domaine de chaque réseau (`dc`, `ac1`, `ac3` ou `pv`) et une mise en page commune de platine pour tous les composants. Le mode mixte est un mode de conception/orchestration; il n’est jamais envoyé tel quel à un solveur spécialisé.

Chaque élément électrique appartient à un réseau et garde ses propriétés et son solveur actuels. Un tableau commun affiche tous les composants en même temps. La palette mixte rend accessibles les composants de tous les domaines et présente le domaine de chaque élément. Les fils restent dans leur réseau homogène; une tentative de relier directement deux domaines incompatibles est refusée avec un diagnostic visible.

Une même fonction physique qui traverse une frontière de domaine est représentée par une liaison de couplage explicite et typée. Par exemple, la liaison PLC Q0 → bobine de commande du contacteur AC3 est un signal de commande isolé : elle transmet l’état logique et ne crée pas une connexion électrique CC–AC3. Le contacteur reste une instance physique unique dans la partie puissance; son état commandé est fourni au coordinateur AC3 et passe toujours par les verrouillages et protections.

### Orchestration des solveurs

Le moteur mixte avance les sous-réseaux actifs dans un tick commun et conserve un snapshot par domaine. Les solveurs existants restent responsables de leurs résultats : DC, AC1, AC3 et PV. Les liens de commande et les composants de conversion échangent seulement les états explicitement définis par leur contrat. Le temps physique n’avance qu’une fois par tick; les résolutions correctives nécessaires aux commandes ou convertisseurs utilisent un temps nul.

Les premières liaisons inter-domaines prises en charge sont :

- PLC CC Q vers commande d’un contacteur AC1/AC3;
- contact auxiliaire AC1/AC3 vers entrée PLC CC;
- conversion PV vers CC via régulateur, puis CC vers AC via onduleur, lorsque ces composants et leurs contrats physiques sont présents.

Un transformateur reste une conversion AC–AC avec isolement; il ne permet pas à lui seul de transformer une source CC en AC. Les domaines sans chemin de conversion physique compatible ne sont pas implicitement fusionnés.

### Interaction et retours d’état

- Le sélecteur de modes offre « Mixte ».
- Le mode ouvre une seule platine avec tous les domaines visibles, une palette globale et des contrôles d’édition propres à l’élément sélectionné.
- Le panneau de propriété identifie le domaine et les liaisons inter-domaines d’un composant.
- Les liaisons de commande peuvent être créées depuis le PLC vers le contacteur sans exiger un relais intermédiaire artificiel; un relais physique peut toujours être ajouté comme élément réel du schéma.
- Les états du PLC, des contacteurs, des convertisseurs et les diagnostics restent visibles pendant la simulation.

### Sauvegarde et compatibilité

Les schémas mono-domaine et les projets mixtes existants doivent continuer de se charger. Une migration transforme un ancien projet mixte CC+AC3 en platine mixte, conserve les identifiants, les composants, les fils et leurs positions, et garde les liaisons relais/retour déjà enregistrées. La mise en page des anciennes platines est convertie vers l’espace de coordonnées commun sans chevauchement volontaire des réseaux. Le format sauvegardé est versionné; les anciennes versions restent lisibles.

## Comportements sûrs et diagnostics

- Aucun fil ne peut joindre deux réseaux de domaines différents.
- Toute liaison de commande vérifie le mode, l’adresse PLC, la cible, l’unicité et la disponibilité de l’alimentation PLC. Une liaison manquante ou invalide laisse l’actionneur au repos et donne un diagnostic précis.
- Une commande PLC ne contourne jamais les interverrouillages mécaniques/électriques ou les protections du domaine de puissance.
- Un convertisseur absent, mal paramétré ou non supporté ne transmet ni puissance ni état supposé; son diagnostic nomme le composant et les domaines concernés.
- Les résultats par domaine restent consultables indépendamment pour faciliter le diagnostic du montage.

## Critères d’acceptation

1. « Mixte » est proposé dans le choix du mode et ouvre une seule platine commune.
2. La palette mixte propose les composants CC, AC, AC3 et PV; les éléments posés sont tous visibles et déplaçables sur la même mise en page.
3. Le moteur identifie et résout chaque réseau homogène avec son solveur spécialisé, et rapporte les résultats par domaine.
4. Une source 24 V CC, un PLC, un contacteur AC3 et un moteur triphasé peuvent être disposés sur la platine; une liaison Q PLC–contacteur fait fermer les pôles de puissance, et le retrait de la commande les fait ouvrir.
5. Le scénario PLC–contacteur fonctionne sans relais intermédiaire, tout en conservant la possibilité d’utiliser un relais physique.
6. Une tentative de connexion par fil entre domaines incompatibles est refusée et expliquée; les liaisons explicites fonctionnent uniquement dans les directions et domaines prévus.
7. Les interverrouillages et protections AC3 restent actifs avec les commandes PLC.
8. Un projet PV raccordé à une charge AC par régulateur/onduleur est orchestré en respectant les domaines et états de conversion modélisés; en l’absence de modèle de conversion supporté, l’application affiche la limite au lieu d’inventer un résultat.
9. Les anciens circuits simples et l’ancien format de projet mixte restent chargés sans perte de composants, de câblage ou d’état enregistré.
10. Les tests de domaine, de câblage, d’orchestration, de PLC/contacteur, de conversion PV, d’interface, de migration et de persistance passent.

## Hors périmètre

- Un solveur électromagnétique monolithique qui résout les domaines CC, AC, AC3 et PV en une seule matrice.
- Une connexion conductrice directe entre domaines de nature différente sans modèle de conversion ou de commande.
- La validation normative d’une installation réelle ou la certification de sécurité des composants.
- L’ajout de modèles physiques de conversion inexistants sans hypothèses documentées et tests dédiés.
