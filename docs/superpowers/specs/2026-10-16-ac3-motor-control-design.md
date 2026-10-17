# Commande et variation de vitesse des moteurs triphasés

## Objectif

Permettre à l’utilisateur de construire et de simuler des circuits AC3 de démarrage direct dans un sens, d’inversion Avant/Arrière, d’étoile-triangle et de variation de vitesse par variateur de fréquence. La simulation doit rendre visibles les effets de la commande, des protections, de la charge et de la vitesse mécanique du moteur.

## État initial vérifié

- La bibliothèque contient une source triphasée 400/230 V, un moteur 6 bornes, des contacteurs 3P, des boutons NO/NF, des auxiliaires NO/NF, un disjoncteur 3P, un relais thermique 3P et un temporisateur étoile-triangle.
- Le PLC AC3 possède des entrées/sorties Ladder, mais ses entrées et sorties ne sont pas actuellement modélisées comme des branches 24 V calculées. Le runtime lit certains contrôles binaires et peut relier une sortie logique à un contacteur par `outputLinks`.
- Le solveur AC3 résout chaque circuit à une fréquence commune. Le moteur est actuellement calculé comme trois impédances de bobinage; sa vitesse affichée est la vitesse théorique du champ tournant, sans inertie ni glissement.
- Le relais thermique expose actuellement six bornes de puissance et aucun contact auxiliaire 95–96 / 97–98.

## Parcours utilisateur visés

### Démarrage direct

L’utilisateur relie une alimentation AC3, un disjoncteur, un contacteur, un relais thermique et un moteur six bornes. Les boutons Marche NO et Arrêt NF commandent la bobine. Un auxiliaire NO assure l’auto-maintien. Le déclenchement thermique ouvre le contact de commande NF, fait retomber le contacteur et signale le défaut jusqu’au réarmement.

### Marche Avant / Arrière

Deux contacteurs réalisent l’inversion de deux phases. Les contacts auxiliaires NF câblés en croisé assurent le verrouillage électrique. Un accessoire de verrouillage mécanique lie les deux contacteurs. Une demande simultanée des deux sens ne ferme jamais les deux contacteurs; l’état sûr est ouvert et un diagnostic explicite est présenté.

### Étoile-triangle

Le moteur six bornes, trois contacteurs, le temporisateur existant et les auxiliaires réalisent la transition. Le contacteur étoile s’ouvre avant la fermeture triangle, avec le temps mort configuré. Les contacteurs étoile et triangle ne peuvent pas être fermés simultanément.

### Variateur de fréquence

L’utilisateur règle marche/arrêt, sens, fréquence ou vitesse cible, temps de rampe et valeurs nominales du moteur. Le variateur commande la fréquence et la tension de sortie; la vitesse du rotor évolue en fonction du couple moteur, de l’inertie et de la charge.

## Architecture retenue

### Modèle mécanique du moteur

Ajouter un état mécanique persistant par moteur AC3 : vitesse signée, accélération, état thermique pertinent et temps de simulation. Employer un modèle pédagogique d’induction asynchrone, borné et déterministe, qui utilise fréquence, tension, paramètres nominaux, glissement, inertie et couple de charge. Le modèle d’impédance existant reste accepté pour les anciens projets; les nouveaux paramètres moteur reçoivent des valeurs par défaut documentées.

L’animation et les propriétés du moteur lisent la vitesse mécanique calculée. À l’arrêt électrique, le moteur décélère selon l’inertie et la charge au lieu de s’immobiliser instantanément. En inversion, le sens mécanique ne bascule pas instantanément : il suit le couple appliqué et traverse la vitesse nulle.

### Protections et interverrouillages

- Étendre le relais thermique avec deux branches auxiliaires identifiées 95–96 (NF) et 97–98 (NO), synchronisées avec l’état thermique de déclenchement.
- Au déclenchement, ouvrir les pôles de puissance et 95–96, fermer 97–98 et garder l’état mémorisé jusqu’au réarmement explicite.
- Ajouter un accessoire de verrouillage mécanique AC3 qui référence deux contacteurs existants sans branche électrique. Une commande simultanée des contacteurs liés force les deux à l’état ouvert et produit un diagnostic.
- Le verrouillage électrique câblé reste distinct et est réalisé avec les contacts auxiliaires NC déjà existants.

### Variateur et frontières de fréquence

Ne pas représenter le variateur par une résistance ajustable ni changer la fréquence de tout le réseau d’alimentation. Modéliser les côtés réseau et moteur comme deux domaines AC3 résolus séparément et reliés par un VFD dans le projet électrique. Le domaine d’entrée reste à la fréquence réseau; le domaine de sortie suit la consigne du variateur. La liaison porte la consigne, l’état marche/sens, les rampes, la puissance disponible et les défauts nécessaires à la simulation.

Le VFD applique une loi pédagogique tension/fréquence jusqu’à la fréquence de base, une limite de tension au-dessus, une limite de courant et une rampe. Il peut déclencher sur surintensité, surcharge ou perte de commande; les protections et l’état du variateur sont visibles dans ses propriétés.

## Interface et compatibilité

- Ajouter les définitions, terminaux, libellés, paramètres, visuels et fiches de propriétés à la bibliothèque AC3.
- Les composants et leurs paramètres doivent survivre à la sauvegarde et au rechargement des circuits et projets.
- Les projets existants sans paramètres mécaniques ou variateur continuent à se charger avec le comportement de compatibilité prévu; aucune valeur nominale absente ne doit être inventée silencieusement dans les résultats mesurés.
- Le PLC peut commander les contacteurs et les entrées du variateur par les liens logiques existants ou étendus, sans exposer un chemin qui contourne les interverrouillages et protections.
- Fournir des schémas d’exemple construits dans l’application pour les quatre parcours ci-dessus.

## Critères d’acceptation

1. Un démarrage direct énergise le moteur, établit l’auto-maintien, puis l’arrêt et le déclenchement thermique coupent la bobine et le moteur.
2. Le relais thermique présente l’état correct de 95–96 et 97–98; son défaut reste mémorisé jusqu’au réarmement.
3. Le montage inverseur fait tourner le moteur dans les deux sens après les transitions mécaniques simulées; jamais deux contacteurs interverrouillés ne conduisent ensemble.
4. Un moteur accélère depuis le repos, atteint un régime dépendant de la fréquence et de la charge, ralentit au retrait de l’alimentation et répond à une consigne de couple de charge accrue.
5. Le montage étoile-triangle respecte la temporisation et le temps mort et ne ferme jamais les contacteurs étoile et triangle simultanément.
6. Le VFD garde le réseau d’entrée à sa fréquence nominale tout en imposant sa fréquence variable au moteur; une consigne différente produit une vitesse mécanique différente après rampe.
7. Les défauts de configuration, de câblage, de plage de consigne, de conflit d’interverrouillage et de défaut VFD ont un résultat sûr et un diagnostic actionnable.
8. Les tests de solveur, de runtime, de persistance, d’interface et de packaging Mac passent sur la révision candidate.

## Hors périmètre

- Simulation électromagnétique transitoire à pas de commutation PWM ou dimensionnement de composants réels pour une installation industrielle.
- Certification de sécurité, coordination de protections selon une norme particulière et recommandation de mise sous tension d’un équipement réel.
- Développement d’un éditeur Ladder complet; le PLC existant est consommé et ses limites d’entrées/sorties sont respectées.
